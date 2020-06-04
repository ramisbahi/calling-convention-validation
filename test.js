const MIPSParser = require('mips-parser');

const source = `
  li $v0, 4
  la $a0, message
  syscall
`;

console.log(MIPSParser.parse(source)); // MIPS AST