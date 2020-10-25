# alu-verilog
Used verilog to implement a (not so) simple Arithmetic Logic Unit.
The input is an entry package from which I read the payload, which has the parameters, and the header, which has the number of parameteres.
There's a specific operation you need to do between the two operands (such as AND, OR, SUB, the program has all of them).
There's a section to read from the memory in case the the operands are not addressed directly.
Finally, you generate the exit package that also has a header and a payload.
