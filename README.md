# calling-convention-validation

This Python script allows you to analyze a MIPS file for potential calling convention violations. There are essentially three categories of potential violations:
* Assuming a value in a register which isn’t $a (determined by not having used this register as a destination previously in this function) - should be passed as arg 
* Assuming a value in a $t register which was not saved/restored before/after jal 
* Changing an unstored $s register 

There are all checked in the context of each function (something which is called by a jal). Different paths are navigated through branching, as well.

Before using the Python script (callconv.py), the parser must be installed.

### Cloning repository and installing parser

```
https://github.com/ramisbahi/calling-convention-validation.git
cd calling-convention-validation
npm install
npm run build

bin/mips-parser --help # validate that parser is working
```


### Usage 

To analyze a MIPS .s file:

```
python3 callconv.py filepath
```

To get a help/usage message:

```
python3 callconv.py -h
```

### Handling Errors

There can be errors parsing the MIPS instructions. If you see a SyntaxError, check to see where it is coming from. 

If it looks like a valid MIPS instruction/syntax (i.e. li.s $f18, 0.0), the instruction may be missing from either the JavaScript parser itself (in which case you can add it on line 263 of index.js) or it is not an instruction in one of the sets in the Python script. In the latter case, determine what kind of instruction it is and add it to the appropriate set.
 
If it looks like an invalid instruction/syntax (i.e. li, $t0, 4), there is either a syntax error in the original code (which simply must be edited out by hand), or it has been converted incorrectly (to the adjusted.s file). In the latter case, edit the adjusted.s file directly and please contact me.


### Notes for ECE/CS250 at Duke

In many cases, you will see a lot of similar violations. For instance, if a particular $t register is not saved before/after a jal and used repeatedly after, each of those uses is reported as a separate violation. Keep in mind that this will not necessarily equate to multiple violations when grading. Such an error could simply be commented where the jal occurs.


### Resources

The `mips-parser` is implemented using [Syntax](https://github.com/DmitrySoshnikov/syntax) tool, which generates a LALR(1) parser based on the MIPS [grammar](https://github.com/DmitrySoshnikov/mips-parser/blob/master/mips.g). The parser is adapted from Dmitry Soshnikov, with some modifications to support more MIPS instructions.
