(* ::Package:: *)

BeginPackage["ArnoudBuzing`AntennaLink`"]

AntennaSolve::usage = "AntennaSolve[inputFile, outputFile] runs the NEC2 MoM solver on the given inputFile (.nec) and writes the results to outputFile (.out)."
AntennaParseOutput::usage = "AntennaParseOutput[file] parses a NEC .out file into an Association containing Datasets."
AntennaSolveMemory::usage = "AntennaSolveMemory[wires, freq, excitations] runs the NEC2 solver directly in memory, bypassing file I/O."
AntennaFarFieldMemory::usage = "AntennaFarFieldMemory[wires, freq, excitations, thetaList, phiList] runs the NEC2 solver directly in memory and computes the far-field E-fields and gains for the specified list of theta and phi angles (in degrees)."
AntennaYagiUda::usage = "AntennaYagiUda[reflectorLength, reflectorSpacing, drivenLength, directorLengths, directorSpacings, wireRadius, segments] or AntennaYagiUda[assoc] creates a structured list of wire associations representing a Yagi-Uda antenna aligned along the Y-axis."
AntennaHelix::usage = "AntennaHelix[radius, pitch, turns, wireRadius, segmentsPerTurn] or AntennaHelix[assoc] creates a structured list of wire associations representing a helical antenna along the Z-axis."
AntennaParabolicReflector::usage = "AntennaParabolicReflector[focalLength, dishRadius, numRibs, numRings, wireRadius] or AntennaParabolicReflector[assoc] creates a structured list of wire associations representing a wire-grid parabolic reflector dish vertexed at the origin."
AntennaSweepMemory::usage = "AntennaSweepMemory[wires, freqSpec, excitations] sweeps the frequencies given by freqSpec (a single frequency or an explicit list, e.g. Range[fmin, fmax, step]) to compute input impedance, S11, and VSWR in memory."
AntennaPlotGeometry::usage = "AntennaPlotGeometry[wires] plots the 3D geometry of the antenna. AntennaPlotGeometry[solveResult] plots the geometry colored by computed segment currents."
AntennaPlotPattern3D::usage = "AntennaPlotPattern3D[farFieldData] plots the 3D radiation pattern. AntennaPlotPattern3D[solveResult] plots the radiation pattern and overlays the physical antenna geometry at the center."

Begin["`Private`"]

$LibraryFile = FindLibrary["libnec2link"];

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
setupGeometry[wires_List, freq_?NumericQ, excitations_List, groundSpec_] := Module[
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

  "OK"
]

Options[AntennaSolveMemory] = {"Ground" -> None};

AntennaSolveMemory[wires_List, freq_?NumericQ, excitations_List, opts:OptionsPattern[]] := Module[
  {status, currentsTensor, currentData, groundSpec},

  If[$LibraryFile === $Failed,
    Message[AntennaSolve::nolib];
    Return[$Failed]
  ];

  groundSpec = OptionValue[AntennaSolveMemory, {opts}, "Ground"];

  status = setupGeometry[wires, freq, excitations, groundSpec];
  If[status =!= "OK", Message[AntennaSolve::err, status]; Return[$Failed]];

  currentsTensor = nec2LinkExecute[];

  If[Length[currentsTensor] > 0,
    currentData = Dataset[AssociationThread[
      {"CurrentReal", "CurrentImag", "X", "Y", "Z"},
      #
    ]& /@ currentsTensor];
    
    <|"Currents" -> currentData, "Wires" -> wires, "Excitations" -> excitations|>
  ,
    $Failed
  ]
]

Options[AntennaFarFieldMemory] = {"Ground" -> None};

AntennaFarFieldMemory[wires_List, freq_?NumericQ, excitations_List, thetaList_List, phiList_List, opts:OptionsPattern[]] := Module[
  {status, currentsTensor, currentsData, farFieldTensor, farFieldData, thetaRad, phiRad, groundSpec},

  If[$LibraryFile === $Failed,
    Message[AntennaSolve::nolib];
    Return[$Failed]
  ];

  groundSpec = OptionValue[AntennaFarFieldMemory, {opts}, "Ground"];

  status = setupGeometry[wires, freq, excitations, groundSpec];
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
  
  <|"Currents" -> currentsData, "FarField" -> farFieldData, "Wires" -> wires, "Excitations" -> excitations|>]

