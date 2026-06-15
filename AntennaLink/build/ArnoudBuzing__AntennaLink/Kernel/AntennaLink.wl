(* ::Package:: *)

BeginPackage["ArnoudBuzing`AntennaLink`"]

AntennaSolve::usage = "AntennaSolve[inputFile, outputFile] runs the NEC2 MoM solver on the given inputFile (.nec) and writes the results to outputFile (.out)."
AntennaParseOutput::usage = "AntennaParseOutput[file] parses a NEC .out file into an Association containing Datasets."
AntennaSolveMemory::usage = "AntennaSolveMemory[wires, freq, excitations] runs the NEC2 solver directly in memory, bypassing file I/O. The result includes \"Currents\" and an \"InputParameters\" Dataset giving the input impedance (ZInput), drive voltage, current, and power at each excited segment. The \"Loads\" option adds lumped R/L/C or impedance loading to segments."
AntennaFarFieldMemory::usage = "AntennaFarFieldMemory[wires, freq, excitations, thetaList, phiList] runs the NEC2 solver directly in memory and computes the far-field E-fields and gains for the specified list of theta and phi angles (in degrees). The result also includes an \"InputParameters\" Dataset with the input impedance at each excited segment."
AntennaYagiUda::usage = "AntennaYagiUda[reflectorLength, reflectorSpacing, drivenLength, directorLengths, directorSpacings, wireRadius, segments] or AntennaYagiUda[assoc] creates a structured list of wire associations representing a Yagi-Uda antenna aligned along the Y-axis."
AntennaHelix::usage = "AntennaHelix[radius, pitch, turns, wireRadius, segmentsPerTurn] or AntennaHelix[assoc] creates a structured list of wire associations representing a helical antenna along the Z-axis. Each wire is given a unique Tag (1 at the base), so any point can be addressed for excitation."
AntennaParabolicReflector::usage = "AntennaParabolicReflector[focalLength, dishRadius, numRibs, numRings, wireRadius] or AntennaParabolicReflector[assoc] creates a structured list of wire associations representing a wire-grid parabolic reflector dish vertexed at the origin. Each rib and ring wire is given a unique Tag."
AntennaSweepMemory::usage = "AntennaSweepMemory[wires, freqSpec, excitations] sweeps the frequencies given by freqSpec (a single frequency or an explicit list, e.g. Range[fmin, fmax, step]) to compute input impedance, S11, and VSWR in memory."
AntennaPlotGeometry::usage = "AntennaPlotGeometry[wires] plots the 3D geometry of the antenna. AntennaPlotGeometry[solveResult] plots the geometry colored by computed segment currents."
AntennaPlotPattern3D::usage = "AntennaPlotPattern3D[farFieldData] plots the 3D radiation pattern. AntennaPlotPattern3D[solveResult] plots the radiation pattern and overlays the physical antenna geometry at the center."
AntennaPlotPattern2D::usage = "AntennaPlotPattern2D[farFieldData] or AntennaPlotPattern2D[solveResult] plots a 2D polar cut of the radiation pattern. Use \"Plane\" -> \"Elevation\" (a phi = const vertical cut, default) or \"Azimuth\" (a theta = const horizontal cut), and \"Angle\" to choose the fixed angle in degrees."

Begin["`Private`"]

$LibraryFile = FindLibrary["libnec2link"];

(* FindLibrary only succeeds when the paclet's LibraryResources directory is on
   the library path, which is not guaranteed when the package is loaded directly
   (e.g. via Get, or before the paclet is installed). Fall back to the library
   bundled next to this package, under LibraryResources/$SystemID. *)
If[$LibraryFile === $Failed && $InputFileName =!= "",
  Module[{candidates},
    candidates = FileNames[
      "libnec2link.*",
      FileNameJoin[{ParentDirectory[DirectoryName[ExpandFileName[$InputFileName]]], "LibraryResources", $SystemID}]
    ];
    If[candidates =!= {}, $LibraryFile = First[candidates]]
  ]
];

If[$LibraryFile =!= $Failed,
  nec2LinkRun = LibraryFunctionLoad[$LibraryFile, "run_nec2", {String, String}, Integer];
  nec2LinkInit = LibraryFunctionLoad[$LibraryFile, "nec2_init", {}, Integer];
  nec2LinkAddWire = LibraryFunctionLoad[$LibraryFile, "nec2_add_wire", {Integer, Integer, {Real, 1}, {Real, 1}, Real}, Integer];
  nec2LinkGeometryEnd = LibraryFunctionLoad[$LibraryFile, "nec2_geometry_end", {Integer}, Integer];
  nec2LinkSetFreq = LibraryFunctionLoad[$LibraryFile, "nec2_set_freq", {Real}, Integer];
  nec2LinkSetExcitation = LibraryFunctionLoad[$LibraryFile, "nec2_set_excitation", {Integer, Integer, Real, Real}, Integer];
  nec2LinkExecute = LibraryFunctionLoad[$LibraryFile, "nec2_execute", {}, {Real, 2}];
  nec2LinkFarField = LibraryFunctionLoad[$LibraryFile, "nec2_far_field", {{Real, 1}, {Real, 1}}, {Real, 2}];
  nec2LinkGetInputParameters = LibraryFunctionLoad[$LibraryFile, "nec2_get_input_parameters", {}, {Real, 2}];
  nec2LinkSetGround = LibraryFunctionLoad[$LibraryFile, "nec2_set_ground", {Integer, Integer, Real, Real, Real, Real}, Integer];
  nec2LinkAddLoad = LibraryFunctionLoad[$LibraryFile, "nec2_add_load", {Integer, Integer, Integer, Integer, Real, Real, Real}, Integer];
]

AntennaSolve[inputFile_String, outputFile_String] := Module[
  {result},
  If[$LibraryFile === $Failed,
    Message[AntennaSolve::nolib];
    Return[$Failed]
  ];
  
  result = nec2LinkRun[inputFile, outputFile];
  
  If[result =!= 0,
    Message[AntennaSolve::err, result];
    Return[$Failed]
  ];
  
  outputFile
]

