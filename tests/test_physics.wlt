(* Sanity checks against well-known antenna theory and internal self-consistency.
   Tolerances are loose where they pin physical constants (gain figures) and
   tight where they check derived quantities against their own definitions. *)

VerificationTest[
  PacletDirectoryLoad[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink"}]];
  Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink", "Kernel", "AntennaLink.wl"}]];
  NameQ["ArnoudBuzing`AntennaLink`AntennaFarFieldMemory"],
  True,
  TestID -> "physics-context-load"
]

(* A half-wave dipole has a peak directivity of about 2.15 dBi. *)
VerificationTest[
  Module[{ff},
    ff = ArnoudBuzing`AntennaLink`AntennaFarFieldMemory[
      {<|"Segments" -> 21, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>},
      300.0, {<|"Tag" -> 1, "Segment" -> 11, "Voltage" -> 1.0|>},
      Range[0.0, 180.0, 5.0], Range[0.0, 350.0, 10.0]];
    Module[{g = Max[Normal[ff["FarField"]][[All, "GainDB"]]]}, 1.9 < g < 2.4]
  ],
  True,
  TestID -> "dipole-peak-gain-2.15dBi"
]

(* The dipole has a deep null along its own (z) axis (theta = 0), and its
   pattern is azimuthally symmetric (gain at fixed theta independent of phi). *)
VerificationTest[
  Module[{data, axis, g90},
    data = Normal[ArnoudBuzing`AntennaLink`AntennaFarFieldMemory[
      {<|"Segments" -> 21, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>},
      300.0, {<|"Tag" -> 1, "Segment" -> 11, "Voltage" -> 1.0|>},
      Range[0.0, 180.0, 5.0], Range[0.0, 350.0, 10.0]]["FarField"]];
    axis = SelectFirst[data, #Theta == 0.0 &]["GainDB"];
    g90 = Function[ph, SelectFirst[data, #Theta == 90.0 && #Phi == ph &]["GainDB"]] /@ {0.0, 90.0, 180.0, 270.0};
    {axis < -10.0, Max[g90] - Min[g90] < 0.01}
  ],
  {True, True},
  TestID -> "dipole-axial-null-and-azimuthal-symmetry"
]

(* GainDB is consistent with the linear Gain: GainDB == 10 log10(Gain). *)
VerificationTest[
  Module[{data},
    data = Normal[ArnoudBuzing`AntennaLink`AntennaFarFieldMemory[
      {<|"Segments" -> 21, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>},
      300.0, {<|"Tag" -> 1, "Segment" -> 11, "Voltage" -> 1.0|>},
      Range[0.0, 90.0, 30.0], Range[0.0, 270.0, 90.0]]["FarField"]];
    AllTrue[data, #Gain <= 1.*^-20 || Abs[#GainDB - 10 Log10[#Gain]] < 1.*^-6 &]
  ],
  True,
  TestID -> "gaindb-matches-linear-gain"
]

(* A quarter-wave monopole over perfect ground has ~5.15 dBi gain, ~3 dB above
   the half-wave dipole (it radiates into a half-space). *)
VerificationTest[
  Module[{mono, feed, gMono, gDip},
    mono = {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, 0}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>};
    feed = {<|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>};
    gMono = Max[Normal[ArnoudBuzing`AntennaLink`AntennaFarFieldMemory[mono, 299.79, feed,
       Range[0.0, 90.0, 5.0], {0.0}, "Ground" -> <|"Type" -> "Perfect", "ConnectWires" -> True|>]["FarField"]][[All, "GainDB"]]];
    gDip = Max[Normal[ArnoudBuzing`AntennaLink`AntennaFarFieldMemory[
      {<|"Segments" -> 21, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>},
      299.79, {<|"Tag" -> 1, "Segment" -> 11, "Voltage" -> 1.0|>},
      Range[0.0, 180.0, 5.0], {0.0}]["FarField"]][[All, "GainDB"]]];
    {4.9 < gMono < 5.4, Abs[(gMono - gDip) - 3.0] < 0.3}
  ],
  {True, True},
  TestID -> "monopole-gain-5.15dBi-and-3dB-over-dipole"
]

(* S11 and VSWR from the sweep are self-consistent with the returned impedance
   and reference impedance, and VSWR is never below 1. *)
VerificationTest[
  Module[{z0 = 50.0, rows},
    rows = Normal[ArnoudBuzing`AntennaLink`AntennaSweepMemory[
      {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>},
      Range[280.0, 320.0, 10.0], {<|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0|>},
      "ReferenceImpedance" -> z0]];
    AllTrue[rows, Function[r,
      Module[{gamma = (r["ZInput"] - z0)/(r["ZInput"] + z0)},
        r["VSWR"] >= 1.0 &&
        Abs[r["S11"] - 20 Log10[Abs[gamma]]] < 1.*^-6 &&
        Abs[r["VSWR"] - (1 + Abs[gamma])/(1 - Abs[gamma])] < 1.*^-6
      ]]]
  ],
  True,
  TestID -> "s11-vswr-self-consistent"
]
