Get["AntennaLink/Kernel/AntennaLink.wl"];

yagiWires = AntennaYagiUda[
  0.75, 0.3, 0.705, {0.645, 0.645, 0.645}, {0.3, 0.3, 0.3}, 0.005, 21
];

sol = AntennaSolveMemory[
  yagiWires, 200.0, {<|"Tag" -> 2, "Segment" -> 11, "Voltage" -> 1.0|>}
];

currents = sol["Currents"];

Print["Number of wires: ", Length[yagiWires]];
Print["Total segments: ", Length[currents]];

Do[
  wireSegs = (i-1)*21 + 1 ;; i*21;
  cReal = Normal[currents[wireSegs, "CurrentReal"]];
  cImag = Normal[currents[wireSegs, "CurrentImag"]];
  mags = Sqrt[cReal^2 + cImag^2];
  Print["Wire ", i, " max current: ", Max[mags]];
  , {i, 1, 5}
]
