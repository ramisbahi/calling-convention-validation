# Byseven: Prints out the first N positive integers that are divisible by 7, where N
# is an integer that is input to the program

.text
.align 2
.globl main

main:
    li      $v0, 4              # Print prompt
    la      $a0, prompt         
    syscall                     

    li      $v0, 5              # Read integer, store in t0
    syscall     
    move    $t0, $v0            # t0 holds max multiplier
    move $t4 $t1
    li      $t1, 1              # t1 is the multiplier of 7 (i)
    li      $t2, 7              # t2 is 7

_loop:
    bgt     $t1, $t0, _endloop  # if multiplier is greater than max multiplier end
    mul     $t3, $t1, $t2       # calculate value and store in t3

    li $v0, 1                   #print integer
    move $a0, $t3
    syscall

    li $v0, 4                   #print new line
    la $a0, str_newline
    syscall

    addi $t1, $t1, 1            # increment t1 by one (i++)

    b _loop
_endloop:
    li $v0, 0
    jr $ra

# ======================== end of function: main

# data section

.data
prompt: .asciiz "Please input a positive integer: "
str_newline: .asciiz "\n"       # a literal newline string for printing