PacletDirectoryLoad[Directory[]];
Needs["ArnoudBuzing`AntennaLink`"];

dipole = {
  <|"Segments" -> 21, "Tag" -> 1, "P1" -> {0,0,-0.375}, "P2" -> {0,0,0.375}, "Radius" -> 0.0001|>
};

sol = AntennaSolveMemory[
  dipole, 200.0, {<|"Tag" -> 1, "Segment" -> 11, "Voltage" -> 1.0|>}
];

currents = sol["Currents"];
cReal = Normal[currents[All, "CurrentReal"]];
cImag = Normal[currents[All, "CurrentImag"]];
mags = Sqrt[cReal^2 + cImag^2];

Print["Max current: ", Max[mags]];
Print["Impedance: ", 1.0 / Max[mags]];
