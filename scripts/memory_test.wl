Print["Loading paclet..."];
pacletDir = FileNameJoin[{DirectoryName[$InputFileName, 2], "AntennaLink"}];
PacletDirectoryLoad[pacletDir];
Get[FileNameJoin[{pacletDir, "Kernel", "AntennaLink.wl"}]];

Print["Defining params..."];
wires = {
  <|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
};

freq = 299.79;

excitations = {
  <|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0 + 0.0 * I|>
};

Print["Running memory solve..."];
res = ArnoudBuzing`AntennaLink`AntennaSolveMemory[wires, freq, excitations];
Print["Result: ", res];
