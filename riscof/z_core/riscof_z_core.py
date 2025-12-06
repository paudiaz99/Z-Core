"""
Z-Core RISCOF DUT Plugin

This plugin handles building and running RISCOF architectural tests
on the Z-Core RISC-V processor using Icarus Verilog simulation.
"""

import os
import re
import shutil
import subprocess
import logging

import riscof.utils as utils
from riscof.pluginTemplate import pluginTemplate

logger = logging.getLogger()


class z_core(pluginTemplate):
    """RISCOF DUT plugin for Z-Core RISC-V processor."""

    __model__ = "z_core"
    __version__ = "1.0.0"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Configuration populated by RISCOF
        self.dut_exe = ""
        self.num_jobs = 1
        self.pluginpath = os.path.dirname(__file__)
        self.isa_spec = os.path.join(self.pluginpath, "z_core_isa.yaml")
        self.platform_spec = os.path.join(self.pluginpath, "z_core_platform.yaml")

    def initialise(self, suite, work_dir, compliance_env):
        """
        Initialize the DUT plugin.

        Args:
            suite: Path to the test suite
            work_dir: Working directory for test execution
            compliance_env: Environment variables for test compliance
        """
        self.suite = suite
        self.work_dir = work_dir
        self.compile_cmd = self.dut_exe if self.dut_exe else "riscv32-unknown-elf-gcc"

        # Path to Z-Core RTL and testbench
        self.rtl_path = os.path.abspath(os.path.join(self.pluginpath, "..", "..", "rtl"))
        self.tb_path = os.path.abspath(os.path.join(self.pluginpath, "..", "..", "tb"))

        # Environment files
        self.env_dir = os.path.join(self.pluginpath, "env")

    def build(self, isa_yaml, platform_yaml):
        """
        Build the DUT simulator if needed.
        
        For Z-Core, we compile the Icarus Verilog testbench once.
        """
        # The RISCOF testbench is separate from the main testbench
        self.riscof_tb = os.path.join(self.tb_path, "z_core_riscof_tb.sv")

        if not os.path.exists(self.riscof_tb):
            logger.warning(f"RISCOF testbench not found at {self.riscof_tb}")
            logger.warning("Using main testbench - manual signature extraction required")
            return

        # Compile the RISCOF testbench
        sim_dir = os.path.join(self.pluginpath, "..", "..", "sim")
        os.makedirs(sim_dir, exist_ok=True)
        
        self.vvp_path = os.path.join(sim_dir, "z_core_riscof.vvp")

        compile_cmd = [
            "iverilog",
            "-g2012",
            "-o", self.vvp_path,
            f"-I{self.rtl_path}",
            self.riscof_tb
        ]

        logger.info(f"Compiling Z-Core RISCOF testbench...")
        try:
            result = subprocess.run(compile_cmd, capture_output=True, text=True, check=True)
            logger.info("Z-Core testbench compiled successfully")
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to compile testbench: {e.stderr}")
            raise

    def runTests(self, testlist):
        """
        Run the architectural tests.

        Args:
            testlist: Dictionary of tests to run
        """
        for test_name, test_info in testlist.items():
            test_entry = test_info["test_entry"]
            work_dir = test_info["work_dir"]
            isa = test_info["isa"]

            # Paths
            elf_file = os.path.join(work_dir, f"{test_name}.elf")
            hex_file = os.path.join(work_dir, f"{test_name}.hex")
            sig_file = os.path.join(work_dir, f"{test_name}.signature")
            log_file = os.path.join(work_dir, f"{test_name}.log")

            logger.info(f"Running test: {test_name}")

            # Step 1: Compile test to ELF
            compile_cmd = [
                self.compile_cmd,
                "-march=rv32i",
                "-mabi=ilp32",
                "-static",
                "-mcmodel=medany",
                "-fvisibility=hidden",
                "-nostdlib",
                "-nostartfiles",
                f"-I{self.env_dir}",
                f"-T{os.path.join(self.env_dir, 'link.ld')}",
                test_entry,
                "-o", elf_file
            ]

            try:
                subprocess.run(compile_cmd, capture_output=True, text=True, check=True)
            except subprocess.CalledProcessError as e:
                logger.error(f"Compile failed for {test_name}: {e.stderr}")
                continue

            # Step 2: Convert ELF to hex for Verilog $readmemh
            objcopy_cmd = [
                "riscv32-unknown-elf-objcopy",
                "-O", "verilog",
                elf_file,
                hex_file
            ]

            try:
                subprocess.run(objcopy_cmd, capture_output=True, text=True, check=True)
            except subprocess.CalledProcessError as e:
                logger.error(f"Objcopy failed for {test_name}: {e.stderr}")
                continue

            # Step 3: Extract signature bounds from ELF
            sig_begin, sig_end = self._get_signature_bounds(elf_file)
            if sig_begin is None:
                logger.warning(f"Could not find signature bounds for {test_name}")
                continue

            # Step 4: Run simulation
            sim_cmd = [
                "vvp",
                self.vvp_path,
                f"+hex_file={hex_file}",
                f"+sig_file={sig_file}",
                f"+sig_begin={sig_begin}",
                f"+sig_end={sig_end}"
            ]

            try:
                with open(log_file, "w") as log:
                    subprocess.run(sim_cmd, stdout=log, stderr=subprocess.STDOUT, timeout=60)
            except subprocess.TimeoutExpired:
                logger.error(f"Simulation timeout for {test_name}")
                continue
            except Exception as e:
                logger.error(f"Simulation error for {test_name}: {e}")
                continue

            logger.info(f"Completed: {test_name}")

    def _get_signature_bounds(self, elf_file):
        """
        Extract begin_signature and end_signature addresses from ELF.
        """
        try:
            nm_cmd = ["riscv32-unknown-elf-nm", elf_file]
            result = subprocess.run(nm_cmd, capture_output=True, text=True, check=True)

            sig_begin = None
            sig_end = None

            for line in result.stdout.splitlines():
                parts = line.split()
                if len(parts) >= 3:
                    addr = int(parts[0], 16)
                    name = parts[2]
                    if name == "begin_signature":
                        sig_begin = addr
                    elif name == "end_signature":
                        sig_end = addr

            return sig_begin, sig_end

        except Exception as e:
            logger.error(f"Failed to extract signature bounds: {e}")
            return None, None
