(* ::Package:: *)

BeginPackage["ArnoudBuzing`AntennaLink`"]

AntennaSolve::usage = "AntennaSolve[inputFile, outputFile] runs the NEC2 MoM solver on the given inputFile (.nec) and writes the results to outputFile (.out)."

Begin["`Private`"]

$LibraryFile = FindLibrary["libnec2link"];

If[$LibraryFile =!= $Failed,
  nec2LinkRun = LibraryFunctionLoad[$LibraryFile, "run_nec2", {String, String}, Integer]
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

End[] (* `Private` *)

EndPackage[]
