format[outcome_String] := Switch[
  outcome,
  "Success", "\:2705",
  "Failure", "\:274c",
  _, "\:26a0"
  ];

(* Locate the tests directory relative to this script, independent of the
   current working directory and of how the kernel was launched. *)
testsDir = FileNameJoin[{ParentDirectory[DirectoryName[ExpandFileName[$InputFileName]]], "tests"}];

(* Optional: run a specific file by passing a .wlt path as a script argument.
   Check both arg lists so it works under `wolframscript -file` ($ScriptCommandLine)
   and `wolfram -script` ($CommandLine). *)
explicit = Select[
  Join[
    If[ListQ[$ScriptCommandLine], $ScriptCommandLine, {}],
    If[ListQ[$CommandLine], $CommandLine, {}]
  ],
  StringEndsQ[#, ".wlt"] &
];

files = If[explicit =!= {}, explicit, FileNames["*.wlt", testsDir, Infinity]];

If[files === {},
  Print["No .wlt test files found in ", testsDir];
  Exit[1]
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