AntennaSolve::nolib = "The libnec2link library could not be found.";
AntennaSolve::err = "The NEC2 solver returned an error code: `1`.";
AntennaSweepMemory::freq = "The frequency specification `1` must be a numeric frequency or an explicit list of frequencies (e.g. Range[fmin, fmax, step]).";

(* Shared validation messages. Defined on General so each public symbol reports
   under its own name (e.g. AntennaSolveMemory::badwire) via the usual fallback. *)
General::nowires = "The wire list is empty; at least one wire is required.";
General::badwire = "`1` is not a valid wire. Each wire must be an Association with an integer \"Segments\" > 0, an integer \"Tag\", three-element numeric \"P1\" and \"P2\", and a positive numeric \"Radius\".";
General::badex = "`1` is not a valid excitation. Each excitation must be an Association with an integer \"Tag\", a positive integer \"Segment\", and a numeric (possibly complex) \"Voltage\".";
General::missingkey = "Required key(s) `1` missing from the input association.";
General::badload = "`1` is not a valid load. Each load must be an Association whose \"Type\" is one of Series, Parallel, SeriesPerMeter, ParallelPerMeter, Impedance, or Conductivity.";


AntennaParseOutput[outFile_String] := Module[
  {text, inputParamsStr, currentsStr, rpStr, extractTable, extractRPTable, inputData, currentData, rpData},
  
  If[!FileExistsQ[outFile], Return[$Failed]];
  
  text = Import[outFile, "String"];
  
  extractTable[block_String] := Module[
    {lines, dataLines, table},
    lines = StringSplit[block, "\n"];
    dataLines = Select[lines, StringMatchQ[#, Whitespace ~~ ("+" | "-" | DigitCharacter) ~~ __] &];
    If[Length[dataLines] == 0, Return[{}]];
    table = ImportString[StringJoin[Riffle[dataLines, "\n"]], "Table"];
    table
  ];
  
  extractRPTable[block_String] := Module[
    {lines, dataLines, table},
    lines = StringSplit[block, "\n"];
    dataLines = Select[lines, StringMatchQ[#, Whitespace ~~ ("+" | "-" | DigitCharacter) ~~ __] && !StringContainsQ[#, "---"] &];
    If[Length[dataLines] == 0, Return[{}]];
    table = ImportString[StringJoin[Riffle[dataLines, "\n"]], "Table"];
    table = If[Length[#] == 11, Insert[#, "N/A", 8], #]& /@ table;
    table
  ];
  
  inputParamsStr = First[StringCases[text, "--------- ANTENNA INPUT PARAMETERS ---------" ~~ Shortest[x___] ~~ "\n\n\n" :> x], ""];
  currentsStr = First[StringCases[text, "-------- CURRENTS AND LOCATION --------" ~~ Shortest[x___] ~~ "\n\n\n" :> x], ""];
  rpStr = First[StringCases[text, "---------- RADIATION PATTERNS -----------" ~~ Shortest[x___] ~~ ("\n\n\n" | EndOfString) :> x], ""];
  
  inputData = If[inputParamsStr =!= "",
    Dataset[AssociationThread[
      {"Tag", "Segment", "VoltageReal", "VoltageImag", "CurrentReal", "CurrentImag", "ImpedanceReal", "ImpedanceImag", "AdmittanceReal", "AdmittanceImag", "Power"},
      #
    ]& /@ extractTable[inputParamsStr]],
    Missing["NotAvailable"]
  ];
  
  currentData = If[currentsStr =!= "",
    Dataset[AssociationThread[
      {"Segment", "Tag", "X", "Y", "Z", "Length", "CurrentReal", "CurrentImag", "Magnitude", "Phase"},
      #
    ]& /@ extractTable[currentsStr]],
    Missing["NotAvailable"]
  ];
  
  rpData = If[rpStr =!= "",
    Dataset[AssociationThread[
      {"Theta", "Phi", "VerticalGain", "HorizontalGain", "TotalGain", "AxialRatio", "Tilt", "Sense", "EThetaMagnitude", "EThetaPhase", "EPhiMagnitude", "EPhiPhase"},
      #
    ]& /@ extractRPTable[rpStr]],
    Missing["NotAvailable"]
  ];
  
  <|"InputParameters" -> inputData, "Currents" -> currentData, "RadiationPattern" -> rpData|>
]

setupGround[groundSpec_] := Module[
  {type, nradl, epsr, sig, scrwlt, scrwrt, iperf, result},
  
  If[groundSpec === None || !AssociationQ[groundSpec],
    result = nec2LinkSetGround[-1, 0, 0.0, 0.0, 0.0, 0.0];
    If[result =!= 0, Message[AntennaSolve::err, result]];
    Return[0]
  ];
  
  type = Lookup[groundSpec, "Type", "Perfect"];
  nradl = Lookup[groundSpec, "Radials", 0];
  epsr = Lookup[groundSpec, "Dielectric", 1.0];
  sig = Lookup[groundSpec, "Conductivity", 0.0];
  scrwlt = Lookup[groundSpec, "RadialLength", 0.0];
  scrwrt = Lookup[groundSpec, "RadialRadius", 0.0];
  
  iperf = Switch[type,
    "Perfect", 1,
    "Realistic", 0,
    "Sommerfeld", 2,
    _, 1
  ];
  
  result = nec2LinkSetGround[iperf, nradl, N[epsr], N[sig], N[scrwlt], N[scrwrt]];
  If[result =!= 0, Message[AntennaSolve::err, result]];
  
  If[Lookup[groundSpec, "ConnectWires", True], 1, 0]
]

(* Whether wires touching Z=0 should connect to the ground plane. *)
groundConnectFlag[groundSpec_] :=
  If[groundSpec === None || !AssociationQ[groundSpec] || !Lookup[groundSpec, "ConnectWires", True], 0, 1];

(* Shared in-memory setup for the solver entry points: initialize, load the
   wire geometry, set the frequency, configure ground, and apply excitations.
   Returns "OK" on success, or a status string naming the stage that failed.
   The caller is responsible for invoking nec2LinkExecute[] afterward. *)
setupGeometry[wires_List, freq_?NumericQ, excitations_List, groundSpec_, loads_List] := Module[
  {result},

  result = nec2LinkInit[];
  If[result =!= 0, Return["InitFailed"]];

  Scan[
    Function[wire,
      nec2LinkAddWire[
        wire["Segments"], wire["Tag"],
        Developer`ToPackedArray[N[wire["P1"]]],
        Developer`ToPackedArray[N[wire["P2"]]],
        N[wire["Radius"]]
      ]
    ],
    wires
  ];

  result = nec2LinkGeometryEnd[groundConnectFlag[groundSpec]];
  If[result =!= 0, Return["GeometryEndFailed"]];

  result = nec2LinkSetFreq[N[freq]];
  If[result =!= 0, Return["SetFreqFailed"]];

  setupGround[groundSpec];

  Scan[
    Function[ex,
      nec2LinkSetExcitation[
        ex["Tag"], ex["Segment"],
        Re[ex["Voltage"]], Im[ex["Voltage"]]
      ]
    ],
    excitations
  ];

  Scan[applyLoad, loads];

  "OK"
]

(* Load geometry and excitations once, without setting a frequency or solving.
   Used by AntennaSweepMemory so the structure is built a single time and only
   the frequency-dependent steps (set_freq, ground, execute) repeat per point.
   Returns "OK" or a status string naming the failed stage. *)
loadGeometryOnce[wires_List, excitations_List, groundSpec_, loads_List] := Module[
  {result},

  result = nec2LinkInit[];
  If[result =!= 0, Return["InitFailed"]];

  Scan[
    Function[wire,
      nec2LinkAddWire[
        wire["Segments"], wire["Tag"],
        Developer`ToPackedArray[N[wire["P1"]]],
        Developer`ToPackedArray[N[wire["P2"]]],
        N[wire["Radius"]]
      ]
    ],
    wires
  ];

  result = nec2LinkGeometryEnd[groundConnectFlag[groundSpec]];
  If[result =!= 0, Return["GeometryEndFailed"]];

  (* Excitations and loads are frequency-independent registrations, applied once
     here; the loads' impedance is recomputed per frequency inside the solver. *)
  Scan[
    Function[ex,
      nec2LinkSetExcitation[
        ex["Tag"], ex["Segment"],
        Re[ex["Voltage"]], Im[ex["Voltage"]]
      ]
    ],
    excitations
  ];

  Scan[applyLoad, loads];

  "OK"
]

(* Build a Dataset of per-source input parameters (one row per voltage source)
   from the most recent solve: feed location, drive voltage, resulting current,
   input impedance Zin = V/I, and delivered power. Returns Missing[] when there
   are no sources. Call only after nec2LinkExecute[]. *)
inputParametersDataset[] := Module[{params},
  params = nec2LinkGetInputParameters[];
  If[Length[params] > 0,
    Dataset[<|
      "Tag" -> Round[#[[1]]],
      "Segment" -> Round[#[[2]]],
      "Voltage" -> #[[3]] + I*#[[4]],
      "Current" -> #[[5]] + I*#[[6]],
      "ZInput" -> #[[7]] + I*#[[8]],
      "Power" -> #[[9]]
    |> & /@ params],
    Missing["NotAvailable"]
  ]
];

(* --- Input validation for the public solver entry points ------------------ *)
validWireQ[w_Association] :=
  AllTrue[{"Segments", "Tag", "P1", "P2", "Radius"}, KeyExistsQ[w, #] &] &&
  IntegerQ[w["Segments"]] && Positive[w["Segments"]] &&
  IntegerQ[w["Tag"]] &&
  VectorQ[w["P1"], NumericQ] && Length[w["P1"]] === 3 &&
  VectorQ[w["P2"], NumericQ] && Length[w["P2"]] === 3 &&
  NumericQ[w["Radius"]] && Positive[w["Radius"]];
validWireQ[_] := False;

validExcitationQ[e_Association] :=
  AllTrue[{"Tag", "Segment", "Voltage"}, KeyExistsQ[e, #] &] &&
  IntegerQ[e["Tag"]] &&
  IntegerQ[e["Segment"]] && Positive[e["Segment"]] &&
  NumericQ[e["Voltage"]];
validExcitationQ[_] := False;

(* NEC LD-card type codes. *)
$loadTypeCodes = <|
  "Series" -> 0, "Parallel" -> 1,
  "SeriesPerMeter" -> 2, "ParallelPerMeter" -> 3,
  "Impedance" -> 4, "Conductivity" -> 5
|>;

validLoadQ[ld_Association] := KeyExistsQ[$loadTypeCodes, Lookup[ld, "Type", "Series"]];
validLoadQ[_] := False;

(* Register one validated lumped load with the solver. *)
applyLoad[load_Association] := Module[{type, segF, segT, a, b, c},
  type = Lookup[load, "Type", "Series"];
  segF = Lookup[load, "SegmentFrom", 0];
  segT = Lookup[load, "SegmentTo", 0];
  {a, b, c} = Switch[type,
    "Impedance",    {Lookup[load, "Resistance", 0.], Lookup[load, "Reactance", 0.], 0.},
    "Conductivity", {Lookup[load, "Conductivity", 0.], 0., 0.},
    _,              {Lookup[load, "Resistance", 0.], Lookup[load, "Inductance", 0.], Lookup[load, "Capacitance", 0.]}
  ];
  nec2LinkAddLoad[$loadTypeCodes[type], Lookup[load, "Tag", 0], segF, segT, N[a], N[b], N[c]]
];

(* Validate the wire, excitation, and load lists for the public function `sym`.
   On the first invalid entry, issue a message against `sym` and return False;
   otherwise return True. *)
validateSolverInputs[sym_, wires_List, excitations_List, loads_List] := Module[{bad},
  If[wires === {}, Message[MessageName[sym, "nowires"]]; Return[False]];
  bad = SelectFirst[wires, ! validWireQ[#] &, None];
  If[bad =!= None, Message[MessageName[sym, "badwire"], bad]; Return[False]];
  bad = SelectFirst[excitations, ! validExcitationQ[#] &, None];
  If[bad =!= None, Message[MessageName[sym, "badex"], bad]; Return[False]];
  bad = SelectFirst[loads, ! validLoadQ[#] &, None];
  If[bad =!= None, Message[MessageName[sym, "badload"], bad]; Return[False]];
  True
];

Options[AntennaSolveMemory] = {"Ground" -> None, "Loads" -> {}};

AntennaSolveMemory[wires_List, freq_?NumericQ, excitations_List, opts:OptionsPattern[]] := Module[
  {status, currentsTensor, currentData, groundSpec, loads},

  If[$LibraryFile === $Failed,
    Message[AntennaSolve::nolib];
    Return[$Failed]
  ];

  groundSpec = OptionValue[AntennaSolveMemory, {opts}, "Ground"];
  loads = OptionValue[AntennaSolveMemory, {opts}, "Loads"];

  If[! validateSolverInputs[AntennaSolveMemory, wires, excitations, loads], Return[$Failed]];

  status = setupGeometry[wires, freq, excitations, groundSpec, loads];
  If[status =!= "OK", Message[AntennaSolve::err, status]; Return[$Failed]];

  currentsTensor = nec2LinkExecute[];

  If[Length[currentsTensor] > 0,
    currentData = Dataset[AssociationThread[
      {"CurrentReal", "CurrentImag", "X", "Y", "Z"},
      #
    ]& /@ currentsTensor];

    <|"Currents" -> currentData, "InputParameters" -> inputParametersDataset[],
      "Wires" -> wires, "Excitations" -> excitations|>
  ,
    $Failed
  ]
]

Options[AntennaFarFieldMemory] = {"Ground" -> None, "Loads" -> {}};

AntennaFarFieldMemory[wires_List, freq_?NumericQ, excitations_List, thetaList_List, phiList_List, opts:OptionsPattern[]] := Module[
  {status, currentsTensor, currentsData, farFieldTensor, farFieldData, thetaRad, phiRad, groundSpec, loads},

  If[$LibraryFile === $Failed,
    Message[AntennaSolve::nolib];
    Return[$Failed]
  ];

  groundSpec = OptionValue[AntennaFarFieldMemory, {opts}, "Ground"];
  loads = OptionValue[AntennaFarFieldMemory, {opts}, "Loads"];

  If[! validateSolverInputs[AntennaFarFieldMemory, wires, excitations, loads], Return[$Failed]];

  status = setupGeometry[wires, freq, excitations, groundSpec, loads];
  If[status =!= "OK", Message[AntennaSolve::err, status]; Return[$Failed]];

  currentsTensor = nec2LinkExecute[];
  If[Length[currentsTensor] == 0, Return[$Failed]];
  
  currentsData = Dataset[AssociationThread[
    {"CurrentReal", "CurrentImag", "X", "Y", "Z"},
    #
  ]& /@ currentsTensor];
  
  thetaRad = N[thetaList] * Degree;
  phiRad = N[phiList] * Degree;
  
  farFieldTensor = nec2LinkFarField[thetaRad, phiRad];
  If[Length[farFieldTensor] == 0, Return[$Failed]];
  
  farFieldData = Dataset[
    <|
      "Theta" -> #[[1]] / Degree,
      "Phi" -> #[[2]] / Degree,
      "ETheta" -> #[[3]] + I * #[[4]],
      "EPhi" -> #[[5]] + I * #[[6]],
      "Gain" -> #[[7]],
      "GainDB" -> If[#[[7]] > 10^-20, 10. * Log10[#[[7]]], -999.99]
    |>& /@ farFieldTensor
  ];
  
  <|"Currents" -> currentsData, "FarField" -> farFieldData,
    "InputParameters" -> inputParametersDataset[],
    "Wires" -> wires, "Excitations" -> excitations|>]

AntennaYagiUda[assoc_Association] := With[
  {missing = Select[
     {"ReflectorLength", "ReflectorSpacing", "DrivenLength", "DirectorLengths", "DirectorSpacings"},
     ! KeyExistsQ[assoc, #] &]},
  If[missing =!= {},
    Message[AntennaYagiUda::missingkey, missing]; $Failed,
    AntennaYagiUda[
      assoc["ReflectorLength"], assoc["ReflectorSpacing"], assoc["DrivenLength"],
      assoc["DirectorLengths"], assoc["DirectorSpacings"],
      Lookup[assoc, "WireRadius", 0.001], Lookup[assoc, "Segments", 11]
    ]
  ]
]

AntennaYagiUda[reflectorLength_, reflectorSpacing_, drivenLength_, directorLengths_List, directorSpacings_List, wireRadius_:0.001, segments_:11] := Module[
  {wires, cumY},
  
  wires = {
    (* Reflector *)
    <|
      "Segments" -> segments,
      "Tag" -> 1,
      "P1" -> {0.0, -N[reflectorSpacing], -N[reflectorLength]/2.0},
      "P2" -> {0.0, -N[reflectorSpacing], N[reflectorLength]/2.0},
      "Radius" -> N[wireRadius]
    |>,
    (* Driven Element *)
    <|
      "Segments" -> segments,
      "Tag" -> 2,
      "P1" -> {0.0, 0.0, -N[drivenLength]/2.0},
      "P2" -> {0.0, 0.0, N[drivenLength]/2.0},
      "Radius" -> N[wireRadius]
    |>
  };
  
  cumY = 0.0;
  Do[
    cumY += N[directorSpacings[[i]]];
    AppendTo[wires, <|
      "Segments" -> segments,
      "Tag" -> 2 + i,
      "P1" -> {0.0, cumY, -N[directorLengths[[i]]]/2.0},
      "P2" -> {0.0, cumY, N[directorLengths[[i]]]/2.0},
      "Radius" -> N[wireRadius]
    |>],
    {i, 1, Length[directorLengths]}
  ];
  
  wires
]

AntennaHelix[assoc_Association] := With[
  {missing = Select[{"Radius", "Pitch", "Turns"}, ! KeyExistsQ[assoc, #] &]},
  If[missing =!= {},
    Message[AntennaHelix::missingkey, missing]; $Failed,
    AntennaHelix[
      assoc["Radius"], assoc["Pitch"], assoc["Turns"],
      Lookup[assoc, "WireRadius", 0.001], Lookup[assoc, "SegmentsPerTurn", 16]
    ]
  ]
]

AntennaHelix[radius_, pitch_, turns_, wireRadius_:0.001, segmentsPerTurn_:16] := Module[
  {totalSegments, phiStep, phiVal, p1, p2},
  
  totalSegments = Round[N[turns] * segmentsPerTurn];
  phiStep = (2.0 * Pi * N[turns]) / totalSegments;
  
  Table[
    phiVal = k * phiStep;
    p1 = {N[radius] * Cos[phiVal - phiStep], N[radius] * Sin[phiVal - phiStep], N[pitch] * ((phiVal - phiStep) / (2.0 * Pi))};
    p2 = {N[radius] * Cos[phiVal], N[radius] * Sin[phiVal], N[pitch] * (phiVal / (2.0 * Pi))};
    <|
      "Segments" -> 1,
      "Tag" -> k,
      "P1" -> p1,
      "P2" -> p2,
      "Radius" -> N[wireRadius]
    |>,
    {k, 1, totalSegments}
  ]
]

AntennaParabolicReflector[assoc_Association] := With[
  {missing = Select[{"FocalLength", "DishRadius", "NumRibs", "NumRings"}, ! KeyExistsQ[assoc, #] &]},
  If[missing =!= {},
    Message[AntennaParabolicReflector::missingkey, missing]; $Failed,
    AntennaParabolicReflector[
      assoc["FocalLength"], assoc["DishRadius"], assoc["NumRibs"], assoc["NumRings"],
      Lookup[assoc, "WireRadius", 0.001]
    ]
  ]
]

AntennaParabolicReflector[focalLength_, dishRadius_, numRibs_, numRings_, wireRadius_:0.001] := Module[
  {wires, ribsAngles, ringRadii, phi, r1, r2, p1, p2, tag},

  wires = {};
  tag = 0;   (* running counter: every rib and ring wire gets a unique tag *)
  ribsAngles = Table[k * (2.0 * Pi) / N[numRibs], {k, 1, numRibs}];
  ringRadii = Table[j * N[dishRadius] / N[numRings], {j, 0, numRings}];

  (* Generate Ribs *)
  Do[
    phi = ribsAngles[[k]];
    Do[
      r1 = ringRadii[[j]];
      r2 = ringRadii[[j + 1]];
      p1 = {r1 * Cos[phi], r1 * Sin[phi], (r1^2) / (4.0 * N[focalLength])};
      p2 = {r2 * Cos[phi], r2 * Sin[phi], (r2^2) / (4.0 * N[focalLength])};
      AppendTo[wires, <|
        "Segments" -> 1,
        "Tag" -> ++tag,
        "P1" -> p1,
        "P2" -> p2,
        "Radius" -> N[wireRadius]
      |>],
      {j, 1, numRings}
    ],
    {k, 1, numRibs}
  ];

  (* Generate Rings *)
  Do[
    r2 = ringRadii[[j + 1]];
    Do[
      With[{phi1 = If[k == 1, ribsAngles[[numRibs]], ribsAngles[[k - 1]]], phi2 = ribsAngles[[k]]},
        p1 = {r2 * Cos[phi1], r2 * Sin[phi1], (r2^2) / (4.0 * N[focalLength])};
        p2 = {r2 * Cos[phi2], r2 * Sin[phi2], (r2^2) / (4.0 * N[focalLength])};
        AppendTo[wires, <|
          "Segments" -> 1,
          "Tag" -> ++tag,
          "P1" -> p1,
          "P2" -> p2,
          "Radius" -> N[wireRadius]
        |>]
      ],
      {k, 1, numRibs}
    ],
    {j, 1, numRings}
  ];

  wires
]

Options[AntennaSweepMemory] = {"Ground" -> None, "ReferenceImpedance" -> 50.0, "Loads" -> {}};

AntennaSweepMemory[wires_List, freqSpec_, excitations_List, opts:OptionsPattern[]] := Module[
  {freqList, z0, results, groundSpec, loads, loadStatus},

  If[$LibraryFile === $Failed,
    Message[AntennaSolve::nolib];
    Return[$Failed]
  ];

  z0 = OptionValue[AntennaSweepMemory, {opts}, "ReferenceImpedance"];
  groundSpec = OptionValue[AntennaSweepMemory, {opts}, "Ground"];
  loads = OptionValue[AntennaSweepMemory, {opts}, "Loads"];

  If[! validateSolverInputs[AntennaSweepMemory, wires, excitations, loads], Return[$Failed]];

  freqList = Switch[freqSpec,
    _List,
      N[freqSpec],
    _?NumericQ,
      {N[freqSpec]},
    _,
      Message[AntennaSweepMemory::freq, Defer[freqSpec]];
      Return[$Failed]
  ];
  
  (* Build the structure once; only the frequency-dependent steps below repeat. *)
  loadStatus = loadGeometryOnce[wires, excitations, groundSpec, loads];
  If[loadStatus =!= "OK",
    Return[Dataset[Table[<|"Frequency" -> f, "Error" -> loadStatus|>, {f, freqList}]]]
  ];

  results = Table[
    Module[{currents, inputParams, tag, seg, voltage, current, zin, pwr, gamma, s11, vswr},
      nec2LinkSetFreq[f];
      setupGround[groundSpec];
      Which[
        Length[currents = nec2LinkExecute[]] == 0,
          <|"Frequency" -> f, "Error" -> "ExecuteFailed"|>,
        Length[inputParams = nec2LinkGetInputParameters[]] == 0,
          <|"Frequency" -> f, "Error" -> "NoExcitations"|>,
        True,
          With[{row = inputParams[[1]]},
            tag = Round[row[[1]]];
            seg = Round[row[[2]]];
            voltage = row[[3]] + I * row[[4]];
            current = row[[5]] + I * row[[6]];
            zin = row[[7]] + I * row[[8]];
            pwr = row[[9]];

            gamma = (zin - z0) / (zin + z0);
            s11 = If[Abs[gamma] > 10^-20, 20.0 * Log10[Abs[gamma]], -999.99];
            vswr = If[Abs[1.0 - Abs[gamma]] > 10^-20, (1.0 + Abs[gamma]) / (1.0 - Abs[gamma]), Infinity];

            <|
              "Frequency" -> f,
              "Tag" -> tag,
              "Segment" -> seg,
              "Voltage" -> voltage,
              "Current" -> current,
              "ZInput" -> zin,
              "Power" -> pwr,
              "S11" -> s11,
              "VSWR" -> vswr
            |>
          ]
      ]
    ],
    {f, freqList}
  ];

  Dataset[results]
]

Options[AntennaPlotGeometry] = {
  "ColorFunction" -> Automatic,
  "HighlightExcitations" -> True,
  "ScaleFactor" -> 1.0,
  "ReturnPrimitives" -> False
};

AntennaPlotGeometry[input_, opts:OptionsPattern[]] := Module[
  {wires, currents, excitations, colorFunc, highlightEx, scale, returnPrims, 
   flatSegments, allPoints, maxDim, visualRadius, maxCurrent, magnitudes, phases, 
   primitives, sphereRadius, currentsList},
   
  colorFunc = OptionValue[AntennaPlotGeometry, {opts}, "ColorFunction"];
  highlightEx = OptionValue[AntennaPlotGeometry, {opts}, "HighlightExcitations"];
  scale = OptionValue[AntennaPlotGeometry, {opts}, "ScaleFactor"];
  returnPrims = OptionValue[AntennaPlotGeometry, {opts}, "ReturnPrimitives"];
  
  (* Resolve inputs *)
  {wires, currents, excitations} = Switch[input,
    _Association,
      {
        Lookup[input, "Wires", {}],
        Lookup[input, "Currents", None],
        Lookup[input, "Excitations", {}]
      },
    _List,
      {input, None, {}},
    _,
      Message[AntennaPlotGeometry::invalid, Defer[input]];
      Return[$Failed]
  ];
  
  If[wires === {},
    Return[{}]
  ];
  
  (* Bounding box for visual radius scaling *)
  allPoints = Join[Lookup[wires, "P1"], Lookup[wires, "P2"]];
  maxDim = Max[
    Max[allPoints[[All, 1]]] - Min[allPoints[[All, 1]]],
    Max[allPoints[[All, 2]]] - Min[allPoints[[All, 2]]],
    Max[allPoints[[All, 3]]] - Min[allPoints[[All, 3]]],
    0.001
  ];
  visualRadius = scale * maxDim * 0.008;
  sphereRadius = visualRadius * 2.2;
  
  (* Generate flat list of segments matching solver structure *)
  flatSegments = {};
  Do[
    Module[{segs = wire["Segments"], p1 = wire["P1"], p2 = wire["P2"], r = Lookup[wire, "Radius", 0.001], tag = wire["Tag"]},
      Do[
        AppendTo[flatSegments, <|
          "WireTag" -> tag,
          "SegmentIndex" -> s,
          "P1" -> p1 + (s - 1)/segs * (p2 - p1),
          "P2" -> p1 + s/segs * (p2 - p1),
          "Radius" -> Max[r, visualRadius]
        |>],
        {s, 1, segs}
      ]
    ],
    {wire, wires}
  ];
  
  (* Parse currents if available *)
  If[currents =!= None,
    currentsList = Normal[currents];
    magnitudes = Map[
      Function[row,
        Abs[Lookup[row, "CurrentReal", 0.0] + I * Lookup[row, "CurrentImag", 0.0]]
      ],
      currentsList
    ];
    phases = Map[
      Function[row,
        Arg[Lookup[row, "CurrentReal", 0.0] + I * Lookup[row, "CurrentImag", 0.0]] / Degree
      ],
      currentsList
    ];
    maxCurrent = Max[magnitudes];
  ,
    magnitudes = None;
    maxCurrent = 0.0;
  ];
  
  (* Build primitives *)
  primitives = {};
  Do[
    Module[{seg = flatSegments[[k]], p1, p2, rad, color, mag, ph},
      p1 = seg["P1"];
      p2 = seg["P2"];
      rad = seg["Radius"];
      
      color = GrayLevel[0.6]; (* Default color *)
      
      If[magnitudes =!= None && Length[magnitudes] >= k,
        mag = magnitudes[[k]];
        ph = phases[[k]];
        
        Switch[colorFunc,
          "Phase",
            (* Map phase from -180..180 to 0..1 Hue *)
            color = Hue[(ph + 180.0)/360.0],
          _,
            (* Default/Magnitude *)
            color = If[maxCurrent > 10^-20,
              ColorData["TemperatureMap"][mag / maxCurrent],
              ColorData["TemperatureMap"][0.0]
            ]
        ]
      ];
      
      AppendTo[primitives, {color, Cylinder[{p1, p2}, rad]}];
    ],
    {k, 1, Length[flatSegments]}
  ];
  
  (* Highlight excitations *)
  If[highlightEx && ListQ[excitations] && Length[excitations] > 0,
    Do[
      Module[{tag = ex["Tag"], segIdx = ex["Segment"], matchingSeg},
        matchingSeg = Select[flatSegments, #WireTag == tag && #SegmentIndex == segIdx &];
        If[Length[matchingSeg] > 0,
          Module[{center = (matchingSeg[[1, "P1"]] + matchingSeg[[1, "P2"]]) / 2.0},
            AppendTo[primitives, {RGBColor[0.0, 0.9, 0.1], Sphere[center, sphereRadius]}]
          ]
        ]
      ],
      {ex, excitations}
    ]
  ];
  
  If[returnPrims,
    primitives,
    Graphics3D[
      primitives,
      Axes -> True,
      AxesLabel -> {"X", "Y", "Z"},
      Boxed -> True,
      Lighting -> "Neutral",
      ViewPoint -> {1.5, -2.5, 1.5}
    ]
  ]
]

AntennaPlotGeometry::invalid = "The input `1` is not a valid wire list or solved result association.";

Options[AntennaPlotPattern3D] = {
  "PlotType" -> "dB",
  "DynamicRange" -> 40.0,
  "ColorFunction" -> "Rainbow",
  "ShowGeometry" -> True,
  "ScaleFactor" -> 1.0
};

AntennaPlotPattern3D[input_, opts:OptionsPattern[]] := Module[
  {farFieldData, plotType, range, colorFunc, showGeom, scale, data, 
   thetas, phis, gainAssoc, numThetas, numPhis, maxGainDB, minGainDB, minDB, 
   vCoords, vValues, vColors, minVal, maxVal, polygons, 
   geomPrims, scaledGeomPrims, maxPatRadius, maxGeomDim, geomScale},
   
  plotType = OptionValue[AntennaPlotPattern3D, {opts}, "PlotType"];
  range = OptionValue[AntennaPlotPattern3D, {opts}, "DynamicRange"];
  colorFunc = OptionValue[AntennaPlotPattern3D, {opts}, "ColorFunction"];
  showGeom = OptionValue[AntennaPlotPattern3D, {opts}, "ShowGeometry"];
  scale = OptionValue[AntennaPlotPattern3D, {opts}, "ScaleFactor"];
  
  (* Resolve inputs *)
  farFieldData = Switch[input,
    _Association,
      Lookup[input, "FarField", None],
    _,
      input
  ];
  
  If[farFieldData === None,
    Message[AntennaPlotPattern3D::invalid, Defer[input]];
    Return[$Failed]
  ];
  
  data = Normal[farFieldData];
  If[!ListQ[data] || Length[data] == 0,
    Message[AntennaPlotPattern3D::invalid, Defer[input]];
    Return[$Failed]
  ];
  
  thetas = Union[Lookup[data, "Theta"]];
  phis = Union[Lookup[data, "Phi"]];
  
  numThetas = Length[thetas];
  numPhis = Length[phis];
  
  If[numThetas < 2 || numPhis < 2,
    Message[AntennaPlotPattern3D::grid];
    Return[$Failed]
  ];
  
  gainAssoc = AssociationThread[
    Transpose[{Lookup[data, "Theta"], Lookup[data, "Phi"]}],
    data
  ];
  
  If[plotType === "dB",
    maxGainDB = Max[Lookup[data, "GainDB"]];
    minGainDB = Min[Lookup[data, "GainDB"]];
    minDB = Max[maxGainDB - range, minGainDB];
  ];
  
  (* Build vertices *)
  vCoords = Table[
    Module[{theta = thetas[[i]], phi = phis[[j]], row, val, r, thetaRad, phiRad},
      row = Lookup[gainAssoc, Key[{theta, phi}], None];
      If[row === None,
        {0.0, 0.0, 0.0},
        val = If[plotType === "dB",
          row["GainDB"],
          row["Gain"]
        ];
        r = If[plotType === "dB",
          Max[0.0, val - minDB],
          val
        ];
        thetaRad = theta * Degree;
        phiRad = phi * Degree;
        r * {Sin[thetaRad] * Cos[phiRad], Sin[thetaRad] * Sin[phiRad], Cos[thetaRad]}
      ]
    ],
    {i, 1, numThetas},
    {j, 1, numPhis}
  ];
  
  (* Build vertex values for coloring *)
  vValues = Table[
    Module[{theta = thetas[[i]], phi = phis[[j]], row},
      row = Lookup[gainAssoc, Key[{theta, phi}], None];
      If[row === None, 
        0.0, 
        If[plotType === "dB", row["GainDB"], row["Gain"]]
      ]
    ],
    {i, 1, numThetas},
    {j, 1, numPhis}
  ];
  
  minVal = Min[vValues];
  maxVal = Max[vValues];
  
  vColors = Map[
    Function[val,
      If[Precision[maxVal - minVal] === 0 || maxVal == minVal,
        ColorData[colorFunc][0.5],
        ColorData[colorFunc][(val - minVal) / (maxVal - minVal)]
      ]
    ],
    vValues,
    {2}
  ];
  
  (* Build polygons *)
  polygons = Table[
    Polygon[
      {vCoords[[i, j]], vCoords[[i + 1, j]], vCoords[[i + 1, j + 1]], vCoords[[i, j + 1]]},
      VertexColors -> {vColors[[i, j]], vColors[[i + 1, j]], vColors[[i + 1, j + 1]], vColors[[i, j + 1]]}
    ],
    {i, 1, numThetas - 1},
    {j, 1, numPhis - 1}
  ];
  
  (* Handle geometry overlay *)
  scaledGeomPrims = {};
  If[showGeom && AssociationQ[input] && KeyExistsQ[input, "Wires"],
    geomPrims = AntennaPlotGeometry[
      input, 
      "ReturnPrimitives" -> True, 
      "HighlightExcitations" -> True,
      "ScaleFactor" -> scale
    ];
    
    If[Length[geomPrims] > 0,
      maxPatRadius = Max[Map[Norm, Flatten[vCoords, 1]]];
      
      (* Bounding box size of geometry *)
      Module[{wires = input["Wires"], allPoints, maxGeomDim},
        allPoints = Join[Lookup[wires, "P1"], Lookup[wires, "P2"]];
        maxGeomDim = Max[
          Max[allPoints[[All, 1]]] - Min[allPoints[[All, 1]]],
          Max[allPoints[[All, 2]]] - Min[allPoints[[All, 2]]],
          Max[allPoints[[All, 3]]] - Min[allPoints[[All, 3]]],
          0.001
        ];
        
        geomScale = If[maxPatRadius > 0.0,
          (maxPatRadius * 0.25) / maxGeomDim,
          1.0
        ];
        
        scaledGeomPrims = GeometricTransformation[
          geomPrims, 
          ScalingTransform[{geomScale, geomScale, geomScale}]
        ];
      ]
    ]
  ];
  
  Graphics3D[
    {
      {EdgeForm[None], polygons},
      scaledGeomPrims
    },
    Axes -> True,
    AxesLabel -> {"X", "Y", "Z"},
    Boxed -> True,
    Lighting -> "Neutral",
    ViewPoint -> {1.5, -2.5, 1.5}
  ]
]

AntennaPlotPattern3D::invalid = "The input `1` is not a valid far-field dataset or solved result association.";
AntennaPlotPattern3D::grid = "The far field dataset must contain a 3D grid of angles with at least 2 distinct Theta and Phi values.";

Options[AntennaPlotPattern2D] = {
  "Plane" -> "Elevation",
  "Angle" -> Automatic,
  "PlotType" -> "dB",
  "DynamicRange" -> 40.0
};

AntennaPlotPattern2D[input_, opts:OptionsPattern[]] := Module[
  {farFieldData, plane, angleOpt, plotType, range, data, thetas, phis, gainAssoc,
   valueKey, valueAt, maxDB, minDB, radiusOf, fixedPhi, fixedPhi2, fixedTheta,
   pts, plotAngle, label},

  (* Resolve input: a solved-result association, or the far-field dataset. *)
  farFieldData = Switch[input,
    _Association, Lookup[input, "FarField", None],
    _, input
  ];
  If[farFieldData === None || MissingQ[farFieldData],
    Message[AntennaPlotPattern2D::invalid, Defer[input]]; Return[$Failed]
  ];

  data = Normal[farFieldData];
  If[! ListQ[data] || data === {} || ! AssociationQ[First[data]],
    Message[AntennaPlotPattern2D::invalid, Defer[input]]; Return[$Failed]
  ];

  plane = OptionValue["Plane"];
  angleOpt = OptionValue["Angle"];
  plotType = OptionValue["PlotType"];
  range = OptionValue["DynamicRange"];

  thetas = Union[Lookup[data, "Theta"]];
  phis = Union[Lookup[data, "Phi"]];

  valueKey = If[plotType === "dB", "GainDB", "Gain"];
  gainAssoc = AssociationThread[
    Transpose[{Lookup[data, "Theta"], Lookup[data, "Phi"]}],
    Lookup[data, valueKey]
  ];
  valueAt[th_, ph_] := Lookup[gainAssoc, Key[{th, ph}], Missing[]];

  (* Radius mapping: in dB, shift so the peak sits at the rim and the floor
     (peak - DynamicRange) sits at the center; linear gain is used directly. *)
  maxDB = Max[Lookup[data, "GainDB"]];
  minDB = maxDB - range;
  radiusOf[v_] := Which[
    MissingQ[v], 0.0,
    plotType === "dB", Max[0.0, v - minDB],
    True, Max[0.0, v]
  ];

  Switch[plane,
    "Azimuth",
      fixedTheta = First[Nearest[thetas, If[angleOpt === Automatic, 90.0, N[angleOpt]]]];
      pts = Table[{ph Degree, radiusOf[valueAt[fixedTheta, ph]]}, {ph, phis}];
      (* close the loop *)
      If[pts =!= {}, pts = Append[pts, First[pts]]];
      label = "Azimuth cut (\[Theta] = " <> ToString[fixedTheta] <> "\[Degree])",

    _, (* "Elevation" *)
      fixedPhi = First[Nearest[phis, If[angleOpt === Automatic, 0.0, N[angleOpt]]]];
      fixedPhi2 = First[Nearest[phis, Mod[fixedPhi + 180.0, 360.0]]];
      (* phi0 half-plane: +Z (theta=0) at top, sweeping to the fixedPhi side *)
      pts = Table[{(90.0 - th) Degree, radiusOf[valueAt[th, fixedPhi]]}, {th, thetas}];
      If[fixedPhi2 != fixedPhi,
        pts = Join[pts,
          Reverse@Table[{(90.0 + th) Degree, radiusOf[valueAt[th, fixedPhi2]]}, {th, thetas}]]
      ];
      If[pts =!= {}, pts = Append[pts, First[pts]]];
      label = "Elevation cut (\[Phi] = " <> ToString[fixedPhi] <> "\[Degree])"
  ];

  ListPolarPlot[pts,
    Joined -> True,
    PlotRange -> All,
    PolarAxes -> True,
    PolarGridLines -> Automatic,
    PlotStyle -> Directive[Thick, ColorData[97][1]],
    PlotLabel -> label <> If[plotType === "dB", "  [dB, " <> ToString[range] <> " dB range]", "  [linear gain]"]
  ]
]

AntennaPlotPattern2D::invalid = "The input `1` is not a valid far-field dataset or solved result association.";

End[] (* `Private` *)

EndPackage[]
