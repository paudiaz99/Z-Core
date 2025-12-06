/* Z-Core RISCOF Linker Script */

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
    /* Z-Core memory map: 0x00000000 - 0x0000FFFF (64KB) */
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS {
    /* Code section - starts at reset vector */
    .text : {
        *(.text.init)
        *(.text)
        *(.text.*)
    } > RAM

    /* Read-only data */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > RAM

    /* Initialized data */
    .data : {
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
    } > RAM

    /* Signature section - RISCOF extracts this region */
    .signature : {
        . = ALIGN(4);
        begin_signature = .;
        *(.data.signature)
        *(.signature)
        . = ALIGN(4);
        end_signature = .;
    } > RAM

    /* tohost/fromhost - used by some compliance tests */
    .tohost : {
        *(.tohost)
    } > RAM

    /* Uninitialized data */
    .bss : {
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
    } > RAM

    /* Stack - grows downward from end of RAM */
    _stack_start = ORIGIN(RAM) + LENGTH(RAM);
}
