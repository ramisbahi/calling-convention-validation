import os
import json
import sys

# 0th operand is a modified dest register
dest_instructions = set(['add', 'addi', 'addiu', 'addu', 'clo', 'clz', 'la', 'li', 'lui', 'move', 'negu', 'seb', 'seh', 'sub', 'subu', 'rotr', 'rotrv', 'sll', 'sllv', 'sra', 'srav', 'srl', 'srlv', 'and', 'andi', 'ext', 'ins', 'nor', 'not', 'or', 'ori', 'wsbh', 'xor', 'xori', 'movn', 'movz', 'slt', 'slti', 'sltiu', 'sltu', 'sgt', 'seq', 'sge', 'sle', 'sgeu', 'sgtu', 'sleu', 'sne', 'mul', 'mfhi', 'mflo', 'jalr', 'lb', 'lbu', 'lh', 'lhu', 'lw', 'lwl', 'lwr', 'ulw', 'll', 'sc'])

# 0th operand is a source register
source_instructions = set(['div', 'divu', 'madd', 'maddu', 'msub', 'msubu', 'mult', 'multu', 'mthi', 'mtlo', 'beq', 'beqz', 'bgez', 'blt', 'bgt', 'bgezal', 'bgtz', 'blez', 'bltz', 'bltzal', 'bne', 'bnez', 'jr'])

# storing something
store_instructions = set(['sb', 'sh', 'swl', 'sw', 'swr', 'usw'])

# jump or branch
branch_instructions = set(['beq', 'beqz', 'bgez', 'blt', 'bgt', 'bgezal', 'bgtz', 'blez', 'bltz', 'bltzal', 'bne', 'bnez', 'j', 'b', 'bc1t', 'bc1f'])

other_instructions = set(['jal', 'syscall', 'sw', 'lwc1', 'swc1', 'mfc1', 'mtc1', 'mov.s', 'li.s', 'c.eq.s', 'c.le.s', 'c.lt.s', 'c.gt.s', 'c.ge.s', 'mul.s', 'mul.s', 'div.s', 'add.s', 'sub.s', 's.s', 'l.s', 's.d', 'l.d'])

t_regs = set(['$t0', '$t1', '$t2', '$t3', '$t4', '$t5', '$t6', '$t7', '$t8', '$t9'])
s_regs = set(['$s0', '$s1', '$s2', '$s3', '$s4', '$s5', '$s6', '$s7', '$s8', '$s9'])

instruction_map = {} # maps index to line number

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
        if token in dest_instructions.union(source_instructions).union(store_instructions).union(branch_instructions).union(other_instructions):
            return True
    return False

# writes adjusted file, also stores index to line
def write_to_adjusted(content):
    with open('adjusted.s', 'r') as adjusted: # allows us to overwrite
        adjusted.read()

    index = 0
    with open('adjusted.s', 'w') as adjusted:
        for line_number, line in enumerate(content):
            if '.align' in line:
                continue # don't write this line
            tokens = line.split()
            last_op_index = calc_last_op_index(tokens)
            for i, token in enumerate(tokens):
                if '$' in token and ',' not in token and i < last_op_index:
                    adjusted.write(token + ', ')
                else:
                    adjusted.write(token + ' ')
            if is_instruction(tokens):
                # print(index)
                # print(line_number + 1)
                # print(tokens)
                # print()
                instruction_map[index] = line_number + 1
                index += 1
            adjusted.write('\n')

source_file = 'test.s'
if len(sys.argv) > 1:
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
    return ret[:-2] + '\n'

