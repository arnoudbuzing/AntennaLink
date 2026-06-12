VerificationTest[
  PacletDirectoryLoad[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink"}]];
  Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink", "Kernel", "AntennaLink.wl"}]];
  NameQ["ArnoudBuzing`AntennaLink`AntennaSolveMemory"],
  True,
  TestID -> "freq-scaling-context-load"
]

(* A given physical antenna has the same input impedance regardless of the
   absolute frequency, as long as its geometry is scaled in wavelengths. This
   guards against the current-normalization (wlam) scaling bug, which made the
   reported impedance wrong by a factor of f/CVEL away from ~300 MHz. *)
VerificationTest[
  Module[{zAt},
    zAt[f_] := Module[{s = 299.792458/f},
      Normal[ArnoudBuzing`AntennaLink`AntennaSolveMemory[
        {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25 s}, "P2" -> {0, 0, 0.25 s}, "Radius" -> 0.001 s|>},
        f, {<|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0|>}]["InputParameters"]][[1, "ZInput"]]];
    Abs[zAt[300.0] - zAt[900.0]] < 0.01
  ],
  True,
  TestID -> "impedance-frequency-scale-invariant"
]

(* Gain is dimensionless and likewise frequency-scale invariant. *)
VerificationTest[
  Module[{gAt},
    gAt[f_] := Module[{s = 299.792458/f},
      Max[Normal[ArnoudBuzing`AntennaLink`AntennaFarFieldMemory[
        {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25 s}, "P2" -> {0, 0, 0.25 s}, "Radius" -> 0.001 s|>},
        f, {<|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0|>},
        Range[0.0, 180.0, 10.0], Range[0.0, 350.0, 30.0]]["FarField"]][[All, "GainDB"]]]];
    Abs[gAt[300.0] - gAt[900.0]] < 0.01
  ],
  True,
  TestID -> "gain-frequency-scale-invariant"
]
