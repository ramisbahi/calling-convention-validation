# This version of PizzaCalc is the 9th major revision. I have heavily 
# edited my original solution to reduce the instruction count. To do this, 
# most of the functions that only one fixed caller have been moved to inside 
# of main, eliminating most jal's and reducing stack saves for registers. 
# Doing so also enabled variables to be passed through multiple subfunctions 
# without needing to be copied to a and v registers at each return, further 
# reducing instruction count. 
# 
# However, as a result, the code is now more difficult to follow for lack
# of clear divisions between functions that used to be separate. You can review
# my revision history to see earlier versions of the code that had more
# instructions but a more reader friendly organization. 


.align 2
.text
.globl main

# Compares two strings (hopefully) if a0>a1, v0>0
# takes inputs from a0 and a1
# returns to v0
str_compare: 
    lb      $t0, 0($a0)     # char of a0 in t0
    lb      $t1, 0($a1)     # char of a1 in t1

    bne     $t0 $t1, _str_compare_ret        # if current char not equal return

    addi    $a0, 1          # if current char equal then look at next char
    addi    $a1, 1
    bnez    $t0, str_compare    # if end of a0, fall through to return

_str_compare_ret: 
    sub     $v0, $t0 $t1    # find difference between t0 and t1, will be 0 if equal
    jr      $ra             # return the difference

_print:
    li      $v0, 4
    syscall
    jr $ra

# Main (many subfunctions are inside main to reduce the need for jal, 
# thereby reducing the need for callee saved registers, thereby reducing
# instruction count.) 
# The entire _get_pizza_loop ultimately yields a pointer to the head
# of the list in s0
main: 
    # Save main's return address
    addi    $sp, $sp -4
    sw		$ra, 0($sp)		

    # Head pointer is s0, 0 to begin with, will be 
    # updated each time _get_pizza_loop runs

    # Get the next pizza

# Subfunction: gets user input and creates a pizza node
# with the next field set to null
# returns pizza pointer in s2
_get_pizza_loop: 
    # Allocating heap space for node
    # |--------------name: 64------------|---PPD: 4----|----next: 4-----|
    li      $a0, 72
    li      $v0, 9
    syscall
    move    $s5, $v0        # pointer to allocated heap in s5

    # Getting name
    la $a0 PIZZA_NAME_PROMPT    # Prompt user for pizza name
    jal _print


    li      $v0, 8          # read console input into heap
    move      $a0, $s5
    li      $a1, 64
    syscall

    # Removing the new line character at end of input
    move    $t0, $s5     # make copy of heap pointer
_remove_nln: 
    lb      $t1, 0($t0)     # load a char of name
    addi    $t0, 1          # increment by 1 char
    bnez    $t1, _remove_nln  # keep searching for eos

    addi    $t0, -2         # on finding eos, back up 2 bytes to nln
    li      $t9 32
    sb      $t9, 0($t0)   # overwrite nln with space

    # Check for DONE
    la      $a1, done       # place DONE into a1 to compare
    jal     str_compare

    beqz    $v0, _no_pizza  # if done, pass 0 in v0 


    la $a0 DIAMETER_PROMPT    # Prompt user for pizza name
    jal _print


    li      $v0, 6          # read console input into f0
    syscall 
    mov.s 	$f4, $f0		# copy diameter to f4


    la $a0 COST_PROMPT    # Prompt user for pizza name
    jal _print


    li      $v0, 6          # read console input into f0
    syscall 

    c.eq.s  $f0, $f10       # check for 0 by comparing to an empty register
    bc1t    _return_node    # if cost is 0 return without calculating

    # Calculating pizza per dollar
    mul.s   $f4, $f4 $f4    # f4 = diam^2
    l.s     $f6, PIdiv4     # f6 = PI/4
    mul.s   $f4, $f4 $f6    # f4 = area of pizza
    div.s   $f4, $f4 $f0    # f4 = pizza per dollar

    swc1    $f4, 64($s5)     # store pizza per dollar to node


_return_node: 

    # passes pointer of node on successful retrieval 
    # in s2
    move    $s2, $s5       

_no_pizza: 

    beqz    $v0, _print_list    # check v0, if no more pizza, start printing


    move     $s4, $s0           # make copy of s0 in s4 for insertion


# Subfunction: inserts new pizza to correct place in linked list
# gets current pizza from s2
# gets head pointer from s4
# will update s0 with new head when done
_insert: 

#     // Declare a prev placeholder and an iterator
#     Pizza* prev = NULL;       
#     Pizza* iter = *head;
    move    $s1, $s4    # iter is in s1
    li      $s3, 0      # prev is in s3

# Find the place to insert 
_find_insert: 
#     while (iter != NULL && iter->pizzaPerDollar > current->pizzaPerDollar){
    beqz    $s1, _next          # end the loop if at end of list

    move    $a0, $s2            # hold current in a0
    move    $a1, $s1            # hold iter in a1

# Subfunction: comparator for nodes
# Copies current in a0 and iter in a1
# Calls str_compare if PPD is equal
# Puts comparison result in v0
_node_comparator:
    # First compare PPD
    lwc1    $f12, 64($a1)       # hold iter.pizzaPerDollar in f12
    lwc1    $f13, 64($a0)       # hold current.pizzaPerDollar in f13
    sub.s   $f0, $f12 $f13      # compare floats
    mfc1    $v0, $f0            # comparison result is in v0
    bnez    $v0, _node_compare_done  # if mismatch, comparison done

    # If PPD is equal, compare names
    jal     str_compare     

_node_compare_done: 

    # v0 contains comparison result
    blez    $v0, _next          # if iter <= current, end loop

    # Otherwise keep searching
#         prev = iter;
    move    $s3, $s1 
#         iter = iter->next;
    lw      $s1, 68($s1)
#     }
    b       _find_insert        # loop back
    
_next:
#   If this is the first node
#     if (prev == NULL){
    bnez    $s3, _put_node
#         current->next = iter; // Add the node to the beginning
    sw      $s1, 68($s2)
#         *head = current; // And update the head pointer's pointer
    move    $s4, $s2
    b       _head_return        # skip the next block
#     }
            
# Insert the new node right here
_put_node: 
#         prev->next = current;
    sw      $s2, 68($s3)

#         current->next = iter;
    sw      $s1, 68($s2)
#     }
      #     return;
_head_return: 
    # Update the head pointer (s0)
    move    $s0, $s4


    b       _get_pizza_loop # keep getting pizzas
    

_print_list: 
    # Printing results
    la      $a0, 0($s0)     # print name
    jal _print

    li      $v0, 2          # print pizza per dollar
    lwc1    $f12, 64($s0)
    syscall

    la      $a0, nln
    jal _print

    lw      $s0, 68($s0)    # head = head.next
    bnez    $s0, _print_list       

_exit: 
    # Restore main return address
    lw      $ra, 0($sp)
    addi    $sp, 4
    jr		$ra	

.data
PIZZA_NAME_PROMPT:    .asciiz     "Pizza name: "
DIAMETER_PROMPT:        .asciiz     "Pizza diameter: "
COST_PROMPT:            .asciiz     "Pizza cost: "
prompt: .asciiz "Input: "
nln:    .asciiz "\n"
space:  .asciiz " " 
done:   .asciiz "DONE "

PIdiv4: .float 0.7853981634
