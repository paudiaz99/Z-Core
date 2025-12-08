#ifndef _COMPLIANCE_MODEL_H
#define _COMPLIANCE_MODEL_H

// Data section with tohost/fromhost for signature tracking
#define RVMODEL_DATA_SECTION \
        .pushsection .tohost,"aw",@progbits;                            \
        .align 8; .global tohost; tohost: .dword 0;                     \
        .align 8; .global fromhost; fromhost: .dword 0;                 \
        .popsection;                                                    \
        .align 8; .global begin_regstate; begin_regstate:               \
        .word 128;                                                      \
        .align 8; .global end_regstate; end_regstate:                   \
        .word 4;

// Halt using ECALL - Z-Core halts on ECALL/EBREAK
#define RVMODEL_HALT                                                    \
  ecall;                                                                \
  halt_loop:                                                            \
    j halt_loop;

#define RVMODEL_BOOT

// Begin signature section
#define RVMODEL_DATA_BEGIN                                              \
  RVMODEL_DATA_SECTION                                                  \
  .align 4;                                                             \
  .global begin_signature; begin_signature:

// End signature section
#define RVMODEL_DATA_END                                                \
  .align 4;                                                             \
  .global end_signature; end_signature:

// I/O stubs (not used by Z-Core)
#define RVMODEL_IO_INIT
#define RVMODEL_IO_WRITE_STR(_R, _STR)
#define RVMODEL_IO_CHECK()
#define RVMODEL_IO_ASSERT_GPR_EQ(_S, _R, _I)
#define RVMODEL_IO_ASSERT_SFPR_EQ(_F, _R, _I)
#define RVMODEL_IO_ASSERT_DFPR_EQ(_D, _R, _I)

// Interrupt stubs (not implemented in Z-Core)
#define RVMODEL_SET_MSW_INT
#define RVMODEL_CLEAR_MSW_INT
#define RVMODEL_CLEAR_MTIMER_INT
#define RVMODEL_CLEAR_MEXT_INT

#endif // _COMPLIANCE_MODEL_H
