PacletDirectoryLoad[Directory[]];
Needs["ArnoudBuzing`AntennaLink`"];

yagiWires = AntennaYagiUda[
  0.75, 0.3, 0.705, {0.645, 0.645, 0.645}, {0.3, 0.3, 0.3}, 0.005, 21
];

thetas = Range[0, 180, 5];
phis = Range[0, 360, 5];

sol = AntennaFarFieldMemory[
  yagiWires, 200.0, {<|"Tag" -> 2, "Segment" -> 11, "Voltage" -> 1.0|>}, thetas, phis
];

ff = Normal[sol["FarField"]];
gains = Lookup[ff, "Gain"];
Print["Max gain (linear): ", Max[gains]];
Print["Min gain (linear): ", Min[gains]];

(* Check gain in different directions *)
gainPhi0 = Select[ff, #Theta == 90 && #Phi == 0 &][[1, "Gain"]];
gainPhi90 = Select[ff, #Theta == 90 && #Phi == 90 &][[1, "Gain"]];
gainPhi180 = Select[ff, #Theta == 90 && #Phi == 180 &][[1, "Gain"]];
gainPhi270 = Select[ff, #Theta == 90 && #Phi == 270 &][[1, "Gain"]];

Print["Gain at (Theta=90, Phi=0)   : ", gainPhi0];
Print["Gain at (Theta=90, Phi=90)  : ", gainPhi90];
Print["Gain at (Theta=90, Phi=180) : ", gainPhi180];
Print["Gain at (Theta=90, Phi=270) : ", gainPhi270];
