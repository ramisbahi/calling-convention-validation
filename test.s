.text

main:
    addi $sp,$sp,-28
    sw $ra,0($sp)
    sw $s1, 4($sp)
    beqz $t8, _loop    

    li $s1, 0 

_loop:
    

_build1:
    beq $s1, 1, _build2
    jr $ra

_build2:
    jr $ra


.data
askname: .asciiz "Pizza name:"
askdia: .asciiz "Pizza diameter:"
askcos: .asciiz "Pizza cost:"
done: .asciiz "DONE"
buffer: .space 68
PI: .float 3.14159265358979323846
four: .float 4.0
zero: .float 0.0
nl: .asciiz "\n"
space: .asciiz " "