Print["Loading AntennaLink..."];
pacletDir = FileNameJoin[{DirectoryName[$InputFileName, 2], "AntennaLink"}];
PacletDirectoryLoad[pacletDir];
Get[FileNameJoin[{pacletDir, "Kernel", "AntennaLink.wl"}]];

Print["Creating files..."];
necFile = FileNameJoin[{DirectoryName[$InputFileName, 2], "tests", "dipole.nec"}];
outFile = FileNameJoin[{DirectoryName[$InputFileName, 2], "tests", "dipole.out"}];

necContent = "CM Simple Dipole\nCE\nGW 1 11 0 0 -0.25 0 0 0.25 0.001\nGE 0\nEX 0 1 6 0 1.0 0.0\nFR 0 1 0 0 299.79 0\nXQ\nEN\n";
Export[necFile, necContent, "String"];

Print["Running AntennaSolve..."];
res = ArnoudBuzing`AntennaLink`AntennaSolve[necFile, outFile];

Print["Result: ", res];
Print["FileExistsQ: ", FileExistsQ[outFile]];
