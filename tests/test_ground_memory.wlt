VerificationTest[
  PacletDirectoryLoad[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink"}]];
  Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink", "Kernel", "AntennaLink.wl"}]];
  NameQ["ArnoudBuzing`AntennaLink`AntennaSolveMemory"],
  True,
  TestID -> "ground-memory-context-load"
]

(* Perfect Ground Monopole test *)
VerificationTest[
  Module[{wires, excitations, res},
    wires = {
      <|"Segments" -> 5, "Tag" -> 1, "P1" -> {0, 0, 0}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
    };
    excitations = {
      <|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>
    };
    res = ArnoudBuzing`AntennaLink`AntennaSweepMemory[
      wires, 
      299.79, 
      excitations, 
      "Ground" -> <|"Type" -> "Perfect", "ConnectWires" -> True|>
    ];
    {Head[res], Length[res], Chop[Normal[res][[1]]["ZInput"]]}
  ],
  {Dataset, 1, 41.816361162911925 + 24.530762739536993*I},
  TestID -> "perfect-ground-monopole"
]

(* Sommerfeld Ground Monopole test *)
VerificationTest[
  Module[{wires, excitations, res},
    wires = {
      <|"Segments" -> 5, "Tag" -> 1, "P1" -> {0, 0, 0}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
    };
    excitations = {
      <|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>
    };
    res = ArnoudBuzing`AntennaLink`AntennaSweepMemory[
      wires, 
      299.79, 
      excitations, 
      "Ground" -> <|"Type" -> "Sommerfeld", "Dielectric" -> 15.0, "Conductivity" -> 0.01, "ConnectWires" -> True|>
    ];
    {Head[res], Length[res], Chop[Normal[res][[1]]["ZInput"]]}
  ],
  {Dataset, 1, 54.63733471111652 - 29.62101443434472*I},
  TestID -> "sommerfeld-ground-monopole"
]

(* Realistic Ground Monopole test *)
VerificationTest[
  Module[{wires, excitations, res},
    wires = {
      <|"Segments" -> 5, "Tag" -> 1, "P1" -> {0, 0, 0}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
    };
    excitations = {
      <|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>
    };
    res = ArnoudBuzing`AntennaLink`AntennaSweepMemory[
      wires, 
      299.79, 
      excitations, 
      "Ground" -> <|"Type" -> "Realistic", "Dielectric" -> 15.0, "Conductivity" -> 0.01, "ConnectWires" -> True|>
    ];
    {Head[res], Length[res], Chop[Normal[res][[1]]["ZInput"]]}
  ],
  {Dataset, 1, 34.61249665565982 - 192.8182814190516*I},
  TestID -> "realistic-ground-monopole"
]
