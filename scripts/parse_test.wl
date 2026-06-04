text = Import[FileNameJoin[{DirectoryName[$InputFileName, 2], "tests", "dipole.out"}], "String"];

inputParamsStr = StringCases[text, "--------- ANTENNA INPUT PARAMETERS ---------" ~~ x___ ~~ "--------" :> x];
Print[inputParamsStr];

currentsStr = StringCases[text, "-------- CURRENTS AND LOCATION --------" ~~ x___ ~~ "---------- POWER BUDGET ---------" :> x];
Print[currentsStr];
