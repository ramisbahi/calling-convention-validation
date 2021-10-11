
.text 
############################ 
# String comparison function, subtract bytes to see if they equal 0 
############################ 
strcmp: 
lb $t6, 0($a0) 
lb $t7, 0($a1) 
beqz $t7, _finread 
sub $v0, $t6, $t7 
bnez $v0, _endcmp 
addi $a0, $a0, 1 
addi $a1, $a1, 1 
b strcmp 
_endcmp: 
jr $ra 

########################## 
# Function to print string, saved a few lines of instructions 
########################## 
printstring: 
li $v0, 4 
syscall 
jr $ra 

############################ 
# Main function, cobbled together to reduce number of instructions 
########################### 
main: 
addi $sp, $sp, -4 
sw $ra, 0($sp) 

_startread: #Begin the info gathering from console 
la $a0, name 
jal printstring #Ask for name from console 

li $v0, 9 
li $a0, 64 
syscall 
move $s7, $v0 #create and store a buffer to store string input 

li $v0, 8 
move $a0, $s7 
li $a1, 64 
syscall #read/store string from console 

_parse: #isolate newline and replace with a space 
lb $t0, 0($a0) 
li $t1, 0xA 
beq $t0, $t1, _elseparse 
addi $a0, $a0, 1 
b _parse 

_elseparse: 
li $t4, 0x20 
sb $t4, 0($a0) 

# compare input string to DONE, if equals, stop reading and start printing 
move $a0, $s7 
la $a1, DONE 
jal strcmp 

la $a0, size 
jal printstring # ask for diameter from console 

li $v0, 6 
syscall 
mul.s $f1, $f0, $f0 #$f0 read/store diameter, f1 is diameter of pizza squared 

la $a0, price 
jal printstring #ask for price 

li $v0, 6 
syscall #read/store price, and the value in $f0 is price of pizza 


li.s $f5, 0.0 
c.le.s $f0, $f5 
bc1t _maincont #if size is 0, MIPS can still do the math right 
#so check is price is 0, if so then skip the 
#math and use $f5=0 as the pizza per dollar 

#do the math to calculate the pizza per dollar 
l.s $f5, pi4 #pi4 is just pi/4 precalculated since it's basically a constant anyways 
mul.s $f5, $f5, $f1 
div.s $f5, $f5, $f0 

_maincont: 
#malloc space to store the pizza data 
li $a0, 72 
li $v0, 9 
syscall 
move $s1, $v0 #s1 is malloc'd data 

#store data into malloc'd region 
sw $s7, 0($s1) 
s.s $f5, 64($s1) 
sw $zero, 68($s1) 

######################### 
#Sort/insert below, basically a translation of the C code 
########################## 
move $t0, $s0 #current = head 
move $t1, $0 #prev = null 

_sortloop: 
beqz $t0, _endsortloop 
l.s $f0, 64($s1) 
l.s $f1, 64($t0) 
c.lt.s $f0, $f1 
bc1t _sorttrue 

c.eq.s $f0, $f1 
bc1f _endsortloop 

lw $a0, 0($t0) 
lw $a1, 0($s1) 
jal strcmp 

bgtz $v0, _endsortloop 

_sorttrue: 
move $t1, $t0 # prev = current 
lw $t0, 68($t0) # current = current->next 
b _sortloop 

_endsortloop: 
bnez $t1, _sortelse 
move $s0, $s1 # pizzaptr = newpizza 
sw $t0, 68($s1) #newpizza->next = current 
b _startread 

_sortelse: 
sw $s1, 68($t1) #prev->next = newpizza 
sw $t0, 68($s1) #newpizza->next = current 
b _startread 

_finread: # print out the linked list that was made 
beqz $s0, _endmain 
lw $a0, 0($s0) 
jal printstring 
li $v0, 2 
l.s $f12, 64($s0) 
syscall 
la $a0, nln 
jal printstring 
lw $s0, 68($s0) 
b _finread 

_endmain: #ends the program 
lw $ra, 0($sp) 
addiu $sp, $sp, 4 
jr $ra 

.data 
name: .asciiz "Pizza, name: " 
size: .asciiz "Pizza, diameter: " 
price: .asciiz "Pizza, cost: " 
nln: .asciiz "\n" 
pi4: .float 0.785398163397448309615 
DONE: .asciiz "DONE" 
