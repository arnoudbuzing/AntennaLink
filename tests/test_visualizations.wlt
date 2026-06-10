VerificationTest[
  PacletDirectoryLoad[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink"}]];
  Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink", "Kernel", "AntennaLink.wl"}]];
  NameQ["ArnoudBuzing`AntennaLink`AntennaPlotGeometry"],
  True,
  TestID -> "visualizations-context-load"
]

VerificationTest[
  Module[{wires, plot, prims},
    wires = {
      <|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
    };
    plot = ArnoudBuzing`AntennaLink`AntennaPlotGeometry[wires];
    prims = ArnoudBuzing`AntennaLink`AntennaPlotGeometry[wires, "ReturnPrimitives" -> True];
    
    {Head[plot], Head[prims], Length[prims] > 0}
  ],
  {Graphics3D, List, True},
  TestID -> "plot-geometry-raw-wires"
]

VerificationTest[
  Module[{wires, excitations, sol, plotMag, plotPhase},
    wires = {
      <|"Segments" -> 5, "Tag" -> 1, "P1" -> {0, 0, 0}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
    };
    excitations = {
      <|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>
    };
    sol = ArnoudBuzing`AntennaLink`AntennaSolveMemory[wires, 299.79, excitations, "Ground" -> <|"Type" -> "Perfect", "ConnectWires" -> True|>];
    
    plotMag = ArnoudBuzing`AntennaLink`AntennaPlotGeometry[sol, "ColorFunction" -> "Magnitude"];
    plotPhase = ArnoudBuzing`AntennaLink`AntennaPlotGeometry[sol, "ColorFunction" -> "Phase"];
    
    {Head[plotMag], Head[plotPhase]}
  ],
  {Graphics3D, Graphics3D},
  TestID -> "plot-geometry-solved-currents"
]

VerificationTest[
  Module[{wires, excitations, sol, plotPattern},
    wires = {
      <|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
    };
    excitations = {
      <|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0|>
    };
    
    sol = ArnoudBuzing`AntennaLink`AntennaFarFieldMemory[
      wires, 
      299.79, 
      excitations, 
      {0.0, 45.0, 90.0, 135.0, 180.0}, 
      {0.0, 90.0, 180.0, 270.0, 360.0}
    ];
    
    plotPattern = ArnoudBuzing`AntennaLink`AntennaPlotPattern3D[sol, "ShowGeometry" -> True];
    
    Head[plotPattern]
  ],
  Graphics3D,
  TestID -> "plot-pattern-3d"
]
