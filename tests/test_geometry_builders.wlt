VerificationTest[
  PacletDirectoryLoad[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink"}]];
  Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink", "Kernel", "AntennaLink.wl"}]];
  And[
    NameQ["ArnoudBuzing`AntennaLink`AntennaYagiUda"],
    NameQ["ArnoudBuzing`AntennaLink`AntennaHelix"],
    NameQ["ArnoudBuzing`AntennaLink`AntennaParabolicReflector"]
  ],
  True,
  TestID -> "geometry-builders-context-load"
]

VerificationTest[
  Module[{wires, res},
    wires = AntennaYagiUda[1.0, 0.2, 0.95, {0.9, 0.85}, {0.15, 0.15}];
    res = AntennaSolveMemory[wires, 150.0, {<|"Tag" -> 2, "Segment" -> 6, "Voltage" -> 1.0 + 0.0 * I|>}];
    
    {
      Length[wires], (* 1 reflector + 1 driven + 2 directors = 4 wires *)
      Head[wires],
      AssociationQ[res] && Head[res["Currents"]] === Dataset
    }
  ],
  {4, List, True},
  TestID -> "yagi-uda-builder-and-solve"
]

VerificationTest[
  Module[{wires, wiresAssoc},
    wires = AntennaYagiUda[1.0, 0.2, 0.95, {0.9, 0.85}, {0.15, 0.15}];
    wiresAssoc = AntennaYagiUda[<|
      "ReflectorLength" -> 1.0,
      "ReflectorSpacing" -> 0.2,
      "DrivenLength" -> 0.95,
      "DirectorLengths" -> {0.9, 0.85},
      "DirectorSpacings" -> {0.15, 0.15}
    |>];
    wires === wiresAssoc
  ],
  True,
  TestID -> "yagi-uda-association-builder"
]

VerificationTest[
  Module[{wires, wiresAssoc},
    wires = AntennaYagiUda[1.0, 0.2, 0.95, {0.9, 0.85}, {0.15, 0.15}, 0.002, 15];
    wiresAssoc = AntennaYagiUda[<|
      "ReflectorLength" -> 1.0,
      "ReflectorSpacing" -> 0.2,
      "DrivenLength" -> 0.95,
      "DirectorLengths" -> {0.9, 0.85},
      "DirectorSpacings" -> {0.15, 0.15},
      "WireRadius" -> 0.002,
      "Segments" -> 15
    |>];
    wires === wiresAssoc
  ],
  True,
  TestID -> "yagi-uda-association-builder-custom-params"
]

VerificationTest[
  Module[{wires, res},
    wires = AntennaHelix[0.1, 0.05, 3, 0.001, 8];
    res = AntennaSolveMemory[wires, 1000.0, {<|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0 + 0.0 * I|>}];
    
    {
      Length[wires], (* 3 turns * 8 segments/turn = 24 segments *)
      Head[wires],
      AssociationQ[res] && Head[res["Currents"]] === Dataset
    }
  ],
  {24, List, True},
  TestID -> "helix-builder-and-solve"
]

VerificationTest[
  Module[{wires, res},
    (* 4 ribs, 2 rings -> total 4*2 (rib segments) + 4*2 (ring segments) = 16 wires *)
    wires = AntennaParabolicReflector[0.5, 1.0, 4, 2];
    res = AntennaSolveMemory[wires, 300.0, {<|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0 + 0.0 * I|>}];
    
    {
      Length[wires],
      Head[wires],
      AssociationQ[res] && Head[res["Currents"]] === Dataset
    }
  ],
  {16, List, True},
  TestID -> "parabolic-reflector-builder-and-solve"
]

VerificationTest[
  Module[{wires, wiresAssoc},
    wires = AntennaHelix[0.1, 0.05, 3, 0.001, 8];
    wiresAssoc = AntennaHelix[<|
      "Radius" -> 0.1,
      "Pitch" -> 0.05,
      "Turns" -> 3,
      "WireRadius" -> 0.001,
      "SegmentsPerTurn" -> 8
    |>];
    wires === wiresAssoc
  ],
  True,
  TestID -> "helix-association-builder"
]

VerificationTest[
  Module[{wires, wiresAssoc},
    wires = AntennaParabolicReflector[0.5, 1.0, 4, 2, 0.001];
    wiresAssoc = AntennaParabolicReflector[<|
      "FocalLength" -> 0.5,
      "DishRadius" -> 1.0,
      "NumRibs" -> 4,
      "NumRings" -> 2,
      "WireRadius" -> 0.001
    |>];
    wires === wiresAssoc
  ],
  True,
  TestID -> "parabolic-reflector-association-builder"
]

(* Each helix segment gets a unique tag, with the base at tag 1. *)
VerificationTest[
  Module[{w = AntennaHelix[0.1, 0.05, 3, 0.001, 8]},
    {DuplicateFreeQ[Lookup[w, "Tag"]], First[w]["Tag"], Length[w]}
  ],
  {True, 1, 24},
  TestID -> "helix-unique-tags"
]

(* Every rib and ring wire gets a unique tag, first wire at tag 1. *)
VerificationTest[
  Module[{w = AntennaParabolicReflector[0.5, 1.0, 4, 2]},
    {DuplicateFreeQ[Lookup[w, "Tag"]], First[w]["Tag"], Sort[Lookup[w, "Tag"]]}
  ],
  {True, 1, Range[16]},
  TestID -> "parabolic-unique-tags"
]
