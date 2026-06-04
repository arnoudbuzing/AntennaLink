# AntennaLink

`AntennaLink` is a Wolfram Language paclet that provides a direct interface to the **NEC2** (Numerical Electromagnetics Code) method of moments antenna simulator by wrapping the C translation [nec2c](https://github.com/KJ7LNW/nec2c) via Wolfram LibraryLink.

This allows you to run high-performance antenna simulations directly from your Wolfram Language sessions.

---

## Installation & Setup

### 1. Clone the Repository
Since `nec2c` is included as a Git submodule, clone this repository recursively:
```bash
git clone --recursive https://github.com/arnoudbuzing/AntennaLink.git
cd AntennaLink
```
If you already cloned it without submodules, initialize them:
```bash
git submodule update --init --recursive
```

### 2. Compile the C Library
Use the built-in compiler toolchain in Wolfram Language to compile the LibraryLink module. You can run the provided build script:

```bash
/Applications/Wolfram/15.0/Wolfram.app/Contents/MacOS/wolfram -script scripts/build.wl
```
This compiles the C files under `src/nec2c/` along with the custom LibraryLink wrapper in `src/nec2link.c` and outputs a shared library (`libnec2link.dylib`) directly to the paclet's `LibraryResources/$SystemID/` directory.

---

## Usage

Load the paclet in your Wolfram session:

```wolfram
(* Load from the local directory *)
PacletDirectoryLoad["/path/to/AntennaLink/AntennaLink"];
Needs["ArnoudBuzing`AntennaLink`"];
```

### Memory-Based Interface (Preferred)

`AntennaSolveMemory` runs the NEC-2 solver directly in-memory, bypassing file I/O operations. It accepts structured data representing the geometry, frequency, and excitations, and returns computed values in a structured `Association`.

#### Syntax
```wolfram
AntennaSolveMemory[wires, freq, excitations]
```

* **`wires`**: A list of associations defining the wire segments. Each wire has:
  * `"Segments"` (Integer): Number of segments.
  * `"Tag"` (Integer): Geometry tag number.
  * `"P1"` (List of 3 Reals): Start coordinates `{x, y, z}`.
  * `"P2"` (List of 3 Reals): End coordinates `{x, y, z}`.
  * `"Radius"` (Real): Radius of the wire.
* **`freq`** (Real): Operating frequency in MHz.
* **`excitations`**: A list of associations defining voltage/current sources. Each excitation has:
  * `"Tag"` (Integer): Tag number of the wire.
  * `"Segment"` (Integer): Segment number where the excitation is applied.
  * `"Voltage"` (Complex/Real): Excitation voltage (e.g., `1.0 + 0.0 * I`).

#### Example: In-Memory Dipole Simulation
```wolfram
(* Define a simple dipole antenna *)
wires = {
  <|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
};

(* Set frequency (MHz) *)
freq = 299.79;

(* Add excitation to the center segment (segment 6 of 11) *)
excitations = {
  <|"Tag" -> 1, "Segment" -> 6, "Voltage" -> 1.0 + 0.0 * I|>
};

(* Run the solver directly in memory *)
results = AntennaSolveMemory[wires, freq, excitations];

(* Query the computed currents Dataset *)
results["Currents"]
```

---

### 2. File-Based Interface (Alternative)

This interface executes the legacy file-based workflow of NEC-2.

#### `AntennaSolve`
`AntennaSolve[inputFile, outputFile]` runs the NEC-2 solver on the input `.nec` file and writes the simulation output to `outputFile` (typically `.out`).

```wolfram
(* Define temporary file paths *)
necFile = FileNameJoin[{$TemporaryDirectory, "dipole.nec"}];
outFile = FileNameJoin[{$TemporaryDirectory, "dipole.out"}];

(* Write a standard NEC-2 input file for a simple dipole *)
Export[necFile, "CM Simple Dipole
CE
GW 1 11 0 0 -0.25 0 0 0.25 0.001
GE 0
EX 0 1 6 0 1.0 0.0
FR 0 1 0 0 299.79 0
XQ
EN
", "String"];

(* Run the solver *)
AntennaSolve[necFile, outFile]
```

#### `AntennaParseOutput`
`AntennaParseOutput[outputFile]` parses the standard `.out` file produced by `AntennaSolve` into a Wolfram Language `Association` containing structured `Dataset`s for easy querying and visualization.

```wolfram
(* Parse results *)
results = AntennaParseOutput[outFile];

(* View the currents dataset *)
results["Currents"]

(* View the input parameters/impedance dataset *)
results["InputParameters"]
```

---

## Visualization Examples

Once you have the `results` (either from memory or file), you can extract the values to create 2D and 3D plots using standard Wolfram Language visualization functions.

### 2D Plot: Current Distribution

Using the memory-based solver, we can plot the magnitude of the currents across the segments:

```wolfram
(* Calculate current magnitudes from Real and Imaginary parts *)
magnitudes = Normal[results["Currents"][All, Sqrt[#CurrentReal^2 + #CurrentImag^2] &]];

(* Plot the 2D current distribution along the wire *)
ListLinePlot[magnitudes, 
  PlotTheme -> "Detailed", 
  FrameLabel -> {"Segment Number", "Current Magnitude (A)"},
  PlotLabel -> "Dipole Current Distribution"
]
```

### 3D Plot: Spatial Current Distribution

The `Currents` dataset now includes the 3D spatial coordinates (`X`, `Y`, `Z`) for both the memory-based and file-based interfaces. This makes it easy to create 3D visualizations.

For the **memory-based interface**, you can compute the magnitude and map it to the coordinates:

```wolfram
(* Extract {X, Y, Z} coordinates and compute Current Magnitude *)
data3D = Normal[results["Currents"][All, {#X, #Y, #Z} -> Sqrt[#CurrentReal^2 + #CurrentImag^2] &]];

(* Create a 3D plot where point color represents the current magnitude *)
ListPointPlot3D[data3D, 
  ColorFunction -> "Rainbow", 
  PlotStyle -> PointSize[0.05],
  AxesLabel -> {"X", "Y", "Z"},
  BoxRatios -> {1, 1, 3},
  PlotLabel -> "3D Current Distribution"
]
```

*(Note: If using the **file-based interface**, `#Magnitude` is already pre-computed, so you can simply use `{#X, #Y, #Z} -> #Magnitude &`)*

### 3D Plot: Radiation Pattern

If you use the file-based interface and configure an `RP` (Radiation Pattern) card in your `.nec` file, `AntennaParseOutput` will extract the `RADIATION PATTERNS` block into a Dataset as well!

Here is how you can parse it and render a stunning 3D radiation lobe:

```wolfram
(* Assuming you have run AntennaSolve on a .nec file that includes an RP card *)
(* outFile = FileNameJoin[{$TemporaryDirectory, "dipole.out"}]; *)

(* Parse results from the simulation *)
results = AntennaParseOutput[outFile];
rp = results["RadiationPattern"];

(* Filter out placeholder values (NEC uses -999.99 for undefined gains) *)
(* And shift the gain to be positive for the radius (e.g., if max gain is 2.17, add offset) *)
minGain = Min[Normal[rp[All, #TotalGain &]]];
offset = Abs[minGain] + 1; 

(* Convert Spherical (Theta, Phi) and Gain (Radius) to Cartesian {X, Y, Z} *)
(* Note: NEC-2 Theta is often elevation from the XY plane depending on RP card config *)
points3D = Normal[rp[All, 
  With[{r = #TotalGain + offset, th = #Theta * Degree, ph = #Phi * Degree},
    {
      r * Cos[th] * Cos[ph],
      r * Cos[th] * Sin[ph],
      r * Sin[th]
    }
  ] &
]];

(* Create a 3D Point Plot colored by Z-height (or Gain) *)
ListPointPlot3D[points3D,
  ColorFunction -> "Rainbow",
  PlotStyle -> PointSize[0.02],
  BoxRatios -> {1, 1, 1},
  AxesLabel -> {"X", "Y", "Z"},
  PlotLabel -> "3D Radiation Pattern"
]
```

---

## Running Tests

Run the test suite using:
```bash
/Applications/Wolfram/15.0/Wolfram.app/Contents/MacOS/wolfram -script scripts/test.wl
```

