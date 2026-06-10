PacletDirectoryLoad[Directory[]];
Needs["ArnoudBuzing`AntennaLink`"];

yagiWires = AntennaYagiUda[
  0.75, 0.3, 0.705, {0.645, 0.645, 0.645}, {0.3, 0.3, 0.3}, 0.005, 21
];

sol = AntennaFarFieldMemory[
  yagiWires, 200.0, {<|"Tag" -> 2, "Segment" -> 11, "Voltage" -> 1.0|>}, {90}, {90, 270}
];

ff = Normal[sol["FarField"]];
gainFwd = Select[ff, #Phi == 90 &][[1, "Gain"]];
gainRev = Select[ff, #Phi == 270 &][[1, "Gain"]];

Print["Front Gain (linear): ", gainFwd];
Print["Back Gain (linear): ", gainRev];
Print["Front/Back Ratio: ", gainFwd / gainRev];
