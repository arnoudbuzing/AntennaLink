pacletDir = FileNameJoin[{DirectoryName[$InputFileName, 2], "AntennaLink"}];
PacletDirectoryLoad[pacletDir];
Get[FileNameJoin[{pacletDir, "Kernel", "AntennaLink.wl"}]];

outFile = FileNameJoin[{DirectoryName[$InputFileName, 2], "tests", "dipole.out"}];
res = ArnoudBuzing`AntennaLink`AntennaParseOutput[outFile];
Print[Keys[res]];
Print[Length[res["Currents"]]];
