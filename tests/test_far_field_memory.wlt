VerificationTest[
  PacletDirectoryLoad[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink"}]];
  Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "AntennaLink", "Kernel", "AntennaLink.wl"}]];
  NameQ["ArnoudBuzing`AntennaLink`AntennaFarFieldMemory"],
  True,
  TestID -> "far-field-memory-context-load"
]

VerificationTest[
  Module[{res, wires, freq, excitations, thetaList, phiList},
    wires = {
      <|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
    };
    freq = 299.79;
    excitations = {
      <|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0 + 0.0 * I|>
    };
    
    thetaList = {-90.0, -45.0, 0.0, 45.0, 90.0};
    phiList = {0.0, 90.0, 180.0, 270.0, 360.0};
    
    res = AntennaFarFieldMemory[wires, freq, excitations, thetaList, phiList];
    
    AssociationQ[res] && 
      Head[res["Currents"]] === Dataset && 
      Head[res["FarField"]] === Dataset && 
      Length[res["Currents"]] == 11 && 
      Length[res["FarField"]] == 25
  ],
  True,
  TestID -> "far-field-memory-returns-correct-dataset-sizes"
]

VerificationTest[
  Module[{resMem, resFile, wires, freq, excitations, thetaVal, phiVal, ffMem, ffFile, gainMem, gainFile},
    wires = {
      <|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
    };
    freq = 299.79;
    excitations = {
      <|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0 + 0.0 * I|>
    };
    
    thetaVal = 90.0;
    phiVal = 0.0;
    
    (* In-memory solver *)
    resMem = AntennaFarFieldMemory[wires, freq, excitations, {thetaVal}, {phiVal}];
    gainMem = Normal[resMem["FarField"]][[1, "GainDB"]];
    
    (* File-based parsed output from dipole_rp.out *)
    resFile = AntennaParseOutput[FileNameJoin[{DirectoryName[$TestFileName], "dipole_rp.out"}]];
    
    (* Filter for matching angles *)
    ffFile = Select[Normal[resFile["RadiationPattern"]], #Theta == thetaVal && #Phi == phiVal &];
    gainFile = If[Length[ffFile] > 0, ffFile[[1]]["TotalGain"], Missing["NotFound"]];
    
    (* Compare gains (tolerance within 0.05 dB due to minor interpolation/power differences) *)
    If[gainFile =!= Missing["NotFound"],
      Abs[gainMem - gainFile] < 0.05,
      False
    ]
  ],
  True,
  TestID -> "far-field-memory-gain-matches-file-based"
]
