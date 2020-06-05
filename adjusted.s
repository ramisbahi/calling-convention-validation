.data 
pizza_name: .asciiz "Pizza, name: " 
pizza_d: .asciiz "Pizza, diameter: " 
pizza_price: .asciiz "Pizza, price: " 
PI: .float 3.14159265358979323846 
newline: .asciiz "\n" 
done: .asciiz "DONE" 
success: .asciiz "SUCESS" 
space: .asciiz ", " 
buffer: .space 64 

.text 

main: 
addi $sp, $sp, -4 
sw $ra, 0($sp) 

move $t1, $0 #initializing head to null 
# $t1 = head 
#========TEST======== 
#jr $ra 
#========TEST======== 

jal insert 
jal sort_and_print 
#========TEST======== 
#test: 
#beqz $t1, _test 
# li $v0, 4 
# la $a0, 0($t1) 
# syscall 

# lw $t2, 68($t1) 
# move $t1, $t2 
# j test 

#_test: 

#========TEST======== 


lw $ra, 0($sp) #restoring ra 
addi $sp, $sp, 4 

jr $ra 



insert: 
addi $sp, $sp, -4 
sw $ra, 0($sp) 

li $a0, 72 #making space in heap for a pizza 
li $v0, 9 
syscall 
move $t0, $v0 #t0 is the starting address of the heap memory I just requested 

li $v0, 4 #input pizza name 
la $a0, pizza_name 
syscall 
li $v0, 8 
la $a0, 0($t0) 
li $a1, 64 
syscall 


jal string_compare 


beqz $v0, _continue #if v0 = 0, input did not match 'DONE' and we branch to the rest of insert function 

lw $ra, 0($sp) #restore return to main here so that we can cut insert short if 'DONE' is inputted 
addi $sp, $sp, 4 

jr $ra #otherwise, return to main. 


_continue: 

sw $t1, 68($t0) #storing address in head in this pizza's next 
move $t1, $t0 # shifting head to point to this new pizza 
#we shift head after name input in case user inputs 'DONE' 

li $v0, 4 #input pizza diameter 
la $a0, pizza_d 
syscall 
li $v0, 6 
syscall 
mov.s $f1,$f0 #save piazza diameter into $f1 

li $v0, 4 #input pizza price 
la $a0, pizza_price 
syscall 
li $v0, 6 
syscall 
mov.s $f2,$f0 #save pizza price into $f2 


#calculating price per pizza (ppp) 

li.s $f0, 0.0 
_zero_diameter: 
c.eq.s $f0, $f1 #check if diameter is zero 
bc1t _zero_return 

_zero_price: 
c.eq.s $f0, $f2 #check if price is zero 
bc1t _zero_return 


#calculating price per pizza (ppp) 

mul.s $f0, $f1, $f1 #squared diameter and placed result in $f0 
l.s $f3, PI 
li.s $f5, 0.25 
mul.s $f3, $f3, $f5 
mul.s $f0, $f0, $f3 #multiply by PI/4 to get area 
div.s $f0, $f0, $f2 #divide area by price to get ppp 

_zero_return: 
s.s $f0, 64($t0) #insert pizza ppp into pizza heap memory 

j insert 

string_compare: 
addi $sp, $sp, -28 
sw $s0, 0($sp) 
sw $s1, 4($sp) 
sw $s2, 8($sp) 
sw $s3, 12($sp) 
sw $s4, 16($sp) 
sw $ra, 20($sp) 
sw $s5, 24($sp) 

move $s0, $a0 #passing argument to $s0 
la $s1, done 

jal _loop 

lw $s5, 24($sp) 
lw $ra, 20($sp) 
lw $s4, 16($sp) 
lw $s3, 12($sp) 
lw $s2, 8($sp) 
lw $s1, 4($sp) 
lw $s0, 0($sp) 
addi $sp, $sp, 28 

jr $ra 


_loop: 

lb $s2, ($s0) # $s2 has char from input 
lb $s3, ($s1) # $s3 has char from 'DONE' 

lb $s5, newline 

beq $0, $s3, _null_reached #branch if null terminator is reached for 'DONE' 
seq $s4, $s3, $s2 
beqz $s4, _mismatch #branch to _mismatch if characters do not match 

addi $s0, $s0, 1 #proceeds to next characters 
addi $s1, $s1, 1 
j _loop 
_null_reached: 
addi $s0, $s0, 1 
lb $s2, ($s0) 
seq $t8, $s3, $s2 
beqz $t8, _mismatch 
bnez $t8, _match 
_mismatch: 
lb $s2, 0($s0) 

seq $s3, $s2, $s5 # $s2 has char from input, $s5 is '\n' NOTE: comparing bits 
bnez $s3, _mismatch_return 
addi $s0, $s0, 1 #shift address representing input up by _end_one 

j _mismatch 

_mismatch_return: 
sb $0, 0($s0) #replace '\n' with 0 

li $v0, 0 
jr $ra 

_match: 
li $v0, 1 
jr $ra 

sort_and_print: 
#=======SELECTION SORT=========== 
_sortloop_one: 
beq $t1, $0, _end_one 

move $s0, $t1 # $s0 = max, initialized with head 
lw $s1, 68($t1) # $s1 = current, initialized with head->next 
li $s2, 0 # $s2 = counter, initialized to 0 
# $s3 = max index 

_sortloop_two: 
beq $s1, $0, _end_two 

l.s $f4, 64($s0) # $f4 = ppp of max pizza 
l.s $f5, 64($s1) # $f5 = ppp of current pizza 

c.lt.s $f5, $f4 #checks if which ppp is great 
bc1t _end_if 
c.eq.s $f5, $f4 #checks if ppp is the same 
move $t4, $s0 
move $t5, $s1 
bc1t _strcmp 
move $s0, $s1 #if current ppp is bigger, update max and its index 
move $s3, $s2 
j _end_if 
_strcmp: 
lb $t2, 0($t4) 
lb $t3, 0($t5) 
blt $t2, $t3, _end_if 
blt $t3, $t2, _current_first 
addi $t4, $t4, 1 
addi $t5, $t5, 1 
j _strcmp 

_current_first: 
move $s0, $s1 #if current ppp is bigger, update max and its index 
move $s3, $s2 

_end_if: 
lw $s1, 68($s1) # current = current->next 
addi $s2, $s2, 1 #counter++ 
j _sortloop_two 

_end_two: 
li $v0, 4 #print the pizza info 
la $a0, 0($s0) 
syscall 

li $v0, 4 
la $a0, space 
syscall 

l.s $f4, 64($s0) #retrieve ppp from max 
li $v0, 2 
mov.s $f12, $f4 
syscall 

li $v0, 4 
la $a0, newline 
syscall 


#======relinking list======= 
beq $t1, $s0, _end_if_two 

move $s4, $t1 # s4 = premax 
li $s6, 0 # $s6 just used as index for loop 
_for_loop: 
sge $s5, $s6, $s3 
bnez $s5, _end_for_loop 
lw $s4, 68($s4) # premax = premax->next 
addi $s6, $s6, 1 
j _for_loop 
_end_for_loop: 
lw $s6, 68($s0) #we use $s6 as temp var since for loop index not needed anymore 
sw $s6, 68($s4) 
j _sortloop_one 

_end_if_two: 
lw $t1, 68($t1) #head = head->next 
j _sortloop_one 


#======TEST========== 

#======TEST========== 


_end_one: 
jr $ra 
