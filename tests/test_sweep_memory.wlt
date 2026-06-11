VerificationTest[
  PacletDirectoryLoad[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink"}]];
  Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink", "Kernel", "AntennaLink.wl"}]];
  NameQ["ArnoudBuzing`AntennaLink`AntennaSweepMemory"],
  True,
  TestID -> "sweep-memory-context-load"
]

VerificationTest[
  Module[{res, wires, excitations, freqSpec},
    wires = {
      <|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
    };
    excitations = {
      <|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0 + 0.0 * I|>
    };
    freqSpec = {280.0, 300.0, 320.0};
    
    res = AntennaSweepMemory[wires, freqSpec, excitations, "ReferenceImpedance" -> 50.0];
    
    {
      Head[res] === Dataset,
      Length[res] == 3,
      Keys[Normal[res][[1]]]
    }
  ],
  {
    True,
    True,
    {"Frequency", "Tag", "Segment", "Voltage", "Current", "ZInput", "Power", "S11", "VSWR"}
  },
  TestID -> "sweep-memory-returns-correct-dataset-structure"
]

VerificationTest[
  Module[{res, wires, excitations, freqSpec, s11Vals, vswrVals},
    wires = {
      <|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
    };
    excitations = {
      <|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0 + 0.0 * I|>
    };
    (* Sweep from 280 to 320 with step 10 *)
    freqSpec = Range[280.0, 320.0, 10.0];
    
    res = AntennaSweepMemory[wires, freqSpec, excitations, "ReferenceImpedance" -> 73.0];
    s11Vals = Normal[res[All, "S11"]];
    vswrVals = Normal[res[All, "VSWR"]];
    
    {
      Length[res] == 5, (* 280, 290, 300, 310, 320 *)
      AllTrue[s11Vals, NumericQ],
      AllTrue[vswrVals, # >= 1.0 &]
    }
  ],
  {True, True, True},
  TestID -> "sweep-memory-computes-valid-s11-and-vswr"
]

(* Reusing one loaded geometry across frequencies must give the same impedances
   as solving each frequency from a freshly loaded geometry. *)
VerificationTest[
  Module[{wires, excitations, freqs, swept, perFreq},
    wires = {
      <|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
    };
    excitations = {<|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0|>};
    freqs = {280.0, 300.0, 320.0};
    swept = Normal[AntennaSweepMemory[wires, freqs, excitations][All, "ZInput"]];
    perFreq = First[Normal[AntennaSweepMemory[wires, {#}, excitations][All, "ZInput"]]] & /@ freqs;
    Max[Abs[swept - perFreq]] < 10.^-6
  ],
  True,
  TestID -> "sweep-memory-reuse-matches-per-frequency"
]
