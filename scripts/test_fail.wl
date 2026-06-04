PacletDirectoryLoad["/Users/arnoudb/github/AntennaLink/AntennaLink"]
Needs["ArnoudBuzing`AntennaLink`"]

necFile = FileNameJoin[{$TemporaryDirectory, "dipole.nec"}];
outFile = FileNameJoin[{$TemporaryDirectory, "dipole.out"}];

Export[necFile, "CM Simple Dipole
CE
GW 1 11 0 0 -0.25 0 0 0.25 0.001
GE 0
EX 0 1 6 0 1.0 0.0
FR 0 1 0 0 299.79 0
XQ
EN
", "String"];

Print["First call: ", AntennaSolve[necFile, outFile]];
Print["Second call: ", AntennaSolve[necFile, outFile]];