AntennaYagiUda[assoc_Association] := Module[
  {reflectorLength, reflectorSpacing, drivenLength, directorLengths, directorSpacings, wireRadius, segments},
  reflectorLength = Lookup[assoc, "ReflectorLength"];
  reflectorSpacing = Lookup[assoc, "ReflectorSpacing"];
  drivenLength = Lookup[assoc, "DrivenLength"];
  directorLengths = Lookup[assoc, "DirectorLengths"];
  directorSpacings = Lookup[assoc, "DirectorSpacings"];
  wireRadius = Lookup[assoc, "WireRadius", 0.001];
  segments = Lookup[assoc, "Segments", 11];
  
  AntennaYagiUda[reflectorLength, reflectorSpacing, drivenLength, directorLengths, directorSpacings, wireRadius, segments] /;
    !MissingQ[reflectorLength] && !MissingQ[reflectorSpacing] && !MissingQ[drivenLength] && ListQ[directorLengths] && ListQ[directorSpacings]
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

AntennaHelix[assoc_Association] := Module[
  {radius, pitch, turns, wireRadius, segmentsPerTurn},
  radius = Lookup[assoc, "Radius"];
  pitch = Lookup[assoc, "Pitch"];
  turns = Lookup[assoc, "Turns"];
  wireRadius = Lookup[assoc, "WireRadius", 0.001];
  segmentsPerTurn = Lookup[assoc, "SegmentsPerTurn", 16];
  
  AntennaHelix[radius, pitch, turns, wireRadius, segmentsPerTurn] /;
    !MissingQ[radius] && !MissingQ[pitch] && !MissingQ[turns]
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
      "Tag" -> 1,
      "P1" -> p1,
      "P2" -> p2,
      "Radius" -> N[wireRadius]
    |>,
    {k, 1, totalSegments}
  ]
]

AntennaParabolicReflector[assoc_Association] := Module[
  {focalLength, dishRadius, numRibs, numRings, wireRadius},
  focalLength = Lookup[assoc, "FocalLength"];
  dishRadius = Lookup[assoc, "DishRadius"];
  numRibs = Lookup[assoc, "NumRibs"];
  numRings = Lookup[assoc, "NumRings"];
  wireRadius = Lookup[assoc, "WireRadius", 0.001];
  
  AntennaParabolicReflector[focalLength, dishRadius, numRibs, numRings, wireRadius] /;
    !MissingQ[focalLength] && !MissingQ[dishRadius] && !MissingQ[numRibs] && !MissingQ[numRings]
]

AntennaParabolicReflector[focalLength_, dishRadius_, numRibs_, numRings_, wireRadius_:0.001] := Module[
  {wires, ribsAngles, ringRadii, phi, r1, r2, p1, p2},
  
  wires = {};
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
        "Tag" -> 1,
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
          "Tag" -> 2,
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

Options[AntennaSweepMemory] = {"Ground" -> None, "ReferenceImpedance" -> 50.0};

AntennaSweepMemory[wires_List, freqSpec_, excitations_List, opts:OptionsPattern[]] := Module[
  {freqList, z0, results, groundSpec},

  If[$LibraryFile === $Failed,
    Message[AntennaSolve::nolib];
    Return[$Failed]
  ];

  z0 = OptionValue[AntennaSweepMemory, {opts}, "ReferenceImpedance"];
  groundSpec = OptionValue[AntennaSweepMemory, {opts}, "Ground"];

  freqList = Switch[freqSpec,
    _List,
      N[freqSpec],
    _?NumericQ,
      {N[freqSpec]},
    _,
      Message[AntennaSweepMemory::freq, Defer[freqSpec]];
      Return[$Failed]
  ];
  
  results = Table[
    Module[{status, currents, inputParams, tag, seg, voltage, current, zin, pwr, gamma, s11, vswr},
      status = setupGeometry[wires, f, excitations, groundSpec];
      Which[
        status =!= "OK",
          <|"Frequency" -> f, "Error" -> status|>,
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

End[] (* `Private` *)

EndPackage[]
