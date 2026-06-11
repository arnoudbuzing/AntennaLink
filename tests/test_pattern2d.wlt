VerificationTest[
  PacletDirectoryLoad[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink"}]];
  Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink", "Kernel", "AntennaLink.wl"}]];
  NameQ["ArnoudBuzing`AntennaLink`AntennaPlotPattern2D"],
  True,
  TestID -> "pattern2d-context-load"
]

(* Shared far-field solution for the plotting tests. *)
VerificationTest[
  Module[{wires, exc, sol, elev, azim, fromDataset, linear},
    wires = {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>};
    exc = {<|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0|>};
    sol = ArnoudBuzing`AntennaLink`AntennaFarFieldMemory[
      wires, 299.79, exc, Range[0.0, 180.0, 10.0], Range[0.0, 350.0, 10.0]];

    elev = ArnoudBuzing`AntennaLink`AntennaPlotPattern2D[sol];                          (* default elevation *)
    azim = ArnoudBuzing`AntennaLink`AntennaPlotPattern2D[sol, "Plane" -> "Azimuth"];
    fromDataset = ArnoudBuzing`AntennaLink`AntennaPlotPattern2D[sol["FarField"]];       (* pass dataset directly *)
    linear = ArnoudBuzing`AntennaLink`AntennaPlotPattern2D[sol, "PlotType" -> "Linear"];

    {Head[elev], Head[azim], Head[fromDataset], Head[linear]}
  ],
  {Graphics, Graphics, Graphics, Graphics},
  TestID -> "pattern2d-cuts-render"
]

(* Invalid input is rejected with a message. *)
VerificationTest[
  ArnoudBuzing`AntennaLink`AntennaPlotPattern2D[42],
  $Failed,
  {ArnoudBuzing`AntennaLink`AntennaPlotPattern2D::invalid},
  TestID -> "pattern2d-invalid-input"
]
