pacletDir = FileNameJoin[{DirectoryName[$InputFileName, 2], "AntennaLink"}];
PacletDirectoryLoad[pacletDir];
Get[FileNameJoin[{pacletDir, "Kernel", "AntennaLink.wl"}]];

helixWires = AntennaHelix[0.08, 0.10, 5.0, 0.001, 16];
sol = AntennaSolveMemory[helixWires, 300.0, {<|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>}];
plot = AntennaPlotGeometry[sol];

Print["Sphere primitive in plot: ", InputForm[Cases[plot, _Sphere, Infinity]]];
