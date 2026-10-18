# COMP FLOW_COEFFICIENT defaults to 0.07: every compartment leaks and LEAK_AREA_RATIO is ignored

- **Type:** Wrong result without warning (regression on master).
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A01 in `audit/RAPPORT.md`.

## Summary

`read_comp` defaults `FLOW_COEFFICIENT` to 0.07 (`input_namelist.f90:659`). Since fd25c16 (2026-10-16, fix for #2568) any `cvent > 0` takes the blower-door branch of `initialize_leaks` (`initialization.f90:224`), which creates wall, floor and ceiling leaks of total area C*sqrt(rho/2) = 0.054 m2 for every compartment that does not set `FLOW_COEFFICIENT`. The User Guide says the default is 0 (`Input_File_Chapter.tex:215`). As a consequence `LEAK_AREA_RATIO` is never used, and the analytical verification case `sealed_test` fails.

A second defect is in the same branch: the ceiling leak uses `leak_area_ratios(3)` (0 by default) instead of its share of the blower-door area (`initialization.f90:284`), so the ceiling leak has zero area and the total leak area is 77 % of C*sqrt(rho/2) for a 5 x 5 x 3 m room.

## Reproducer

Input file(s): `audit/repro/A01_flow_coefficient_default_sealed_room.in`, `audit/repro/A01_blower_door_ceiling_leak.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A01_flow_coefficient_default_sealed_room.in audit/repro/A01_blower_door_ceiling_leak.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A01_flow_coefficient_default_sealed_room.in
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A01_blower_door_ceiling_leak.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

| Case | Quantity | Expected | Observed (master) | With the fix |
|---|---|---|---|---|
| `A01_flow_coefficient_default_sealed_room.in` (copy of `Verification/Energy_Balance/sealed_test.in`) | `PRS_1` at 600 s | 192000 Pa (analytical, `sealed_test.csv`) | -5.62 Pa | 191840 Pa |
| same | `ULT_1` at 600 s | 568.7 C | 787.1 C | 581.2 C |
| `A01_blower_door_ceiling_leak.in` (C = 0.01, exhaust 0.05 m3/s) | `PRS_1` at steady state | -25 Pa (Q = C dP^0.5) | -42.24 Pa | -25.23 Pa |

## Root cause

`flow_coefficient = 0.07_eb` in `set_defaults` of `read_comp` was not changed when fd25c16 changed the meaning of `FLOW_COEFFICIENT` and the CeditQt default to 0. CeditQt always writes `FLOW_COEFFICIENT`, so files written by the GUI are not affected, which probably hid the regression. Hand-written files and 418 of the 421 V&V inputs are affected.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Default and ceiling leak area:

```diff
--- a/Source/CFAST/initialization.f90
+++ b/Source/CFAST/initialization.f90
@@ -281,7 +281,7 @@
             ventptr%width = 0.9_eb * (roomptr%cwidth + roomptr%cdepth)/2
             area2 = roomptr%cwidth * roomptr%cdepth
             ventptr%soffit  = roomptr%cheight 
-            ventptr%sill   = roomptr%cheight - area*roomptr%leak_area_ratios(3)/ventptr%width
+            ventptr%sill   = roomptr%cheight - area2/area*leak_area/ventptr%width
             ventptr%offset(1) = 0._eb
             ventptr%offset(2) = 0._eb
             ventptr%face=1
--- a/Source/CFAST/input_namelist.f90
+++ b/Source/CFAST/input_namelist.f90
@@ -656,7 +656,7 @@
     grid(:)                 = default_grid
     origin(:)               = 0.0_eb
     leak_area_ratio(:)      = 0.0_eb
-    flow_coefficient        = 0.07_eb
+    flow_coefficient        = 0.0_eb
     hall                    = .false.
     shaft                   = .false.
 
```

## Impact

- All outputs of every input that does not set `FLOW_COEFFICIENT`.
- Default fix alone, run on the 421 V&V inputs: ULT changes by more than 1 C in 219 cases, HGT by more than 1 cm in 318, HRR by more than 1 % in 30. Examples: `Validation/DelCo_Trainers/Test_05` ULT_2 576 -> 189 C and HRR 397 kW -> 0; `NIST_NRC_Corner_Effects/cabinet_07` ULT_2 855 -> 538 C; `NIST_NRC_T13` HRR 0.96 -> 2.33 MW at 278 s; `Verification/Sprinkler/sprinkler_1` PRS 33 kPa instead of -0.6 Pa.
- No released version (8-Beta or earlier) contains fd25c16.

## Notes

- `Appendix_CFAST_Keywords.tex:156` and `:162` still give 0.07 and "Real Doublet 0,0" for `FLOW_COEFFICIENT` and `LEAK_AREA_RATIO`.
- Suggested test: a verification case that sets `FLOW_COEFFICIENT` and checks the steady-state pressure against Q = C dP^0.5 (the second reproducer does this).
- #2565 (item 4) may already ask about the 0.07 default; I could not read the tracker to check.
