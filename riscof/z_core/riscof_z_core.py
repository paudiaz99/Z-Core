import os
import re
import shutil
import subprocess
import shlex
import logging
import random
import string
from string import Template
import sys

import riscof.utils as utils
import riscof.constants as constants
from riscof.pluginTemplate import pluginTemplate

logger = logging.getLogger()

class z_core(pluginTemplate):
    __model__ = "z_core"
    __version__ = "1.0"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        config = kwargs.get('config')

        if config is None:
            print("Please enter input file paths in configuration.")
            raise SystemExit(1)

        # Path to the Z-Core project root
        self.pluginpath = os.path.abspath(config['pluginpath'])
        self.project_root = os.path.dirname(os.path.dirname(self.pluginpath))

        # Number of parallel jobs
        self.num_jobs = str(config['jobs'] if 'jobs' in config else 1)

        # ISA and platform spec paths
        self.isa_spec = os.path.abspath(config['ispec'])
        self.platform_spec = os.path.abspath(config['pspec'])

        # Whether to run tests or just compile
        if 'target_run' in config and config['target_run'] == '0':
            self.target_run = False
        else:
            self.target_run = True

    def initialise(self, suite, work_dir, archtest_env):
        self.work_dir = work_dir
        self.suite_dir = suite

        # Compile command template for RISC-V GCC
        self.compile_cmd = 'riscv{1}-unknown-elf-gcc -march={0} \
          -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -g \
          -T ' + self.pluginpath + '/env/link.ld \
          -I ' + self.pluginpath + '/env/ \
          -I ' + archtest_env + ' {2} -o {3} {4}'

        # Build the testbench executable once
        self.build_testbench()
        
        # Make the simulation wrapper script executable
        self.sim_script = os.path.join(self.pluginpath, 'run_sim.sh')
        os.chmod(self.sim_script, 0o755)

    def build_testbench(self):
        """Build the Icarus Verilog testbench for RISCOF"""
        self.tb_exe = os.path.join(self.work_dir, "z_core_riscof_tb.vvp")
        tb_file = os.path.join(self.project_root, "tb", "z_core_riscof_tb.sv")
        
        if not os.path.exists(tb_file):
            logger.error(f"Testbench not found: {tb_file}")
            raise SystemExit(1)

        # Compile testbench with Icarus Verilog
        compile_cmd = f"iverilog -g2012 -I{self.project_root} -o {self.tb_exe} {tb_file}"
        logger.info(f"Compiling testbench: {compile_cmd}")
        
        result = subprocess.run(compile_cmd, shell=True, cwd=self.project_root,
                               capture_output=True, text=True)
        if result.returncode != 0:
            logger.error(f"Testbench compile failed: {result.stderr}")
            raise SystemExit(1)
        logger.info("Testbench compiled successfully")

    def build(self, isa_yaml, platform_yaml):
        ispec = utils.load_yaml(isa_yaml)['hart0']
        self.xlen = ('64' if 64 in ispec['supported_xlen'] else '32')
        self.isa = 'rv' + self.xlen
        
        if "I" in ispec["ISA"]:
            self.isa += 'i'
        if "M" in ispec["ISA"]:
            self.isa += 'm'
        if "F" in ispec["ISA"]:
            self.isa += 'f'
        if "D" in ispec["ISA"]:
            self.isa += 'd'
        if "C" in ispec["ISA"]:
            self.isa += 'c'

        self.compile_cmd = self.compile_cmd + ' -mabi=' + ('lp64 ' if 64 in ispec['supported_xlen'] else 'ilp32 ')

    def runTests(self, testList):
        # Delete Makefile if it already exists
        if os.path.exists(self.work_dir + "/Makefile." + self.name[:-1]):
            os.remove(self.work_dir + "/Makefile." + self.name[:-1])
        
        make = utils.makeUtil(makefilePath=os.path.join(self.work_dir, "Makefile." + self.name[:-1]))
        make.makeCommand = 'make -k -j' + self.num_jobs

        for testname in testList:
            testentry = testList[testname]
            test = testentry['test_path']
            test_dir = testentry['work_dir']
            
            # Output files
            elf = 'my.elf'
            hex_file = 'my.hex'
            sig_file = os.path.join(test_dir, self.name[:-1] + ".signature")
            
            # Compile macros
            compile_macros = ' -D' + " -D".join(testentry['macros'])
            
            # Compile command
            cmd = self.compile_cmd.format(testentry['isa'].lower(), self.xlen, test, elf, compile_macros)

            if self.target_run:
                # Use the wrapper script that properly handles signature extraction
                simcmd = "{0} {1} {2} {3} {4}".format(
                    self.sim_script, elf, hex_file, sig_file, self.tb_exe)
                
                execute = '@cd {0}; {1}; {2};'.format(test_dir, cmd, simcmd)
            else:
                execute = '@cd {0}; {1}; echo "NO RUN";'.format(test_dir, cmd)

            make.add_target(execute)

        make.execute_all(self.work_dir)

        if not self.target_run:
            raise SystemExit(0)