# checks if any registers in instruction are assumed (i.e. not used as destination earlier in function)
def check_sources(sources, past_destinations, label, instruction, index, done_jal):
    for source in sources:
        value = ""
        if source['type'] == 'Register': # is a register
            value = source['value']
        elif source['type'] == 'Address': # is an address
            value = source['base']['value']
        else:
            break # not a register or address operand, not going to find one after this
        if value not in past_destinations and do_not_assume_reg(value, index, done_jal):
            violation_message = ""
            if value in t_regs:
                violation_message = "Potential violation: value of " + value + " is assumed in " + label +". This may be due to not saving before/after a jal in this context, or simply not having used this register as a destination in this context.\t"
            else:
                violation_message = "Potential violation: value of " + value + " is assumed in " + label +".\t"
            violation_message += string_instruction(instruction) + " on line " + str(instruction_map[index]) + "\n" 
            potential_violations[index] = violation_message

# can't assume vals in these
# if v register - check if recent jal (after jr)
def do_not_assume_reg(register, index, done_jal):
    if 'v' in register and done_jal: # jal'd earlier in this function, so v can be "assumed" as return value from this
        return False
    return register != '$sp' and register != '$0' and 'a' not in register

# start = starting index
# label = current function label
# stored = things that have been saved
# past destinations = registers used as destination (important bc cannot use as source unless previously used as destination)
# t_reg_used = t registers that have been used so far 
# done_jal = boolean value, whether or not jal has been done in this function yet
def check_function(start, label, stored, past_destinations, done_jal):
    index = start
    while instructions[index]['opcode'] != 'jr': # go through each instruction in callee function
        instruction = instructions[index]
        if instruction['opcode'] == 'jal':
            jal_label = instruction['operands'][0]['value']
            check_function(labels[jal_label]['address'], jal_label, set(), set(), False) # jal new function, so reset all parameters
            for register in t_regs: # t registers removed from past destinations after jal - cannot be used after unless restored
                past_destinations.discard(register)
            done_jal = True
        elif instruction['opcode'] in store_instructions: # store word/half/byte
            if instruction['operands'][1]['base']['value'] == '$sp': # being stored onto stack
                stored.add(instruction['operands'][0]['value'])
            else: # first thing used as source, check this
                source = instruction['operands']
                check_sources(source, past_destinations, label, instruction, index, done_jal)
        elif instruction['opcode'] in dest_instructions: # first operator is destination - make sure not changing s value
            if instruction['opcode'] == 'lw' and instruction['operands'][1]['base']['value'] == '$sp': # loading from stack
                if(instruction['operands'][0]['value'] in t_regs):
                    past_destinations.add(instruction['operands'][0]['value']) # loaded t register (likely after jal), so can use value
                index += 1
                continue # not actually changing value (in fact, restoring), so don't worry about anything else
            changed_reg = instruction['operands'][0]['value']
            
            if changed_reg in s_regs and changed_reg not in stored: # s register which hasn't been stored
                violation_message = "Potential violation: " + changed_reg + " changed in " + label + " and not saved.\t"
                violation_message += string_instruction(instruction) + " on line " + str(instruction_map[index]) + "\n"
                potential_violations[index] = violation_message

            sources = instruction['operands'][1:] # other operands - definitely sources
            check_sources(sources, past_destinations, label, instruction, index, done_jal) # check sources first - in case reg used as source and destination, need to make sure not used as source before destination

            past_destinations.add(changed_reg)
        elif instruction['opcode'] in source_instructions: # source instruction - first reg is source
            sources = instruction['operands']
            check_sources(sources, past_destinations, label, instruction, index, done_jal)
        elif not is_fp_instruction(instruction['opcode']) and instruction['opcode'] != 'syscall' and instruction['opcode'] not in branch_instructions:
            print("INSTRUCTION NOT RECOGNIZED", instruction['opcode'], "\n", instruction)

        if instruction['opcode'] in branch_instructions: # branch or jump
            if index not in taken_branch_indices: # did not do this branch yet, so let's take it
                branch_label = get_identifier(instruction)
                taken_branch_indices.add(index)
                check_function(labels[branch_label]['address'], label, stored, past_destinations, done_jal)
        index += 1

check_function(labels['main']['address'], 'main', set(), set(), False)
for index in sorted(potential_violations):
    print(potential_violations[index])