# HALL compartments: the Delichatsios corridor correlation is applied on one side of the fire only

- **Type:** Wrong result without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A07 in `audit/RAPPORT.md`.

## Summary

In `get_gas_temp_velocity`, the corridor (Delichatsios) branch uses the signed distance along the corridor, `distance = ydistance` or `xdistance` (`fire.f90:928, 931`). Points on the negative side of the fire get a negative distance, fail the x > W/2 test and fall back to the radial ceiling-jet correlation. Two detectors placed symmetrically about the fire therefore see different temperatures.

## Reproducer

Input file(s): `audit/repro/A07_hallway_ceiling_jet_symmetry.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A07_hallway_ceiling_jet_symmetry.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A07_hallway_ceiling_jet_symmetry.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

Two heat detectors and two targets at +/- 8 m from the fire in a corridor; the door is in line with the fire, so the geometry is symmetric.

| Quantity | +8 m (master) | -8 m (master) | Both, with the fix |
|---|---|---|---|
| Detector activation | 109 s | 149 s | identical |
| `TRGGAST` at 30 s | 71.4 C | 65.3 C | identical |

## Root cause

Missing `abs()` on the distance. Older than the 2016 source move.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Use the absolute distance:

```diff
--- a/Source/CFAST/fire.f90
+++ b/Source/CFAST/fire.f90
@@ -925,10 +925,10 @@
             r = sqrt(xdistance**2 + ydistance**2)
             if (roomptr%hall) then
                 if (roomptr%cdepth>roomptr%cwidth) then
-                    distance = ydistance
+                    distance = abs(ydistance)
                     hall_width = roomptr%cwidth
                 else
-                    distance = xdistance
+                    distance = abs(xdistance)
                     hall_width = roomptr%cdepth
                 end if
             else
```

## Impact

- Detector and sprinkler activation, target gas temperatures and convection in every compartment with `HALL = .TRUE.` (13 V&V inputs).
- Fix alone on those 13 cases: `ATF_Corridors` TRGGAST +5 to +55 C (500 kW case 306 -> 361 C), TRGSURT +2 to +18 C.
