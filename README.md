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

### `AntennaSolve`
`AntennaSolve[inputFile, outputFile]` runs the NEC2 solver on the input `.nec` file and writes the simulation output to `outputFile` (typically `.out`).

#### Example: Dipole Antenna Simulation

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

(* Print the results *)
FilePrint[outFile]
```

---

## Running Tests

Run the test suite using:
```bash
/Applications/Wolfram/15.0/Wolfram.app/Contents/MacOS/wolfram -script scripts/test.wl
```
