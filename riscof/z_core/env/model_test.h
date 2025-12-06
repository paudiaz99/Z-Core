// Z-Core RISCOF Model Test Header
// This file defines the macros required by RISCOF architectural tests

#ifndef _MODEL_TEST_H
#define _MODEL_TEST_H

//-----------------------------------------------------------------------
// RV Software Compliance Test Macros
//-----------------------------------------------------------------------

// Signature region labels - used by RISCOF to extract test results
#define RVMODEL_DATA_SECTION \
    .pushsection .tohost,"aw",@progbits; \
    .align 8; .global tohost; tohost: .dword 0;  \
    .align 8; .global fromhost; fromhost: .dword 0; \
    .popsection; \
    .section .data.signature,"aw",@progbits; \
    .align 4; .global begin_signature; begin_signature:

#define RVMODEL_DATA_BEGIN \
    RVMODEL_DATA_SECTION

#define RVMODEL_DATA_END \
    .align 4; .global end_signature; end_signature: \
    .align 4; .global rvtest_sig_begin; rvtest_sig_begin: \
    .fill 64, 4, 0xdeadbeef; \
    .align 4; .global rvtest_sig_end; rvtest_sig_end:

// Halt macro - triggers ECALL to signal test completion
// The testbench monitors the halt signal and extracts signature
#define RVMODEL_HALT \
    li gp, 1;  \
    ecall;

// Boot code section
#define RVMODEL_BOOT \
    .section .text.init; \
    .globl _start; \
    _start:

// IO macros - not used in Z-Core (no tohost/fromhost interface)
#define RVMODEL_IO_INIT
#define RVMODEL_IO_WRITE_STR(_R, _STR)
#define RVMODEL_IO_CHECK()
#define RVMODEL_IO_ASSERT_GPR_EQ(_S, _R, _I)
#define RVMODEL_IO_ASSERT_SFPR_EQ(_F, _R, _I)
#define RVMODEL_IO_ASSERT_DFPR_EQ(_D, _R, _I)

// Set base address for signature updates
#define RVTEST_SIGBASE(BaseReg, Val) \
    la BaseReg, Val;

// Update signature with register value
#define RVTEST_SIGUPD(BaseReg, SigReg) \
    sw SigReg, 0(BaseReg); \
    addi BaseReg, BaseReg, 4;

// Set exception handling to trap handler
#define RVMODEL_SET_MSW_INT
#define RVMODEL_CLEAR_MSW_INT
#define RVMODEL_CLEAR_MTIMER_INT
#define RVMODEL_CLEAR_MEXT_INT

#endif // _MODEL_TEST_H
