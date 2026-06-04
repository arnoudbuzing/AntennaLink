(* ::Package:: *)

BeginPackage["ArnoudBuzing`AntennaLink`"]

AntennaSolve::usage = "AntennaSolve[inputFile, outputFile] runs the NEC2 MoM solver on the given inputFile (.nec) and writes the results to outputFile (.out)."
AntennaParseOutput::usage = "AntennaParseOutput[file] parses a NEC .out file into an Association containing Datasets."
AntennaSolveMemory::usage = "AntennaSolveMemory[wires, freq, excitations] runs the NEC2 solver directly in memory, bypassing file I/O."

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

AntennaSolveMemory[wires_List, freq_Real, excitations_List] := Module[
  {result, currentsTensor, currentData},
  
  If[$LibraryFile === $Failed,
    Message[AntennaSolve::nolib];
    Return[$Failed]
  ];
  
  result = nec2LinkInit[];
  If[result =!= 0, Message[AntennaSolve::err, result]; Return[$Failed]];
  
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
  
  result = nec2LinkGeometryEnd[0];
  If[result =!= 0, Message[AntennaSolve::err, result]; Return[$Failed]];
  
  result = nec2LinkSetFreq[freq];
  If[result =!= 0, Message[AntennaSolve::err, result]; Return[$Failed]];
  
  Scan[
    Function[ex,
      nec2LinkSetExcitation[
        ex["Tag"], ex["Segment"], 
        Re[ex["Voltage"]], Im[ex["Voltage"]]
      ]
    ],
    excitations
  ];
  
  currentsTensor = nec2LinkExecute[];
  
  If[Length[currentsTensor] > 0,
    currentData = Dataset[AssociationThread[
      {"CurrentReal", "CurrentImag", "X", "Y", "Z"},
      #
    ]& /@ currentsTensor];
    
    <|"Currents" -> currentData|>
  ,
    $Failed
  ]
]

End[] (* `Private` *)

EndPackage[]
