import os
import json
import sys
import argparse

# 0th operand is a modified dest register
dest_instructions = set(['add', 'addi', 'addiu', 'addu', 'divu', 'mulu', 'mulou', 'clo', 'clz', 'la', 'li', 'lui', 'move', 'negu', 'seb', 'seh', 'sub', 'subu', 'rotr', 'rotrv', 'sll', 'sllv', 'sra', 'srav', 'srl', 'srlv', 'and', 'andi', 'ext', 'ins', 'nor', 'not', 'or', 'ori', 'wsbh', 'xor', 'xori', 'movn', 'movz', 'slt', 'slti', 'sltiu', 'sltu', 'sgt', 'seq', 'sge', 'sle', 'sgeu', 'sgtu', 'sleu', 'sne', 'mul', 'mfhi', 'mflo', 'jalr', 'lb', 'lbu', 'lh', 'lhu', 'lw', 'lwl', 'lwr', 'ulw', 'll', 'sc', 'l.s'])

# 0th operand is a source register
source_instructions = set(['div', 'divu', 'madd', 'maddu', 'msub', 'msubu', 'mult', 'multu', 'mthi', 'mtlo', 'beq', 'beqz', 'bge', 'ble', 'bgez', 'blt', 'bgt', 'bgezal', 'bgtz', 'blez', 'bltz', 'bltzal', 'bne', 'bnez', 'jr'])

# storing something 
store_instructions = set(['sb', 'sh', 'swl', 'sw', 'swr', 'usw', 's.s', 'swc1'])
load_instructions = set(['lb', 'lh', 'lw'])

# jump or branch
branch_instructions = set(['beq', 'beqz', 'bgez', 'bge', 'ble', 'blt', 'bgt', 'bgezal', 'bgtz', 'blez', 'bltz', 'bltzal', 'bne', 'bnez', 'j', 'b', 'bc1t', 'bc1f'])

other_instructions = set(['jal', 'syscall', 'sw', 'lwc1', 'swc1', 'mfc1', 'mtc1', 'mov.s', 'mov.d', 'li.s', 'li.d', 'c.eq.s', 'c.eq.d', 'c.le.s', 'c.le.d', 'c.lt.s', 'c.lt.d', 'c.gt.s', 'c.gt.d', 'c.ge.s', 'c.ge.d', 'mul.s',  'div.s', 'add.s', 'sub.s', 'sub.d', 's.s', 'l.s', 'l.d', 's.d', 'l.d', 'cvt.s.d', 'cvt.s.w', 'cvt.d.s', 'cvt.d.w', 'cvt.w.d', 'cvt.w.s', 'div.d', 'add.d', 'mul.d', 'abs.d', 'abs.s'])

all_instructions = dest_instructions.union(source_instructions).union(store_instructions).union(branch_instructions).union(other_instructions)

t_regs = set(['$t0', '$t1', '$t2', '$t3', '$t4', '$t5', '$t6', '$t7', '$t8', '$t9'])
callee_regs = set(['$s0', '$s1', '$s2', '$s3', '$s4', '$s5', '$s6', '$s7', '$s8', '$s9', '$ra'])

directives = set(['.data', '.word', '.globl', '.half', '.byte', '.align', '.word', '.float', '.space', '.ascii', '.asciiz', '.text', '.extern'])

instruction_map = {} # maps instruction index to line number
instruction_count_map = {} # maps instruction index to number of times has been done
INSTRUCTION_COUNT_LIMIT = 10 # arbitrary number - to not hit an instruction more than x times (i.e. recursion, branching all over)

def calc_last_op_index(tokens):
    ret = 0
    for i, token in enumerate(tokens):
        if '#' in token: # comment or new line 
            break
        elif token != '':
            ret = i
    return ret

def is_instruction(tokens):
    for token in tokens:
        if '#' in token: 
            break
        if token in all_instructions:
            return True
    return False

# writes adjusted file, also stores index to line
def write_to_adjusted(content):
    index = 0
    with open('adjusted.s', 'w') as adjusted:
        for line_number, line in enumerate(content):
            if '.align' in line or '.end' in line:
                continue # don't write this line
            tokens = line.split()
            comma_instruction = False
            last_op_index = calc_last_op_index(tokens)
            for i, token in enumerate(tokens):
                if token not in all_instructions and token not in directives and ':' not in token and ',' not in token and i < last_op_index: # add comma here
                    adjusted.write(token + ', ')
                elif token[:-1] in all_instructions and token[-1] == ',': # is instruction then comma
                    adjusted.write(token[:-1] + ' ')
                    comma_instruction = True
                elif token != ',':
                    adjusted.write(token + ' ')
            if is_instruction(tokens) or comma_instruction:  
                print(index)
                print(line_number + 1)
                print(tokens)
                print()
                instruction_map[index] = line_number + 1
                index += 1
            adjusted.write('\n')


