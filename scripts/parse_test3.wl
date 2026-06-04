text = Import[FileNameJoin[{DirectoryName[$InputFileName, 2], "tests", "dipole.out"}], "String"];

inputParamsStr = First[StringCases[text, "--------- ANTENNA INPUT PARAMETERS ---------" ~~ Shortest[x___] ~~ "\n\n" :> x], ""];
Print["Input: ", StringLength[inputParamsStr]];

currentsStr = First[StringCases[text, "-------- CURRENTS AND LOCATION --------" ~~ Shortest[x___] ~~ "\n\n" :> x], ""];
Print["Currents: ", StringLength[currentsStr]];
