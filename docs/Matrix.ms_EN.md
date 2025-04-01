[на Русском](Matrix.ms.md)
# Matrix.ms

Matrix @ PankovEA scripts. 1.04.2025

The structure (class) for operations is a rectangle of Drozdov with the size of a trifle
Use it carefully. Don't make all kinds of dough. Frequently used in the order of work (script for the developer[Simplify-Spline-by-Remove-Selected-Vertices](/scripts/Simplify-Spline-by-Remove-Selected-Vertices.ms))

## Usage example:

### Assignments to the matrix
**By number:**
```
A = Matrix 5 5 1 -- identity matrix 5х5
A.print()
Matrix 5x5:
  [1 0 0 0 0 ]
  [0 1 0 0 0 ]
  [0 0 1 0 0 ]
  [0 0 0 1 0 ]
  [0 0 0 0 1 ]
```
**By data array**
```
M = Matrix 3 3 #(1, 2, 3, 0, 1, 4, 5, 6, 0)
M.print()
(Matrix rows:3 cols:3 data:#(#(1, 2, 3), #(0, 1, 4), #(5, 6, 0)))
Matrix 3x3:
  [1 2 3 ]
  [0 1 4 ]
  [5 6 0 ]
```

### Operations:
Each time there is a new object of the Return function. It's changing, so it's not old.

Matrix transpose
```
(M.transpose()).print()
Matrix 3x3:
  [1 0 5 ]
  [2 1 6 ]
  [3 4 0 ]
OK
```
Multiplication vector
```
V = #(1, 2, 3)            -- accepts as an array of values  
V = Matrix 3 1 #(1, 2, 3) -- so is the matrix-vector
MV = M.multiplyByVector V
Matrix 3x1:
  [14.0 ]
  [14.0 ]
  [17.0 ]
OK
```
Multiplication Matrix
```
M2 = Matrix 3 2 #(1, 2, 3, 4, 5, 6)
MM2 = M.multiplyByMatrix M2
Matrix 3x2:
  [22.0 28.0 ]
  [23.0 28.0 ]
  [23.0 34.0 ]
OK
```
Invert the matrices
```
Minv = M.inverse()
Matrix 3x3:
  [-24.0 18.0 5.0 ]
  [20.0 -15.0 -4.0 ]
  [-5.0 4.0 1.0 ]
OK
```
Get data can be used as follows:
```
M.getVal 1 2
2

M.data[1][2]
2
```
Similarly, we set:
```
M.setVal 1 2 5
5

M.data[1][2] = 5
5

M.print()
Matrix 3x3:
  [1 5 3 ]
  [0 1 4 ]
  [5 6 0 ]
```