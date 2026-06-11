VerificationTest[
  PacletDirectoryLoad[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink"}]];
  Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink", "Kernel", "AntennaLink.wl"}]];
  NameQ["ArnoudBuzing`AntennaLink`AntennaSolveMemory"],
  True,
  TestID -> "loads-context-load"
]

(* A pure series resistance at the feed segment adds directly to the input
   resistance, leaving the reactance unchanged. *)
VerificationTest[
  Module[{wires, exc, z0, zL},
    wires = {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>};
    exc = {<|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0|>};
    z0 = Normal[ArnoudBuzing`AntennaLink`AntennaSolveMemory[wires, 299.79, exc]["InputParameters"]][[1]]["ZInput"];
    zL = Normal[ArnoudBuzing`AntennaLink`AntennaSolveMemory[wires, 299.79, exc,
       "Loads" -> {<|"Type" -> "Impedance", "Tag" -> 1, "SegmentFrom" -> 6, "SegmentTo" -> 6,
                     "Resistance" -> 50.0, "Reactance" -> 0.0|>}]["InputParameters"]][[1]]["ZInput"];
    {Abs[(Re[zL] - Re[z0]) - 50.0] < 0.5, Abs[Im[zL] - Im[z0]] < 0.5}
  ],
  {True, True},
  TestID -> "loads-series-resistance-adds-to-Rin"
]

(* A series inductor at the feed adds reactance omega*L = 2*pi*f*L. *)
VerificationTest[
  Module[{wires, exc, fMHz, ind, z0, zL, expected},
    fMHz = 299.79; ind = 50.0*^-9;
    wires = {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>};
    exc = {<|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0|>};
    z0 = Normal[ArnoudBuzing`AntennaLink`AntennaSolveMemory[wires, fMHz, exc]["InputParameters"]][[1]]["ZInput"];
    zL = Normal[ArnoudBuzing`AntennaLink`AntennaSolveMemory[wires, fMHz, exc,
       "Loads" -> {<|"Type" -> "Series", "Tag" -> 1, "SegmentFrom" -> 6, "SegmentTo" -> 6,
                     "Inductance" -> ind|>}]["InputParameters"]][[1]]["ZInput"];
    expected = 2 Pi (fMHz*10^6) ind;
    Abs[(Im[zL] - Im[z0]) - expected] < 0.5
  ],
  True,
  TestID -> "loads-series-inductor-adds-reactance"
]

(* Loads apply through the sweep path (geometry loaded once, load impedance
   recomputed per frequency) identically to a per-frequency solve with loads. *)
VerificationTest[
  Module[{wires, exc, ld, swept, perFreq},
    wires = {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>};
    exc = {<|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0|>};
    ld = {<|"Type" -> "Impedance", "Tag" -> 1, "SegmentFrom" -> 6, "SegmentTo" -> 6,
            "Resistance" -> 25.0, "Reactance" -> 0.0|>};
    swept = Normal[ArnoudBuzing`AntennaLink`AntennaSweepMemory[wires, {280.0, 300.0}, exc, "Loads" -> ld][All, "ZInput"]];
    perFreq = (Normal[ArnoudBuzing`AntennaLink`AntennaSolveMemory[wires, #, exc, "Loads" -> ld]["InputParameters"]][[1]]["ZInput"] &) /@ {280.0, 300.0};
    Max[Abs[swept - perFreq]] < 10.^-6
  ],
  True,
  TestID -> "loads-apply-in-sweep"
]

(* An unknown load type is rejected with a message. *)
VerificationTest[
  ArnoudBuzing`AntennaLink`AntennaSolveMemory[
    {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>},
    299.79,
    {<|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0|>},
    "Loads" -> {<|"Type" -> "Bogus"|>}
  ],
  $Failed,
  {ArnoudBuzing`AntennaLink`AntennaSolveMemory::badload},
  TestID -> "loads-invalid-type"
]
