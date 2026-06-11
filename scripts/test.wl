format[outcome_String] := Switch[
  outcome,
  "Success", "\:2705",
  "Failure", "\:274c",
  _, "\:26a0"
  ];

files = If[ 
  Length[$CommandLine]>3, 
  { Last[$CommandLine] }, (* to run a specific file *)
  FileNames["*.wlt", "tests",Infinity]
];

report = TestReport[
  files,
  HandlerFunctions -> <|
    "ReportStarted" -> Function[report, Print["Starting test report: " <> report["EventID"]]],
    "ReportCompleted" -> Function[report, Print["Test report completed: " <> report["EventID"]]],
    "FileStarted" -> Function[testFile, Print["Starting test file: " <> testFile["TestFileName"]]],
    "FileCompleted" -> Function[testFile, Print["Test file completed: " <> testFile["EventID"]]],
    "TestEvaluated" -> Function[test, Module[{obj},
    obj = test["TestObject"];
    Print["["<>format[obj["Outcome"]]<> "] " <> obj["TestID"]];
    ]]
    |>];

Print["Passed: ", report["TestsSucceededCount"],
      "  Failed: ", report["TestsFailedCount"]];

(* Exit non-zero on any failure so CI (and shell callers) can detect it. *)
If[TrueQ[report["AllTestsSucceeded"]],
  Print["ALL TESTS PASSED"],
  Print["TEST FAILURES DETECTED"];
  Exit[1]
];
