VerificationTest[
  PacletDirectoryLoad[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink"}]];
  Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink", "Kernel", "AntennaLink.wl"}]];
  NameQ["ArnoudBuzing`AntennaLink`AntennaSolveMemory"],
  True,
  TestID -> "validation-context-load"
]

(* --- Solver input validation ---------------------------------------------- *)

(* Wire missing the "Radius" key. *)
VerificationTest[
  AntennaSolveMemory[
    {<|"Segments" -> 5, "Tag" -> 1, "P1" -> {0, 0, 0}, "P2" -> {0, 0, 0.25}|>},
    300.0,
    {<|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>}
  ],
  $Failed,
  {AntennaSolveMemory::badwire},
  TestID -> "solve-invalid-wire"
]

(* Empty wire list. *)
VerificationTest[
  AntennaSolveMemory[{}, 300.0, {<|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>}],
  $Failed,
  {AntennaSolveMemory::nowires},
  TestID -> "solve-empty-wires"
]

(* Excitation missing the "Voltage" key. *)
VerificationTest[
  AntennaSolveMemory[
    {<|"Segments" -> 5, "Tag" -> 1, "P1" -> {0, 0, 0}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>},
    300.0,
    {<|"Tag" -> 1, "Segment" -> 1|>}
  ],
  $Failed,
  {AntennaSolveMemory::badex},
  TestID -> "solve-invalid-excitation"
]

(* Non-positive radius is rejected. *)
VerificationTest[
  AntennaFarFieldMemory[
    {<|"Segments" -> 5, "Tag" -> 1, "P1" -> {0, 0, 0}, "P2" -> {0, 0, 0.25}, "Radius" -> -1|>},
    300.0,
    {<|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>},
    {0.0, 90.0}, {0.0, 90.0}
  ],
  $Failed,
  {AntennaFarFieldMemory::badwire},
  TestID -> "farfield-invalid-radius"
]

(* Sweep reports under its own symbol. *)
VerificationTest[
  AntennaSweepMemory[
    {<|"Segments" -> 5, "Tag" -> 1, "P1" -> {0, 0, 0}|>},
    300.0,
    {<|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>}
  ],
  $Failed,
  {AntennaSweepMemory::badwire},
  TestID -> "sweep-invalid-wire"
]

(* Valid inputs still solve (regression guard for the validation gate). *)
VerificationTest[
  AssociationQ[AntennaSolveMemory[
    {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>},
    299.79,
    {<|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0 + 0.0 I|>}
  ]],
  True,
  TestID -> "solve-valid-still-works"
]

(* --- Geometry builder missing-key messages -------------------------------- *)

VerificationTest[
  AntennaYagiUda[<|"ReflectorLength" -> 1.0|>],
  $Failed,
  {AntennaYagiUda::missingkey},
  TestID -> "yagi-missing-key"
]

VerificationTest[
  AntennaHelix[<|"Radius" -> 0.1, "Pitch" -> 0.05|>],
  $Failed,
  {AntennaHelix::missingkey},
  TestID -> "helix-missing-key"
]

VerificationTest[
  AntennaParabolicReflector[<|"FocalLength" -> 0.5, "DishRadius" -> 1.0|>],
  $Failed,
  {AntennaParabolicReflector::missingkey},
  TestID -> "parabolic-missing-key"
]