parser = argparse.ArgumentParser(description='\nAnalyze MIPS file for potential calling convention violations.\n')
parser.add_argument('file', metavar='file_path', type=str, nargs=1, help='Path to MIPS .s file to be analyzed')
try:
    args = parser.parse_args()
except:
    print(parser.print_help())
    sys.exit(0)

source_file = sys.argv[1]

with open(source_file, 'r') as source:
    content = source.readlines()
    source.close()

write_to_adjusted(content) # adds commas, gets rid of .align for parser tool
stream = os.popen('bin/mips-parser -f adjusted.s')
output = stream.read()
parsed = json.loads(output)
instructions = parsed['segments']['.text']['instructions']
labels = parsed['labels']

for index in instruction_map:
    print(index)
    print(instruction_map[index])
    print(instructions[index])
    print()


taken_branch_indices = set() # branches we have taken (index they were called at)

potential_violations = {}

def get_identifier(instruction):
    for operand in instruction['operands']:
        if operand['type'] == 'Identifier':
            return operand['value']
    return ''

def is_fp_instruction(instruction):
    return "." in instruction or "c1" in instruction

def string_instruction(instruction):
    ret = str(instruction['opcode']) + ' '
    if instruction['opcode'] != 'syscall':
        for operand in instruction['operands']:
            value = ""
            if operand['type'] == 'Address':
                value = str(operand['offset']['value']) + "(" + str(operand['base']['value']) + ")"
            elif operand['type'] == 'Unary':
                value = operand['value']['value']
            else:
                value = operand['value']
            ret += str(value) + ', '
    return ret[:-2] 

# checks if any registers in instruction are assumed (i.e. not used as destination earlier in function)
def check_sources(sources, destinations, label, instruction, index, done_jal, branch_path, usable_t_regs):
    for source in sources:
        value = ""
        if source['type'] == 'Register': # is a register
            value = source['value']
        elif source['type'] == 'Address': # is an address
            value = source['base']['value']
        else:
            break # not a register or address operand, not going to find one after this
        violation_message = ""
        violation = False 
        if value not in destinations:
            if do_not_assume_reg(value, done_jal):
                violation = True
                violation_message = "Potential violation: Value of " + value + " is assumed in " + label +" function. This register has not been used as a destination in this context. It should be passed as an argument.\n"
        elif value in t_regs and value not in usable_t_regs: # t register in destinations, but not usable_t_regs
            violation = True
            violation_message = "Potential violation: Value of " + value + " is assumed in " + label +" function. This should have been saved/restored before/after a recent jal in this context.\n"
        
        if violation:
            violation_message += string_instruction(instruction) + " on line " + str(instruction_map[index]) + "\n" 
            path = label + "->" + branch_path
            violation_message += "Path taken: " + path[:-2] + "\n"
            if index not in potential_violations or violation_message.count('->') < potential_violations[index].count('->'): # make sure only replace if less branching
                potential_violations[index] = violation_message 

# register - a register which has been changed (used as a destination), as determined in traversal
# stored - what we have stored in this context
# label - current function  (for print)
# instruction - current instruction (for print)
# index - current index (for line number to print)
# branch_path - current branch path (for print)
# if unstored callee-saved, this is a potential violation (since we know it has been changed)
def check_stored(register, stored, label, instruction, index, branch_path):
    if register in callee_regs and register not in stored: # s/$ra register which hasn't been stored (being changed = uh oh)
        violation_message = "Potential violation: " + register + " changed in " + label + " function and not saved.\n"
        violation_message += string_instruction(instruction) + " on line " + str(instruction_map[index]) + "\n"
        path = label + "->" + branch_path
        violation_message += "Path taken: " + path[:-2] + "\n"
        potential_violations[index] = violation_message

# can't assume vals in these
# if v register - check if recent jal (after jr)
def do_not_assume_reg(register, done_jal):
    if 'v' in register and done_jal: # jal'd earlier in this function, so v can be "assumed" as return value from this
        return False
    return register not in set(['$sp', '$0', '$zero']) and 'a' not in register and 'f' not in register

def is_sp(operand):
    return operand['type'] == 'Address' and operand['base']['value'] == '$sp'

