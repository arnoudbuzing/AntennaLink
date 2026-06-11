# Understanding Antennas from First Principles

### A hands-on tutorial using AntennaLink

This tutorial is for an electrical-engineering student who is just starting to
study antennas. Instead of starting from pages of vector calculus, we will
*build* antennas in the Wolfram Language with [AntennaLink](README.md), look at
what they do, and let the simulations teach us the physics. Every box of code
runs — try changing the numbers and see what happens.

> **What you need.** A Wolfram Language kernel with AntennaLink built (see the
> [README](README.md)). Start every session with:
>
> ```wolfram
> PacletDirectoryLoad["/path/to/AntennaLink/AntennaLink"];
> Needs["ArnoudBuzing`AntennaLink`"];
> ```

---

## 1. What *is* an antenna?

A transmitter produces an oscillating current in a wire. A fundamental result
of electromagnetism is that **accelerating charge radiates** — when you push
charge back and forth along a conductor, some of the energy escapes as an
electromagnetic wave that travels outward at the speed of light. An antenna is
just a conductor shaped so that this happens *efficiently and in a useful
direction*. A receiving antenna runs the process in reverse: a passing wave
pushes charge in the wire, producing a current we can amplify.

So the whole game is: **what current flows on the conductor, and what wave does
that current produce?** That is exactly what AntennaLink computes. Internally it
uses the **Method of Moments** (via the NEC-2 engine): it chops each wire into
short straight **segments**, assumes the current is simple on each segment, and
solves a system of equations so that Maxwell's boundary conditions are satisfied
everywhere. You describe the metal; it finds the current and the radiated field.

A wire in AntennaLink is an `Association`:

```wolfram
<|"Segments" -> 21, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>
```

`P1`/`P2` are the endpoints in meters, `Segments` is how finely it is chopped,
`Tag` is a label so we can refer to it, and `Radius` is the wire thickness. More
segments means a more accurate current — a good rule of thumb is at least ~10
segments per wavelength of wire.

---

## 2. Wavelength: the ruler for everything

Antennas have almost no absolute size — what matters is size **relative to the
wavelength** of the wave. The wavelength is

$$\lambda = \frac{c}{f}, \qquad c \approx 3\times10^8\ \text{m/s}.$$

```wolfram
(* wavelength in meters for a frequency in MHz: c = 299.792458 m/us *)
lambda[fMHz_] := 299.792458 / fMHz
lambda[300.0]                (* -> 0.9993 m, i.e. ~1 m at 300 MHz *)
```

We will work at **300 MHz** throughout, because there $\lambda \approx 1$ m and
the arithmetic is easy: a "half-wave" length is 0.5 m, a "quarter-wave" is
0.25 m, and so on. Everything you learn scales to any frequency — a Wi-Fi
antenna at 2.4 GHz ($\lambda = 12.5$ cm) obeys the same rules, just smaller.

---

## 3. The half-wave dipole — the "hydrogen atom" of antennas

The dipole is the antenna every other antenna is measured against. It is just a
straight wire, about half a wavelength long, fed in the middle. Let's build one
0.5 m long (half-wave at 300 MHz) lying along the *z*-axis:

```wolfram
dipole = {<|"Segments" -> 21, "Tag" -> 1, "P1" -> {0, 0, -0.25}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>};
feed   = {<|"Tag" -> 1, "Segment" -> 11, "Voltage" -> 1.0|>};   (* drive the center segment *)
```

The `feed` says "apply a 1-volt source across segment 11" — the middle of the
21 segments, i.e. the center of the wire.

### 3.1 What does the current look like?

Solve for the currents and color the wire by current magnitude:

```wolfram
sol = AntennaSolveMemory[dipole, 300.0, feed];
AntennaPlotGeometry[sol, "ColorFunction" -> "Magnitude"]
```

You will see the current is **largest at the center (the feed) and falls almost
to zero at the two ends**. We can check the numbers:

```wolfram
mags = Abs[#CurrentReal + I #CurrentImag] & /@ Normal[sol["Currents"]];
{First[mags], mags[[11]], Last[mags]}    (* ends are ~12% of the center value *)
```

