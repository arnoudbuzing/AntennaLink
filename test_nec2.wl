input = "CM Dipole in free space
CE
GW 1 21 0 0 -0.375 0 0 0.375 0.001
GE 0
EX 0 1 11 0 1 0
FR 0 1 0 0 200 0
EN";
Export["dipole.nec", input, "Text"];
Run["src/nec2c/nec2c -i dipole.nec -o dipole.out"];
Print[Import["dipole.out", "Text"]];
