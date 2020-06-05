# calling-convention-validation

This Python script allows you to analyze a MIPS file for potential calling convention violations. There are essentially three categories of potential violations:
* Assuming a value in a register which isn’t $a (determined by not having used this register as a destination previously in this function) - should be passed as arg 
* Assuming a value in a $t register which was not saved/restored before/after jal 
* Changing an unstored $s register 

There are all checked in the context of each function (something which is called by a jal). Different paths are navigated through branching, as well.

### Installing parser

```
cd calling-convention-validation
npm install
npm run build

bin/mips-parser --help # validate that parser is working
```


### Usage 

To analyze analyze.s:

```
python3 callconv.py
```

Or to analyze a file of your choosing:

```
python3 callconv.py [filepath]
```

### Resources

The `mips-parser` is implemented using [Syntax](https://github.com/DmitrySoshnikov/syntax) tool, which generates a LALR(1) parser based on the MIPS [grammar](https://github.com/DmitrySoshnikov/mips-parser/blob/master/mips.g). The parser is adapted from Dmitry Soshnikov, with some modifications to support more MIPS instructions.