Why this shape? The ends of the wire are open circuits — charge has nowhere to
go, so the current *must* vanish there. The feed in the middle is where we pump
charge in. The result is a **standing wave** of current, shaped like half a
cosine, peaking at the feed. This current distribution is the single most
important thing to understand about a dipole: the radiation and the impedance
both follow from it.

### 3.2 Input impedance and resonance

To drive current into the antenna, the source sees an **input impedance**
$Z_\text{in} = V/I$ at the feed. It has two parts:

$$Z_\text{in} = R + jX.$$

- **R** (resistance) represents power that *leaves* — mostly **radiation
  resistance**, the useful power turned into radio waves.
- **X** (reactance) represents energy that sloshes back and forth between the
  antenna's electric and magnetic fields without leaving — like a capacitor or
  inductor. Reactance does no radiating; it just makes the antenna harder to
  feed.

AntennaLink reports this directly:

```wolfram
Normal[sol["InputParameters"]][[1, "ZInput"]]    (* ~ 85 + j49 ohms at 300 MHz *)
```

The reactance is positive (inductive) and nonzero, which means our 0.5 m dipole
is **not resonant** at 300 MHz. An antenna is *resonant* when $X = 0$ — the
reactance cancels out and the source sees a pure resistance, which is easiest to
feed. Let's find the resonant frequency by sweeping:

```wolfram
sweep = AntennaSweepMemory[dipole, Range[260.0, 310.0, 2.0], feed];
ListLinePlot[Normal[sweep[All, {#Frequency, Im[#ZInput]} &]],
  FrameLabel -> {"Frequency (MHz)", "Reactance X (Ω)"},
  GridLines -> {None, {0}}, PlotTheme -> "Detailed"]
```

The reactance crosses zero near **284 MHz**, not 300 MHz. There the impedance is

```wolfram
res = MinimalBy[Normal[sweep], Abs[Im[#ZInput]] &][[1]];
{res["Frequency"], res["ZInput"]}    (* ~ {284., 75 - j2} *)
```

Two classic lessons fall out of this:

1. **A real dipole resonates a little short of half a wavelength** (here 0.5 m
   is resonant at 284 MHz, where $\lambda = 1.055$ m, so the dipole is about
   $0.47\lambda$, not $0.50\lambda$). End effects and wire thickness make the
   antenna look slightly longer than it is. In practice you cut a dipole to
   about 95% of $\lambda/2$.
2. **The radiation resistance of a resonant half-wave dipole is about 73 Ω** —
   we get ~75 Ω, the textbook value. This is *the* number to remember.

### 3.3 The radiation pattern

Now the payoff: where does the energy go? Compute the far field over a grid of
directions and plot it in 3D:

```wolfram
ff = AntennaFarFieldMemory[dipole, 300.0, feed, Range[0.0, 180.0, 5.0], Range[0.0, 350.0, 10.0]];
AntennaPlotPattern3D[ff, "ShowGeometry" -> True]
```

You get the famous **doughnut**: the dipole radiates strongly *broadside*
(perpendicular to the wire) and **not at all along its own axis**. A 2D slice
makes the shape obvious — it is a figure-8:

```wolfram
AntennaPlotPattern2D[ff, "Plane" -> "Elevation", "DynamicRange" -> 30.0]
```

The directions of $\theta$ are measured from the wire axis (+z). Check the
extremes:

```wolfram
gainAt[t_, p_] := SelectFirst[Normal[ff["FarField"]], #Theta == t && #Phi == p &]["GainDB"];
gainAt[0, 0]      (* along the wire: a deep null *)
gainAt[90, 0]     (* broadside: maximum *)
```

Why? Each little piece of current radiates like a tiny dipole — strongest
sideways, nothing off its ends. Add up all the pieces and the wire as a whole
inherits that behavior: maximum broadside, null end-on. **The current
distribution shaped the pattern.**

### 3.4 Directivity and gain

A pattern that favors some directions must be *weaker* in others, because total
radiated power is conserved. **Directivity** measures how much an antenna
concentrates power compared to a hypothetical *isotropic* radiator (one that
radiates equally in all directions). We quote it in **dBi** (decibels relative
to isotropic):

