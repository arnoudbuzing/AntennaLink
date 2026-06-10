VerificationTest[
  PacletDirectoryLoad[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink"}]];
  Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink", "Kernel", "AntennaLink.wl"}]];
  NameQ["ArnoudBuzing`AntennaLink`AntennaSolve"],
  True,
  TestID -> "antennalink-context-load"
]

VerificationTest[
  Module[{necFile, outFile, necContent, res},
    necFile = FileNameJoin[{DirectoryName[$TestFileName], "dipole.nec"}];
    outFile = FileNameJoin[{DirectoryName[$TestFileName], "dipole.out"}];
    If[FileExistsQ[outFile], DeleteFile[outFile]];
    
    necContent = "CM Simple Dipole
CE
GW 1 11 0 0 -0.25 0 0 0.25 0.001
GE 0
EX 0 1 6 0 1.0 0.0
FR 0 1 0 0 299.79 0
XQ
EN
";
    Export[necFile, necContent, "String"];
    
    res = AntennaSolve[necFile, outFile];
    {res, FileExistsQ[outFile]}
  ],
  {FileNameJoin[{DirectoryName[$TestFileName], "dipole.out"}], True},
  TestID -> "antennalink-solve-dipole"
]

VerificationTest[
  Module[{outFile, res},
    outFile = FileNameJoin[{DirectoryName[$TestFileName], "dipole.out"}];
    res = AntennaParseOutput[outFile];
    
    {Keys[res], Length[res["Currents"]]}
  ],
  {{"InputParameters", "Currents", "RadiationPattern"}, 11},
  TestID -> "antennalink-parse-output"
]
