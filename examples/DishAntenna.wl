(* ::Package:: *)

(* ==========================================================================
   AntennaLink example: front-fed parabolic dish antenna
   --------------------------------------------------------------------------
   Builds a wire-grid parabolic reflector with a half-wave dipole feed placed
   at the focal point, then demonstrates the three visualization / solver
   functions end to end:

     1. AntennaPlotGeometry     - render the physical wire structure
     2. AntennaFarFieldMemory   - solve currents and compute the far field
     3. AntennaPlotPattern3D    - render the 3D radiation pattern over geometry

   Run from the repository root with:

     wolfram -script examples/DishAntenna.wl

   The script writes three PNG images next to this file:
     DishAntenna-geometry.png, DishAntenna-currents.png, DishAntenna-pattern.png
   ========================================================================== *)

(* --- Load the paclet -------------------------------------------------------*)
PacletDirectoryLoad[FileNameJoin[{DirectoryName[$InputFileName, 2], "AntennaLink"}]];
Needs["ArnoudBuzing`AntennaLink`"];

exampleDir = DirectoryName[$InputFileName];

(* --- Design parameters -----------------------------------------------------*)
(* Operating frequency. lambda = c / f = 299.8 / 300 ~= 1.0 m, so all lengths
   below are essentially in wavelengths. *)
frequencyMHz = 300.0;
lambda       = 299.8 / frequencyMHz;

(* Parabolic reflector geometry (vertex at the origin, opening toward +Z). *)
focalLength = 0.40;   (* meters; focus sits at (0, 0, focalLength)            *)
dishRadius  = 0.75;   (* aperture radius -> 1.5 lambda diameter               *)
numRibs     = 12;     (* radial ribs                                          *)
numRings    = 6;      (* concentric rings                                     *)
wireRadius  = 0.002;  (* meters                                               *)

(* --- Build the reflector wire grid ----------------------------------------*)
(* AntennaParabolicReflector also accepts positional arguments; the
   association form is used here for readability. *)
dishWires = AntennaParabolicReflector[<|
  "FocalLength" -> focalLength,
  "DishRadius"  -> dishRadius,
  "NumRibs"     -> numRibs,
  "NumRings"    -> numRings,
  "WireRadius"  -> wireRadius
|>];

(* --- Add a half-wave dipole feed at the focal point ------------------------*)
(* The dipole lies along X, centered on the focus. Each reflector wire has a
   unique tag, so the feed takes a tag just above the highest dish tag to keep
   it distinct and drivable on its own. *)
feedHalfLength = 0.25 * lambda;        (* quarter wavelength per arm           *)
feedTag        = Max[Lookup[dishWires, "Tag"]] + 1;
feedSegments   = 11;
feedCenterSeg  = Ceiling[feedSegments / 2];   (* 6 -> center segment           *)

feedWire = <|
  "Segments" -> feedSegments,
  "Tag"      -> feedTag,
  "P1"       -> {-feedHalfLength, 0.0, focalLength},
  "P2"       -> { feedHalfLength, 0.0, focalLength},
  "Radius"   -> wireRadius
|>;

antennaWires = Join[dishWires, {feedWire}];

excitations = {
  <|"Tag" -> feedTag, "Segment" -> feedCenterSeg, "Voltage" -> 1.0 + 0.0 I|>
};

Print["Dish wires: ", Length[dishWires],
      "  | total wires (incl. feed): ", Length[antennaWires]];

(* --- 1. Plot the bare geometry --------------------------------------------*)
geometryPlot = AntennaPlotGeometry[antennaWires, "HighlightExcitations" -> True];
Export[FileNameJoin[{exampleDir, "DishAntenna-geometry.png"}], geometryPlot,
  ImageResolution -> 100];
Print["Wrote DishAntenna-geometry.png"];

(* --- 2. Solve currents and compute the far field --------------------------*)
thetaList = Range[0.0, 180.0, 5.0];    (* polar angle from +Z                 *)
phiList   = Range[0.0, 360.0, 10.0];   (* azimuth                             *)

result = AntennaFarFieldMemory[
  antennaWires, frequencyMHz, excitations, thetaList, phiList
];

If[result === $Failed,
  Print["AntennaFarFieldMemory failed."];
  Exit[1]
];

(* Report the peak gain and the direction it points. *)
ffData    = Normal[result["FarField"]];
maxRow    = MaximalBy[ffData, #["GainDB"] &][[1]];
Print["Peak gain: ", Round[maxRow["GainDB"], 0.01], " dBi",
      "  at theta = ", maxRow["Theta"], " deg, phi = ", maxRow["Phi"], " deg"];

(* Geometry colored by the solved current magnitude. *)
currentsPlot = AntennaPlotGeometry[result, "ColorFunction" -> "Magnitude"];
Export[FileNameJoin[{exampleDir, "DishAntenna-currents.png"}], currentsPlot,
  ImageResolution -> 100];
Print["Wrote DishAntenna-currents.png"];

(* --- 3. Plot the 3D radiation pattern with geometry overlay ---------------*)
patternPlot = AntennaPlotPattern3D[
  result,
  "PlotType"     -> "dB",
  "DynamicRange" -> 30.0,
  "ShowGeometry" -> True
];
Export[FileNameJoin[{exampleDir, "DishAntenna-pattern.png"}], patternPlot,
  ImageResolution -> 100];
Print["Wrote DishAntenna-pattern.png"];

Print["Done."];
