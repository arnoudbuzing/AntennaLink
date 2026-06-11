# AntennaLink

[![CI](https://github.com/arnoudbuzing/AntennaLink/actions/workflows/ci.yml/badge.svg)](https://github.com/arnoudbuzing/AntennaLink/actions/workflows/ci.yml)

`AntennaLink` is a high-performance Wolfram Language paclet that provides a direct, in-memory interface to the **NEC-2** (Numerical Electromagnetics Code) method of moments antenna simulator. It wraps the C translation [nec2c](https://github.com/KJ7LNW/nec2c) via Wolfram LibraryLink, bypassing slow and fragile temporary file I/O operations.

With `AntennaLink`, you can perform electromagnetic geometry generation, parameter sweeps, ground-plane modeling, and interactive 3D visualizations directly from your Wolfram Language session.

---

## Installation & Setup

### 1. Clone the Repository
Clone recursively to fetch the nested `nec2c` C engine dependency:
```bash
git clone --recursive https://github.com/arnoudbuzing/AntennaLink.git
cd AntennaLink
```

### 2. Compile the Library Link Binary
Run the build script using the preferred Wolfram Language kernel to compile the shared library:
```bash
/Applications/Wolfram/15.0/Wolfram.app/Contents/MacOS/wolfram -script scripts/build.wl
```
This generates the compiled LibraryLink shared module (`libnec2link.dylib`) under `AntennaLink/LibraryResources/$SystemID/`.

---

## Usage Overview

Load the paclet inside your Wolfram session:
```wolfram
(* Load locally from source root directory *)
PacletDirectoryLoad["/path/to/AntennaLink/AntennaLink"];
Needs["ArnoudBuzing`AntennaLink`"];
```

---

## 1. In-Memory Solvers

### `AntennaSolveMemory`
Computes segment-level currents directly in memory, and reports the input
impedance at each feed.

```wolfram
(* Define a simple half-wave dipole *)
wires = {
  <|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
};
excitations = {
  <|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0 + 0.0 * I|>
};

(* Solve in memory at 299.79 MHz *)
results = AntennaSolveMemory[wires, 299.79, excitations];

(* View the currents dataset *)
results["Currents"]

(* Input impedance (and drive voltage/current/power) at each excited segment *)
results["InputParameters"]
(* e.g. ZInput -> 83.66 + 47.09 I ohms for this dipole *)
```

### Ground Planes Support
All in-memory solver functions accept a `"Ground"` option to model perfect, finite realistic, or Sommerfeld ground environments:

```wolfram
(* Quarter-wave monopole on Sommerfeld ground *)
monopole = {
  <|"Segments" -> 5, "Tag" -> 1, "P1" -> {0, 0, 0}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
};
baseFeed = {
  <|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>
};

(* Solve over lossy earth using Sommerfeld method *)
solSommerfeld = AntennaSolveMemory[
  monopole, 
  299.79, 
  baseFeed,
  "Ground" -> <|
    "Type" -> "Sommerfeld", 
    "Dielectric" -> 15.0, 
    "Conductivity" -> 0.01,
    "ConnectWires" -> True
  |>
];
```

Supported ground parameters in the `"Ground"` Association:
- `"Type"`: `"Perfect"`, `"Realistic"`, or `"Sommerfeld"`.
- `"Dielectric"` (Real): Relative dielectric constant $\epsilon_r$ (default `1.0`).
- `"Conductivity"` (Real): Soil conductivity $\sigma$ in S/m (default `0.0`).
- `"Radials"` (Integer): Number of wires in a radial ground screen.
- `"RadialLength"`, `"RadialRadius"` (Reals): Ground screen radial geometry parameters.
- `"ConnectWires"` (`True`/`False`): Specifies if wires touching the $Z=0$ ground plane connect to it.

### Lumped Loads

All in-memory solvers accept a `"Loads"` option — a list of Associations that
place lumped R/L/C or impedance loading on segments (NEC's `LD` card), e.g. a
center-loading coil, a trap, or a resistive load:

```wolfram
(* A 50 nH loading coil at the center of a dipole *)
AntennaSolveMemory[wires, 299.79, excitations,
  "Loads" -> {<|
    "Type" -> "Series",        (* series R-L-C *)
    "Tag" -> 1, "SegmentFrom" -> 6, "SegmentTo" -> 6,
    "Inductance" -> 50.*^-9
  |>}
]
```

Each load Association supports:
- `"Type"`: `"Series"` or `"Parallel"` (R-L-C), `"SeriesPerMeter"` / `"ParallelPerMeter"`, `"Impedance"` (fixed $R + jX$), or `"Conductivity"` (S/m).
- `"Tag"`, `"SegmentFrom"`, `"SegmentTo"`: which segments to load (tag with a relative segment range; default loads all segments of the tag).
- `"Resistance"`, `"Inductance"`, `"Capacitance"` (for R-L-C types); `"Resistance"` + `"Reactance"` (for `"Impedance"`); `"Conductivity"` (for `"Conductivity"`).

The load impedance is recomputed at each frequency, so loads work in sweeps too.

---

## 2. Geometry Builders

Generate complex structured wire layouts automatically without calculating coordinates manually.

### Yagi-Uda Antennas (`AntennaYagiUda`)
Can be specified either with positional arguments or as an Association containing the key-value parameters:

```wolfram
(* 5-element Yagi-Uda antenna using positional arguments *)
yagiWires = AntennaYagiUda[
  0.50,                (* Reflector length *)
  0.15,                (* Reflector spacing *)
  0.47,                (* Driven element length *)
  {0.44, 0.43, 0.42},  (* Director lengths *)
  {0.15, 0.20, 0.20},  (* Spacings *)
  0.002,               (* Wire radius *)
  11                   (* Segments per element *)
];

(* Alternatively, using an Association *)
yagiWires = AntennaYagiUda[<|
  "ReflectorLength" -> 0.50,
  "ReflectorSpacing" -> 0.15,
  "DrivenLength" -> 0.47,
  "DirectorLengths" -> {0.44, 0.43, 0.42},
  "DirectorSpacings" -> {0.15, 0.20, 0.20},
  "WireRadius" -> 0.002,
  "Segments" -> 11
|>];
```

### Helical Antennas (`AntennaHelix`)
Can be specified either with positional arguments or as an Association:

```wolfram
(* Helix aligned along the Z-axis using positional arguments *)
helixWires = AntennaHelix[
  0.08,  (* Coil radius *)
  0.10,  (* Turn pitch *)
  5.0,   (* Number of turns *)
  0.001, (* Wire radius *)
  16     (* Segments per turn *)
];

(* Alternatively, using an Association *)
helixWires = AntennaHelix[<|
  "Radius" -> 0.08,
  "Pitch" -> 0.10,
  "Turns" -> 5.0,
  "WireRadius" -> 0.001,
  "SegmentsPerTurn" -> 16
|>];
```

### Parabolic Grid Reflectors (`AntennaParabolicReflector`)
Can be specified either with positional arguments or as an Association:

```wolfram
(* Parabolic wire mesh vertexed at the origin using positional arguments *)
reflectorWires = AntennaParabolicReflector[
  0.3,   (* Focal length *)
  0.6,   (* Outer dish radius *)
  8,     (* Radial ribs *)
  4,     (* concentric rings *)
  0.001  (* Wire radius *)
];

(* Alternatively, using an Association *)
reflectorWires = AntennaParabolicReflector[<|
  "FocalLength" -> 0.3,
  "DishRadius" -> 0.6,
  "NumRibs" -> 8,
  "NumRings" -> 4,
  "WireRadius" -> 0.001
|>];
```

---

## 3. Impedance & S-Parameter Sweeps

### `AntennaSweepMemory`
Sweeps frequency across a range to compute input impedance, reflection coefficient $S_{11}$, and VSWR in-memory.

```wolfram
wires = {
  <|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
};
excitations = {
  <|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0|>
};

(* Sweep from 280 to 320 MHz in steps of 2 MHz with a 50 ohm reference impedance *)
sweepResults = AntennaSweepMemory[
  wires, 
  Range[280.0, 320.0, 2.0], 
  excitations,
  "ReferenceImpedance" -> 50.0
];

(* Plot return loss S11 *)
ListLinePlot[
  Normal[sweepResults[All, {#Frequency, #S11} &]],
  PlotRange -> All,
  FrameLabel -> {"Frequency (MHz)", "S11 (dB)"},
  PlotTheme -> "Detailed"
]
```

---

## 4. Far-Field Patterns

### `AntennaFarFieldMemory`
Computes radiation pattern gains ($E_\theta, E_\phi$ fields and Linear/dB gain values).

```wolfram
(* 1-wavelength loop far field grid *)
loop = AntennaHelix[0.16, 0.0, 1.0, 0.001, 24];
feed = {<|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>};

(* Run theta and phi grid *)
ffData = AntennaFarFieldMemory[
  loop, 
  300.0, 
  feed, 
  Range[0.0, 180.0, 5.0], (* Theta angles *)
  Range[0.0, 360.0, 10.0] (* Phi angles *)
];
```

---

## 5. Interactive 3D Visualizations

Stunning, native 3D visualizations built using hardware-accelerated graphics.

### Geometry & Current Visualizer (`AntennaPlotGeometry`)
Plots physical wires as cylinders with optional color gradients representing segment current magnitude or phase.

```wolfram
(* Solve helical antenna *)
sol = AntennaSolveMemory[helixWires, 300.0, {<|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>}];

(* Render colored by current magnitude with excitation bases highlighted *)
AntennaPlotGeometry[sol]

(* Render colored by current phase *)
AntennaPlotGeometry[sol, "ColorFunction" -> "Phase"]
```

### 3D Radiation Pattern Visualizer (`AntennaPlotPattern3D`)
Renders a smooth 3D polygon surface of the radiation pattern. Automatically scales and overlays the physical antenna geometry at the center.

```wolfram
(* Compute far field pattern *)
ff = AntennaFarFieldMemory[
  yagiWires, 
  300.0, 
  {<|"Tag" -> 2, "Segment" -> 6, "Voltage" -> 1.0|>}, 
  Range[0.0, 180.0, 5.0], 
  Range[0.0, 360.0, 10.0]
];

(* Plot radiation pattern lobes in dB overlaying the Yagi Uda geometry *)
AntennaPlotPattern3D[ff, "ShowGeometry" -> True]
```

### 2D Pattern Cuts (`AntennaPlotPattern2D`)
Polar plot of a single principal-plane cut through the pattern — the everyday
antenna-engineering view.

```wolfram
(* Elevation cut (a vertical, phi = const plane); default phi = 0 *)
AntennaPlotPattern2D[ff, "Plane" -> "Elevation", "DynamicRange" -> 30.0]

(* Azimuth cut (a horizontal, theta = const plane); default theta = 90 deg *)
AntennaPlotPattern2D[ff, "Plane" -> "Azimuth", "Angle" -> 90.0]
```

Options: `"Plane"` (`"Elevation"` | `"Azimuth"`), `"Angle"` (fixed angle in
degrees, `Automatic` by default), `"PlotType"` (`"dB"` | `"Linear"`), and
`"DynamicRange"` (dB span from the peak, default `40`). Accepts either a solved
result or a far-field dataset.

---

## Running the Unit Tests

Execute the systematic test suite inside a shell:
```bash
/Applications/Wolfram/15.0/Wolfram.app/Contents/MacOS/wolfram -script scripts/test.wl
```
The runner prints a per-test pass/fail summary and exits with a non-zero status
if any test fails, so it can be used directly in scripts and CI.

## Continuous Integration

Every push and pull request to `main` builds `libnec2link` and runs the full
test suite on GitHub Actions (see [`.github/workflows/ci.yml`](.github/workflows/ci.yml)),
using the free [Wolfram Engine](https://www.wolfram.com/engine/) Docker image.

CI requires a one-time setup: create a free Wolfram Engine on-demand entitlement
and add its ID as a repository secret named `WOLFRAMSCRIPT_ENTITLEMENTID` under
**Settings → Secrets and variables → Actions**.
