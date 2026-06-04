VerificationTest[
  Module[{res, wires, freq, excitations},
    wires = {
      <|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
    };
    freq = 299.79;
    excitations = {
      <|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0 + 0.0 * I|>
    };
    res = ArnoudBuzing`AntennaLink`AntennaSolveMemory[wires, freq, excitations];
    AssociationQ[res] && Head[res["Currents"]] === Dataset && Length[res["Currents"]] == 11
  ],
  True,
  TestID -> "memory-interface-returns-dataset"
]
