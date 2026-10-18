# FIRE LOCATION defaults to the (0,0) corner; the User Guide says the compartment center

- **Type:** Wrong result without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A10 in `audit/RAPPORT.md`.

## Summary

`read_fire` defaults `location(:) = 0._eb` (`input_namelist.f90:1278`). A fire without `LOCATION` is placed in the front-left corner and treated as a corner fire by `heskestad_plume` (`xf = 4`, `fire.f90:483-485`). The User Guide says "Position X, Y (default: compartment center)" (`Input_File_Chapter.tex:431`), and CeditQt also creates new fires at the center (`:425`).

## Reproducer

Input file(s): `audit/repro/A10_fire_location_default.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A10_fire_location_default.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A10_fire_location_default.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

5 x 5 m room, 300 kW fire without `LOCATION`, at 240 s.

| Quantity | Expected (center 2.5, 2.5) | Observed (master, same as `LOCATION = 0, 0`) | With the fix |
|---|---|---|---|
| `ULT_1` | 127.6 C | 141.4 C | 127.56 C |
| `PLUM_1` | 0.857 kg/s | 0.639 kg/s | 0.857 kg/s |

## Root cause

Default value since 088b6f1f (2017-12-14, new namelist fire input); a -1 sentinel would not work because of the negative-distance conversion, so the fix uses `huge(1._eb)` like `e_coefficient`.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Center by default:

```diff
--- a/Source/CFAST/input_namelist.f90
+++ b/Source/CFAST/input_namelist.f90
@@ -1185,7 +1185,9 @@
             fireptr%e_coefficient = -1._eb
             if (e_coefficient<huge(1._eb)) fireptr%e_coefficient = e_coefficient
             
-            ! position
+            ! position; the default is the center of the compartment
+            if (location(1)>=huge(1._eb)) location(1) = roomptr%cwidth/2._eb
+            if (location(2)>=huge(1._eb)) location(2) = roomptr%cdepth/2._eb
             if (convert_negative_distances) then
                 if (location(1)<0._eb) location(1) = roomptr%cwidth + location(1)
                 if (location(2)<0._eb) location(2) = roomptr%cdepth + location(2)
@@ -1275,7 +1277,7 @@
     id                      = 'NULL'
     fyi                     = 'NULL'
     ignition_criterion      = 'TIME'
-    location(:)             = 0._eb
+    location(:)             = huge(1._eb)
     setpoint                  = 0._eb
 
     end subroutine set_defaults
```

## Impact

- Entrainment, layer height, temperatures and radiation to targets for any fire without `LOCATION`. All 471 V&V fires give `LOCATION`.
