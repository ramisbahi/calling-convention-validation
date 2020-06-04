.text

main:
    addi $sp, $sp, -28
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    sw $s4, 20($sp)
    sw $s5, 24($sp)

    beqz $t8 _loop

    li $s1 0 

_loop:
    la $a0, askname
    li $v0, 4
    syscall

    li $v0, 8
    la $a0, buffer
    li $a1, 68
    syscall

    move $s0, $a0 
    la $a1, done

    jal removenl
    move $a0, $s0 

    jal strcmp
    beq $v0, 0, _end

    la $a0, askdia
    li $v0, 4
    syscall

    li $v0,6
    syscall
    mov.s $f6, $f0 

    la $a0, askcos
    li $v0, 4
    syscall

    li $v0,6
    syscall
    mov.s $f7, $f0 

    l.s $f3, PI
    l.s $f4, four
    l.s $f5, zero

    c.eq.s $f7, $f5
    bc1t _ifzero


    mul.s $f6, $f6, $f6
    mul.s $f6, $f6, $f3
    div.s $f6, $f6, $f4
    div.s $f6, $f6, $f7

_build1:
    beq $s1, 1, _build2
    li $a0, 76
    li $v0, 9
    syscall
    move $s3, $v0
    move $a1, $v0
    move $a0, $s0
    li $t0, 0
    jal strcpy 
    s.s $f6, 68($s3)
    sw $t0, 72($s3)
    li $s1, 1
    move $s5, $s3
    j _loop

_build2:
    li $a0, 76
    li $v0, 9
    syscall
    move $s4, $v0
    move $a1, $v0
    move $a0, $s0
    li $t0, 0    
    jal strcpy
    move $t5, $t0
    s.s $f6, 68($s4)
    sw $t0, 72($s4)
    sw $s4, 72($s5)
    move $s5, $s4    
    j _loop

_end:
    move $a0, $s3
    jal givemax
    move $s3, $v0
    move $s5, $s3


_endloop:
    beq $v1, 0, _print
    move $a0, $v1
    jal givemax
    sw $v0, 72($s5)
    move $s5, $v0
    
    j _endloop
        
_print:
    move $a0, $s3
    li $v0, 4
    syscall

    la $a0, space
    li $v0, 4
    syscall

    l.s $f12, 68($s3)
    li $v0, 2
    syscall
    
    la $a0, nl
    li $v0, 4
    syscall

    lw $s3, 72($s3)
    beq $s3, 0,_final
    j _print

_final:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    lw $s5, 24($sp)
    addi $sp, $sp, 28
    jr $ra

_ifzero:
    l.s $f6,zero
    j _build1



strcmp: 
    # addi $sp, $sp, -4
    # sw $s5, 0($sp)

    lb $t0, 0($a0)
    lb $t1, 0($a1)
    

    bgt $t0, $t1, _retg
    blt $t0, $t1, _retl 
    beq $t1, 0, _reteq
    move $t8, $s7
    li $s7, 0


    addi $a0, $a0, 1
    addi $a1, $a1, 1
    j strcmp

_retg:
    li $v0, 1
    # lw $s5, 0($sp)
    # addi $sp, $sp, 4
    jr $ra

_retl:
    li $v0, -1
    jr $ra

_reteq:
    li $v0, 0
    jr $ra

strcpy:
    lb $t0, 0($a0)
    sb $t0, 0($a1)
    beq $t0, 0, _strcpyret
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    j strcpy

_strcpyret: 
    jr $ra


removenl:
    lb $t0, 0($a0)
    beq $t0, 10, _rm
    addi $a0, $a0, 1
    j removenl
_rm:
    li $t0, 0 
    sb $t0, 0($a0)
    jr $ra

givemax:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    move $t0, $a0 
    lw $t1, 72($t0)
    beq $t1, 0, _retzero

    move $t2, $t0 #max
    move $t3, $t0 #begin 
    
_maxloop:
    lw $t4, 72($t0)
    beq $t4, 0, _retmax
    move $t5, $t0 #tprevious
    lw $t0, 72($t0) #list = list.next
    l.s $f4, 68($t0) #list value
    l.s $f5, 68($t2) #maximum value

    c.lt.s $f5, $f4 #branch if max is less than list
    bc1t _update

    c.eq.s $f5, $f4  #branch if max is equal to list
    bc1t _checkstr
    j _maxloop

_checkstr:
    addi $sp, $sp, -32
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    sw $t2, 8($sp)
    sw $t3, 12($sp)
    sw $t4, 16($sp)
    sw $t5, 20($sp)
    sw $t6, 24($sp)
    sw $t7, 28($sp)

    move $a0, $t0
    move $a1, $t2
    jal strcmp       #compare max and list strings

    lw $t0, 0($sp)
    lw $t1, 4($sp)
    lw $t2, 8($sp)
    lw $t3, 12($sp)
    lw $t4, 16($sp)
    lw $t5, 20($sp)
    lw $t6, 24($sp)
    lw $t7, 28($sp)

    addi $sp, $sp, 32

    beq $v0, -1, _update  #update if list string is less than max string
    j _maxloop

_update:           
    move $t2, $t0 #max = list
    move $t6, $t5 #previous = tprevious
    j _maxloop
    

_retzero:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    move $v0, $t0
    li $v1, 0 
    jr $ra

_retmax:
    beq $t3, $t2, _retmaxeq
    lw $t7, 72($t2)
    sw $t7, 72($t6)
    sw $t3, 72($t2)
    move $t3, $t2

    lw $v1, 72($t3)
    move $v0, $t3

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
_retmaxeq:
    lw $v1, 72($t3)
    move $v0, $t3
    lw $ra, 0($sp)
    addi $sp, $sp, 4
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