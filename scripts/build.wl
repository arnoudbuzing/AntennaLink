(* ::Script:: *)

Needs["CCompilerDriver`"]

srcDir = FileNameJoin[{DirectoryName[$InputFileName, 2], "src"}];
nec2cDir = FileNameJoin[{srcDir, "nec2c"}];

cFiles = Join[
  {FileNameJoin[{srcDir, "nec2link.c"}]},
  Select[FileNames["*.c", nec2cDir], StringFreeQ[#, "main.c"] && StringFreeQ[#, "nec2c.c"] &]
];

libDir = FileNameJoin[{DirectoryName[$InputFileName, 2], "AntennaLink", "LibraryResources", $SystemID}];
If[!DirectoryQ[libDir], CreateDirectory[libDir]];

Print["Building libnec2link..."];

lib = CreateLibrary[cFiles, "libnec2link",
  "TargetDirectory" -> libDir,
  "IncludeDirectories" -> {nec2cDir},
  "Defines" -> {
    "exit" -> "nec2c_exit",
    "version" -> "\"1.3\"",
    "PACKAGE_STRING" -> "\"nec2c 1.3\""
  },
  "CompileOptions" -> {"-w", "-O2"} (* suppress warnings from legacy C code *)
];

If[lib === $Failed,
  Print["Build failed!"];
  Exit[1]
];

Print["Build successful: ", lib];