```wolfram
Max[Normal[ff["FarField"]][[All, "GainDB"]]]    (* ~ 2.18 dBi *)
```

A half-wave dipole has a peak gain of about **2.15 dBi** — it is 1.64× "louder"
broadside than an isotropic source would be. That is modest; the dipole is
nearly omnidirectional. To get real directivity we need to *shape* the pattern,
which is the subject of Section 6.

> `GainDB` here is the power gain in dB; `-999.99` is AntennaLink's stand-in for
> "essentially zero" (a true null, like along the dipole axis).

---

## 4. Feeding the antenna: matching and VSWR

Transmitters and coaxial cable are usually built for **50 Ω**. If the antenna's
impedance isn't 50 Ω, some power *reflects* back from the antenna instead of
radiating — like an echo on a mismatched transmission line. The standard
measure of mismatch is the **Voltage Standing Wave Ratio (VSWR)**, computed from
the reflection coefficient

$$\Gamma = \frac{Z_\text{in} - Z_0}{Z_\text{in} + Z_0}, \qquad
\text{VSWR} = \frac{1 + |\Gamma|}{1 - |\Gamma|}.$$

VSWR = 1 is perfect (no reflection); higher is worse. AntennaLink computes this
across a sweep for you:

```wolfram
sweep = AntennaSweepMemory[dipole, Range[260.0, 310.0, 1.0], feed, "ReferenceImpedance" -> 50.0];
ListLinePlot[Normal[sweep[All, {#Frequency, #VSWR} &]],
  FrameLabel -> {"Frequency (MHz)", "VSWR"}, PlotRange -> {1, 6},
  GridLines -> {None, {2}}, PlotTheme -> "Detailed"]
```

The **bandwidth** of an antenna is the frequency range over which the match is
"good enough" — commonly where VSWR < 2 (the line drawn above). Notice the
lowest VSWR sits near resonance: matching and resonance are closely related, and
much of practical antenna engineering is about moving these curves where you
want them.

---

## 5. Polarization

The wave from an antenna has its electric field pointing in a definite
direction — that is its **polarization**. For a straight wire, the radiated
*E*-field lines up with the wire. Our *z*-oriented dipole is therefore
**vertically polarized**. A receiving antenna must share the transmitter's
polarization, or it loses signal (a vertical and a horizontal dipole are, in
theory, completely "deaf" to each other).

AntennaLink returns the field as two components, `ETheta` and `EPhi` (the two
directions transverse to the direction of travel). Look broadside to the dipole:

```wolfram
b = SelectFirst[Normal[ff["FarField"]], #Theta == 90.0 && #Phi == 0.0 &];
{Abs[b["ETheta"]], Abs[b["EPhi"]]}    (* ETheta dominates -> linear, "vertical" *)
```