def is_load_from_stack(instruction):
    return instruction['opcode'] in load_instructions and is_sp(instruction['operands'][1])

def is_syscall_10(index):
    if instructions[index]['opcode'] == 'syscall':
        for i in [index-2, index-1]: # see if making $v0 = 10
            if i >= 0 and instructions[i]['opcode'] == 'li' and instructions[i]['operands'][0]['value'] == '$v0' and instructions[i]['operands'][1]['value'] == 10:
                return True
    return False

# to differentiate between t reg which needed to be saved before jal and t register not in current context, have destinations and usable_t_regs - usable resets when jal, destinations doesn't - if not in destinations at all - bad, elif not in usable_t_regs - save from last jal

####### main traversal - checks for potential calling convention violations
# start = starting index
# label = current function label
# stored = things that have been saved
# past destinations = registers used as destination (important bc cannot use as source unless previously used as destination)
# done_jal = boolean value, whether or not jal has been done in this function yet
# branch_path = path from function and branches/jumps
# past_usable_t_regs = t registers which have not been disrupted by jal
def check_function(start, label, past_stored, past_destinations, done_jal, branch_path, past_usable_t_regs):
    destinations = past_destinations.copy()
    stored = past_stored.copy()
    usable_t_regs = past_usable_t_regs.copy()

    index = start
    # go through each instruction in callee function, will not hit same instruction more than INSTRUCTION_COUNT_LIMIT times
    while instructions[index]['opcode'] != 'jr' and not is_syscall_10(index) and (index not in instruction_count_map or instruction_count_map[index] < INSTRUCTION_COUNT_LIMIT): 
        instruction = instructions[index]
        if instruction['opcode'] == 'jal':
            jal_label = instruction['operands'][0]['value']
            check_function(labels[jal_label]['address'], jal_label, set(), set(), False, "", set()) # jal new function, so reset all parameters
            # will also keep going
            usable_t_regs = set() # none now
            check_stored('$ra', stored, label, instruction, index, branch_path) # $ra changed - make sure stored
            done_jal = True
        elif instruction['opcode'] in store_instructions: # store word/half/byte 
            if is_sp(instruction['operands'][1]): # being stored onto stack
                stored.add(instruction['operands'][0]['value'])
            else: # first thing used as source, check this
                source = instruction['operands']
                check_sources(source, destinations, label, instruction, index, done_jal, branch_path, usable_t_regs)
        elif instruction['opcode'] in dest_instructions: # first operator is destination - make sure not changing s value
            changed_reg = instruction['operands'][0]['value']

            if not is_load_from_stack(instruction): # not loading from stack
                check_stored(changed_reg, stored, label, instruction, index, branch_path) # something changed - make sure not unstored callee-saved

                # checking sources before adding as destination - in case reg used as both source and destination, need to make sure not used as source here before destination in prior instruction
                sources = instruction['operands'][1:] # other operands - definitely sources
                check_sources(sources, destinations, label, instruction, index, done_jal, branch_path, usable_t_regs) # make sure have been destination first
            
            destinations.add(changed_reg)
            if changed_reg in t_regs:
                usable_t_regs.add(changed_reg)
        elif instruction['opcode'] in source_instructions: # source instruction - first reg is source
            sources = instruction['operands']
            check_sources(sources, destinations, label, instruction, index, done_jal, branch_path, usable_t_regs)
        elif instruction['opcode'] not in all_instructions:
            print("INSTRUCTION NOT RECOGNIZED", instruction['opcode'], "\n", instruction)

        if instruction['opcode'] in branch_instructions: # branch or jump - take all possible paths
            if index not in taken_branch_indices: # did not do this branch yet, so let's take it
                branch_label = get_identifier(instruction)
                taken_branch_indices.add(index)
                check_function(labels[branch_label]['address'], label, stored, destinations, done_jal, branch_path + branch_label + "->", usable_t_regs)
        if index not in instruction_count_map: 
            instruction_count_map[index] = 1
        else:
            instruction_count_map[index] += 1 # increment number of times this instruction has been done
        if instruction['opcode'] in ['j', 'b']: # jump or branch - stop
            return # stop now
        index += 1
    

check_function(labels['main']['address'], 'main', set(), set(), False, "", set()) # start at main, traverse recursively through all possible paths 

print('')
count = 1
if len(potential_violations) > 0:
    for index in sorted(potential_violations):
        print('{}{} {}'.format(count, ')', potential_violations[index]))
        count += 1
else:
    print("No potential calling convention violations detected. You're good to go!\n")