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

(* A syntax error in a .wlt file makes TestReport emit TestReport::rnterr and
   silently skip that file, which would otherwise pass vacuously. Trap it. *)
Check[
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
      |>],
  report = $Failed,
  {TestReport::rnterr}
];

If[report === $Failed,
  Print["A test file could not be read (syntax error); aborting."];
  Exit[1]
];

Print["Passed: ", report["TestsSucceededCount"],
      "  Failed: ", report["TestsFailedCount"]];

(* Exit non-zero on any failure (or if nothing actually ran) so CI and shell
   callers can detect it. *)
Which[
  report["TestsSucceededCount"] + report["TestsFailedCount"] == 0,
    Print["NO TESTS RAN"]; Exit[1],
  ! TrueQ[report["AllTestsSucceeded"]],
    Print["TEST FAILURES DETECTED"]; Exit[1],
  True,
    Print["ALL TESTS PASSED"]
];
