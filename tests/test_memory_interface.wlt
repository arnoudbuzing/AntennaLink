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

(* AntennaSolveMemory exposes input parameters; ZInput must match the value
   AntennaSweepMemory reports at the same frequency. *)
VerificationTest[
  Module[{wires, excitations, solve, sweep, zSolve, zSweep},
    wires = {
      <|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
    };
    excitations = {<|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0|>};
    solve = ArnoudBuzing`AntennaLink`AntennaSolveMemory[wires, 299.79, excitations];
    sweep = ArnoudBuzing`AntennaLink`AntennaSweepMemory[wires, 299.79, excitations];
    zSolve = Normal[solve["InputParameters"]][[1]]["ZInput"];
    zSweep = Normal[sweep][[1]]["ZInput"];
    {
      Head[solve["InputParameters"]],
      Length[solve["InputParameters"]],
      Keys[Normal[solve["InputParameters"]][[1]]],
      Abs[zSolve - zSweep] < 10.^-6
    }
  ],
  {Dataset, 1, {"Tag", "Segment", "Voltage", "Current", "ZInput", "Power"}, True},
  TestID -> "solve-memory-input-impedance"
]
