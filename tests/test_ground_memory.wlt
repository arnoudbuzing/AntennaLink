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
    {Head[res], Length[res],
     Abs[Normal[res][[1]]["ZInput"] - (41.8164 + 24.5308*I)] < 0.05}
  ],
  {Dataset, 1, True},
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
    {Head[res], Length[res],
     Abs[Normal[res][[1]]["ZInput"] - (54.6373 - 29.6210*I)] < 0.05}
  ],
  {Dataset, 1, True},
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
    {Head[res], Length[res],
     Abs[Normal[res][[1]]["ZInput"] - (34.6125 - 192.8183*I)] < 0.05}
  ],
  {Dataset, 1, True},
  TestID -> "realistic-ground-monopole"
]
