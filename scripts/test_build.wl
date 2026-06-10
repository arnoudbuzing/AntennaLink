PacletDirectoryLoad[Directory[]];
Needs["CCompilerDriver`"];
files = {"src/nec2link.c", "src/nec2c/misc.c", "src/nec2c/nec2c.c", "src/nec2c/somnec.c", "src/nec2c/math.c", "src/nec2c/geometry.c", "src/nec2c/radiation.c", "src/nec2c/calculations.c"};
opts = {"CleanIntermediate" -> True, "SystemCompileOptions" -> "-fPIC -D_GNU_SOURCE"};
lib = CreateLibrary[files, "libnec2link", opts];
If[lib === $Failed, Print[Import[CCompilerDriver`Private`$CCompilerOutputFile, "Text"]]];
