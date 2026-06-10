# AntennaLink Roadmap & Feature Plan

This document outlines the proposed roadmap and feature plan for the **AntennaLink** Wolfram Language paclet.

## 1. In-Memory Far-Field / Radiation Pattern Solver (`AntennaFarFieldMemory`)
* **Goal**: Provide an in-memory solver function that computes far-field radiation patterns ($E_\theta, E_\phi$ fields and gains) without writing/reading temporary files.
* **API**:
  ```wolfram
  AntennaFarFieldMemory[wires, freq, excitations, thetaRange, phiRange]
  ```
  Returns a `Dataset` containing:
  - `Theta`, `Phi` (in radians or degrees)
  - `ETheta`, `EPhi` (as complex numbers)
  - `Gain` (linear absolute power gain)
  - `GainDB` (gain in decibels)

## 2. Geometry Builders in Wolfram Language
* **Goal**: High-level constructive helper functions to construct complex antenna structures without manual segment/wire coordinates calculations.
* **API**:
  - `AntennaYagiUda[...]`
  - `AntennaHelix[...]`
  - `AntennaParabolicReflector[...]`

## 3. Impedance Sweeps & S-Parameters (`AntennaSweepMemory`)
* **Goal**: Sweep frequency across a given range to compute resonant characteristics, return loss, and S-parameters.
* **API**:
  - `AntennaSweepMemory[wires, {freqMin, freqMax, freqStep}, excitations]`
  - Computes: Frequency, Input Impedance ($R + jX$), $S_{11}$ (dB), and VSWR.

## 4. Ground Planes in Memory
* **Goal**: Extend the in-memory interface to support ground cards (perfect or realistic finite ground plane parameters).
* **API**:
  - `AntennaSolveMemory[wires, freq, excitations, "Ground" -> <|...|>]`

## 5. Interactive 3D Visualizations
* **Goal**: Seamless, out-of-the-box visualizations:
  - `AntennaPlotGeometry[wires]` (color-coded by current magnitude/phase).
  - `AntennaPlotPattern3D[farFieldData]` (radiation lobes overlaid on geometry).
