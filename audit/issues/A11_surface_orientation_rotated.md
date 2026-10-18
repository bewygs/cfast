# SURFACE_ORIENTATION wall names give normals rotated by 90 degrees from the User Guide and the vent faces

- **Type:** Wrong result without warning (needs a maintainer decision).
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A11 in `audit/RAPPORT.md`.

## Summary

`initialize_targets` maps FRONT WALL to (1,0,0), BACK WALL to (-1,0,0), RIGHT WALL to (0,1,0) and LEFT WALL to (0,-1,0) (`initialization.f90:843-850`). The User Guide puts the front wall at y = 0 and the left wall at x = 0 (`LOCATION(2)` is the distance from the front wall, `LOCATION(1)` from the left wall, `Input_File_Chapter.tex:523-524`), says "the vector (-1,0,0) indicates that the target is facing the left (-x) wall" (`:527`) and "the target normal points toward the selected surface" (`:531`). Vent faces use the same convention (`outputsmv.f90:276-295`: FRONT y = 0, LEFT x = 0, REAR y = D, RIGHT x = W). Each wall name is rotated by 90 degrees.

## Reproducer

Input file(s): `audit/repro/A11_target_orientation_front_wall.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A11_target_orientation_front_wall.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A11_target_orientation_front_wall.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

The fire is between the target and the front wall (y = 0); the target uses `SURFACE_ORIENTATION = 'FRONT WALL'`.

| Quantity at 60 s | Expected (same as `NORMAL = 0, -1, 0`) | Observed (master, same as `NORMAL = 1, 0, 0`) | With option (a) |
|---|---|---|---|
| `TRGFLXI_1` | 5.63 kW/m2 | 4.04 kW/m2 | 5.63 kW/m2 |

## Root cause

Mapping introduced in ceb53777 (2020-05-20). The 67 V&V inputs that use wall names (2047 BACK WALL, 2190 LEFT WALL, 109 FRONT WALL, 185 RIGHT WALL targets) are written for the code's mapping; for example `Verification/Radiation/radiation_1.in` uses 'BACK WALL' for a target that faces the fire in the -x direction. CeditQt offers these names (`targets_tab.py:197, 497`).

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Option (a): follow the User Guide and the vent faces:

```diff
--- a/Source/CFAST/initialization.f90
+++ b/Source/CFAST/initialization.f90
@@ -835,19 +835,20 @@
             stop
         end if
 
-        ! set up normal vector
+        ! set up normal vector; wall names follow the User Guide and the vent faces:
+        ! front y = 0, back y = depth, left x = 0, right x = width
         if (targptr%surface_orientation == "CEILING") then
             targptr%normal = (/0._eb, 0._eb, 1._eb/)
         else if (targptr%surface_orientation == "FLOOR") then
             targptr%normal = (/0._eb, 0._eb, -1._eb/)
         else if (targptr%surface_orientation == "FRONT WALL") then
-            targptr%normal = (/1._eb, 0._eb, 0._eb/)
+            targptr%normal = (/0._eb, -1._eb, 0._eb/)
         else if (targptr%surface_orientation == "BACK WALL") then
-            targptr%normal = (/-1._eb, 0._eb, 0._eb/)
-        else if (targptr%surface_orientation == "RIGHT WALL") then
             targptr%normal = (/0._eb, 1._eb, 0._eb/)
+        else if (targptr%surface_orientation == "RIGHT WALL") then
+            targptr%normal = (/1._eb, 0._eb, 0._eb/)
         else if (targptr%surface_orientation == "LEFT WALL") then
-            targptr%normal = (/0._eb, -1._eb, 0._eb/)
+            targptr%normal = (/-1._eb, 0._eb, 0._eb/)
         else
             do j = 1, n_fires
                 fireptr => fireinfo(j)
```

## Impact

- Fluxes, temperatures and FED of every target oriented by wall name in a user file that follows the User Guide.
- With option (a), the 67 V&V inputs must be converted in the same commit: code 'FRONT WALL' (+x) -> 'RIGHT WALL', 'BACK WALL' (-x) -> 'LEFT WALL', 'RIGHT WALL' (+y) -> 'BACK WALL', 'LEFT WALL' (-y) -> 'FRONT WALL'. Checked: `radiation_1.in` converted this way gives a `_devices.csv` bit-identical to master on the original input.
- Option (b) is to rewrite the guide instead, leaving target and vent wall names inconsistent.
