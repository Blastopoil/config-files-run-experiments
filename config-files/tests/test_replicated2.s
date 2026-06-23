.global _start
.text

.option norvc # To stop the nops from being 16 bits sized

# This program tests if using only one GHR correctly produces a 1010... alternating pattern

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

.align 4

	beqz t0, salto1
	nop
salto1:
	beqz t1, salto2
	nop
salto2:
	beqz t0, salto3
	nop
salto3:
	beqz t1, salto4
	nop
salto4:
	beqz t0, salto5
	nop
salto5:
	beqz t1, salto6
	nop
salto6:
	beqz t0, salto7
	nop
salto7:
	beqz t1, salto8
	nop
salto8:

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	li a7, 93          # RISC-V Linux exit code
    li a0, 0           # Return code set to 0
    ecall
