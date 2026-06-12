(* These tests pin the in-memory solver against the file-based path, which runs
   the full, unmodified nec2c engine via run_nec2. Agreement to a tight
   tolerance means the memory interface faithfully reproduces NEC. *)

VerificationTest[
  PacletDirectoryLoad[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink"}]];
  Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink", "Kernel", "AntennaLink.wl"}]];
  And[NameQ["ArnoudBuzing`AntennaLink`AntennaSolve"],
      NameQ["ArnoudBuzing`AntennaLink`AntennaSolveMemory"]],
  True,
  TestID -> "refval-context-load"
]

(* Free-space dipole: in-memory input impedance == file-based. *)
VerificationTest[
  Module[{nec, necFile, outFile, p, zFile, zMem},
    nec = "CM dipole\nCE\nGW 1 11 0 0 -0.25 0 0 0.25 0.001\nGE 0\nEX 0 1 6 0 1.0 0.0\nFR 0 1 0 0 299.79 0\nXQ\nEN\n";
    necFile = FileNameJoin[{$TemporaryDirectory, "al_ref_dip.nec"}];
    outFile = FileNameJoin[{$TemporaryDirectory, "al_ref_dip.out"}];
    Export[necFile, nec, "String"];
    ArnoudBuzing`AntennaLink`AntennaSolve[necFile, outFile];
    p = Normal[ArnoudBuzing`AntennaLink`AntennaParseOutput[outFile]["InputParameters"]][[1]];
    zFile = p["ImpedanceReal"] + I p["ImpedanceImag"];
    zMem = Normal[ArnoudBuzing`AntennaLink`AntennaSolveMemory[
       {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>},
       299.79, {<|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0|>}]["InputParameters"]][[1, "ZInput"]];
    Abs[zFile - zMem] < 0.05
  ],
  True,
  TestID -> "dipole-impedance-matches-file"
]

(* Quarter-wave monopole over perfect ground: in-memory impedance == file-based. *)
VerificationTest[
  Module[{nec, necFile, outFile, p, zFile, zMem, mono, feed},
    nec = "CM monopole over perfect ground\nCE\nGW 1 11 0 0 0 0 0 0.08191 0.0005\nGE 1\nGN 1\nEX 0 1 1 0 1.0 0.0\nFR 0 1 0 0 915.0 0\nXQ\nEN\n";
    necFile = FileNameJoin[{$TemporaryDirectory, "al_ref_mono.nec"}];
    outFile = FileNameJoin[{$TemporaryDirectory, "al_ref_mono.out"}];
    Export[necFile, nec, "String"];
    ArnoudBuzing`AntennaLink`AntennaSolve[necFile, outFile];
    p = Normal[ArnoudBuzing`AntennaLink`AntennaParseOutput[outFile]["InputParameters"]][[1]];
    zFile = p["ImpedanceReal"] + I p["ImpedanceImag"];
    mono = {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, 0}, "P2" -> {0, 0, 0.08191}, "Radius" -> 0.0005|>};
    feed = {<|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>};
    zMem = Normal[ArnoudBuzing`AntennaLink`AntennaSolveMemory[mono, 915.0, feed,
       "Ground" -> <|"Type" -> "Perfect", "ConnectWires" -> True|>]["InputParameters"]][[1, "ZInput"]];
    Abs[zFile - zMem] < 0.05
  ],
  True,
  TestID -> "monopole-ground-impedance-matches-file"
]

(* Quarter-wave monopole over perfect ground: in-memory peak gain == file-based.
   This is the case that earlier looked suspicious; it is correct. *)
VerificationTest[
  Module[{nec, necFile, outFile, rp, gFile, mono, feed, gMem},
    nec = "CM monopole pattern over perfect ground\nCE\nGW 1 11 0 0 0 0 0 0.08191 0.0005\nGE 1\nGN 1\nEX 0 1 1 0 1.0 0.0\nFR 0 1 0 0 915.0 0\nRP 0 19 1 1000 0.0 0.0 5.0 0.0 100000.0\nXQ\nEN\n";
    necFile = FileNameJoin[{$TemporaryDirectory, "al_ref_monorp.nec"}];
    outFile = FileNameJoin[{$TemporaryDirectory, "al_ref_monorp.out"}];
    Export[necFile, nec, "String"];
    ArnoudBuzing`AntennaLink`AntennaSolve[necFile, outFile];
    rp = Normal[ArnoudBuzing`AntennaLink`AntennaParseOutput[outFile]["RadiationPattern"]];
    gFile = Max[#TotalGain & /@ rp];
    mono = {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, 0}, "P2" -> {0, 0, 0.08191}, "Radius" -> 0.0005|>};
    feed = {<|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>};
    gMem = Max[Normal[ArnoudBuzing`AntennaLink`AntennaFarFieldMemory[mono, 915.0, feed,
       Range[0.0, 90.0, 5.0], {0.0}, "Ground" -> <|"Type" -> "Perfect", "ConnectWires" -> True|>]["FarField"]][[All, "GainDB"]]];
    Abs[gFile - gMem] < 0.05
  ],
  True,
  TestID -> "monopole-ground-gain-matches-file"
]
