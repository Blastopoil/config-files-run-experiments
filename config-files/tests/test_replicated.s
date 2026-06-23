.global _start
.text

.option norvc # To stop the nops from being 16 bits sized

# This program tests if using only a GHR with taken predictions and another one with not taken predictions 
# correctly produces a 111... pattern on one and a 000... pattern on the other

# To compile this use:  riscv64-unknown-elf-gcc -static -nostdlib -o test_replicated test_replicated.s

_start:
	li t0, 0
	li t1, 1

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	beqz t0, salto1
	nop
	nop
	nop
	nop
	nop
	nop
salto1:
	beqz t1, salto2
	nop
	nop
	nop
	nop
	nop
	nop
salto2:
	beqz t0, salto3
	nop
	nop
	nop
	nop
	nop
	nop
salto3:
	beqz t1, salto4
	nop
	nop
	nop
	nop
	nop
	nop
salto4:
	beqz t0, salto5
	nop
	nop
	nop
	nop
	nop
	nop
salto5:
	beqz t1, salto6
	nop
	nop
	nop
	nop
	nop
	nop
salto6:
	beqz t0, salto7
	nop
	nop
	nop
	nop
	nop
	nop
salto7:
	beqz t1, salto8
	nop
	nop
	nop
	nop
	nop
	nop
salto8:


	li a7, 93          # RISC-V Linux exit code
    li a0, 0           # Return code set to 0
    ecall
