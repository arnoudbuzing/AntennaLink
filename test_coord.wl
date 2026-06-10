PacletDirectoryLoad[Directory[]];
Needs["ArnoudBuzing`AntennaLink`"];

dipole = {
  <|"Segments" -> 21, "Tag" -> 1, "P1" -> {1.23, 4.56, 7.89}, "P2" -> {9.87, 6.54, 3.21}, "Radius" -> 0.0001|>
};

(* Re-implement nec2LinkAddWire to see the tensor passing *)
libData = LibraryFunctionLoad["ArnoudBuzing`AntennaLink`Private`$LibraryFile", "nec2_add_wire", {Integer, Integer, {Real, 1}, {Real, 1}, Real}, Integer];

Print["Packed: ", Developer`PackedArrayQ[Developer`ToPackedArray[N[dipole[[1, "P1"]]]]]];