One component dominates and the other is ~0: that is **linear polarization**.
When the two components are equal in size but 90° out of phase, the field vector
rotates as the wave travels — **circular polarization**, used for satellites and
GPS. The helical antenna in the [README examples](README.md#example-5--helical-antenna-and-circular-polarization)
produces exactly that.

---

## 6. Making an antenna directional: the Yagi-Uda

A dipole spreads its power almost everywhere. To send it *one way* (more range,
less interference) we add **parasitic elements** — extra wires that are not fed
at all. They pick up the field from the driven dipole, re-radiate it, and if
their lengths and spacings are right, the re-radiated waves **add up in one
direction and cancel in the other**. This is the Yagi-Uda antenna — the classic
"TV aerial".

The recipe:
- one **driven element** (a dipole, the only one fed),
- one slightly **longer reflector** behind it (it pushes energy forward),
- one or more slightly **shorter directors** in front (they pull energy forward).

```wolfram
yagi = AntennaYagiUda[<|
  "ReflectorLength"  -> 0.50,
  "ReflectorSpacing" -> 0.15,
  "DrivenLength"     -> 0.47,
  "DirectorLengths"  -> {0.44, 0.43, 0.42},
  "DirectorSpacings" -> {0.15, 0.20, 0.20},
  "Segments"         -> 11
|>];
feed = {<|"Tag" -> 2, "Segment" -> 6, "Voltage" -> 1.0|>};   (* Tag 2 = the driven element *)

ff = AntennaFarFieldMemory[yagi, 300.0, feed, Range[0.0, 180.0, 5.0], Range[0.0, 355.0, 5.0]];
AntennaPlotPattern3D[ff, "ShowGeometry" -> True]
```

The doughnut has collapsed into a **single forward beam** pointing toward the
directors (the +y direction, the way the antenna "points"). Two numbers
summarize how well it works:

```wolfram
ffData = Normal[ff["FarField"]];
gainAt[t_, p_] := SelectFirst[ffData, #Theta == t && #Phi == p &]["GainDB"];

peakGain    = Max[ffData[[All, "GainDB"]]]        (* ~ 9–10 dBi: far more than the dipole's 2.15 *)
frontToBack = gainAt[90, 90] - gainAt[90, 270]    (* forward minus backward, ~ 15–20 dB *)
```

The **gain** jumped from ~2 dBi to ~9–10 dBi, and the **front-to-back ratio**
tells us the beam is ~15–20 dB stronger forward than backward. We didn't add any
power — we *redistributed* it by controlling the currents on the parasitic
elements. Try nudging the director lengths or spacings and re-running: you are
now doing real antenna design.

---

## 7. Antennas over ground: the monopole

Real antennas sit above the earth, which reflects radio waves. A beautiful
shortcut called **image theory** says a perfect conducting ground behaves
*exactly* as if there were a mirror-image antenna underneath. So a
**quarter-wave monopole** standing on a ground plane behaves like the top half
of a half-wave dipole — the ground "supplies" the missing bottom half:

```wolfram
monopole = {<|"Segments" -> 11, "Tag" -> 1, "P1" -> {0, 0, 0}, "P2" -> {0, 0, 0.25}, "Radius" -> 0.001|>};
feed     = {<|"Tag" -> 1, "Segment" -> 1, "Voltage" -> 1.0|>};   (* fed at the base *)

sol = AntennaSolveMemory[monopole, 300.0, feed, "Ground" -> <|"Type" -> "Perfect", "ConnectWires" -> True|>];
Normal[sol["InputParameters"]][[1, "ZInput"]]    (* ~ 42 + j25 ohms *)
```

Notice the impedance is roughly **half** that of the dipole (~73 Ω → ~36 Ω at
resonance). That is image theory in action: the monopole radiates into only the
upper half-space, so for the same current it sends out half the power, and
$Z = V/I$ halves. The radiation pattern is correspondingly the *top half* of the
dipole doughnut. Monopoles are everywhere — car radios, cell towers, the "rubber
duck" on a walkie-talkie — precisely because they are half the size of a dipole
and use the ground as their other half.

Try `"Type" -> "Realistic"` with `"Dielectric"` and `"Conductivity"` values to
see how real, lossy earth (instead of a perfect mirror) changes the impedance
and pattern.

---

## 8. Where to go from here

You now have the core ideas: **current distribution → impedance → radiation
pattern → directivity**, plus matching, polarization, parasitic directivity, and
ground effects. Everything else in antennas builds on these. Good next
experiments with AntennaLink:

- **Short antennas and loading.** Make the dipole 0.3 m (too short to resonate),
  watch the huge capacitive reactance, then cancel it with a center **loading
  coil** using the `"Loads"` option. See
  [README Example 4](README.md#example-4--coil-loaded-short-dipole).
- **Circular polarization.** Build a helix and compute its **axial ratio** from
  `ETheta`/`EPhi`. See
  [README Example 5](README.md#example-5--helical-antenna-and-circular-polarization).
- **Bigger arrays.** Add more directors to the Yagi and watch gain climb (with
  diminishing returns). Sweep an element spacing and plot gain vs spacing.
- **A full worked design.** The runnable
  [`examples/DishAntenna.wl`](examples/DishAntenna.wl) builds a fed parabolic
  reflector and visualizes everything end to end.

The function reference for everything used here is in the [README](README.md).
Change the numbers, break things, and watch the patterns move — that is the
fastest way to build antenna intuition.
