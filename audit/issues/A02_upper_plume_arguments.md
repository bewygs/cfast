# Upper-layer plume: heskestad_plume is called with its arguments in the wrong order

- **Type:** Wrong result without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A02 in `audit/RAPPORT.md`.

## Summary

For the part of the fire that burns in the upper layer, `do_fire` calls `heskestad_plume (hrr, hrr_c, upper_plume_height, fire_area, x, y, t_inf, ...)` (`fire.f90:409-411`), while the signature is `(q_t, q_c, fire_area, x, y, z, t_inf, entrainment_rate)`. The plume height is used as the fire area, the fire area as the distance to the side walls, and so on. Entrainment in the upper layer then depends on where the fire is in the room: for a fire against the front or back wall the upper-layer burning is zero.

## Reproducer

Input file(s): `audit/repro/A02_upper_plume_shelf_fire_front_wall.in`, `audit/repro/A02_upper_plume_shelf_fire_left_wall.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A02_upper_plume_shelf_fire_front_wall.in audit/repro/A02_upper_plume_shelf_fire_left_wall.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A02_upper_plume_shelf_fire_front_wall.in
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A02_upper_plume_shelf_fire_left_wall.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

The two files are the same room and fire, rotated by 90 degrees (fire against the front wall, then against the left wall). The results must be identical.

| Quantity at 300 s | Front wall (master) | Left wall (master) | Both, with the fix |
|---|---|---|---|
| `HRR_2` (upper-layer burning) | 0 | 100 kW | identical |
| `ULT_1` | 117.6 C | 213.9 C | identical (245.26 C at 590 s) |

## Root cause

Argument order in the call at `fire.f90:409-411`, introduced in 49554367 (2020-08-31), present in 7.6.0 to 8-Beta. The lower-layer call at `:367-369` has the right order.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Argument order:

```diff
--- a/Source/CFAST/fire.f90
+++ b/Source/CFAST/fire.f90
@@ -406,9 +406,9 @@
         hrr = hrr_c/(1.0_eb-chirad)
         upper_plume_height = max (0.0_eb, min(layer_thickness,(room_height - z_fire_position)))
 
-        call heskestad_plume (hrr, hrr_c, upper_plume_height, fire_area, &
+        call heskestad_plume (hrr, hrr_c, fire_area, &
            min(x_fire_position,room_width-x_fire_position), min(y_fire_position,room_depth-y_fire_position), &
-            interior_ambient_temperature, entrainment_rate_upper)
+            upper_plume_height, interior_ambient_temperature, entrainment_rate_upper)
 
         source_o2 = roomptr%species_fraction(u,o2)
         call chemistry (pyrolysis_rate_upper, molar_mass, entrainment_rate_upper, hoc, y_soot, y_soot_flaming, y_soot_smolder, &
```

## Impact

- HRR, species and temperatures whenever part of the fire burns in the upper layer (elevated fires, deep upper layers, oxygen-limited lower layers).
- Fix alone on the 421 V&V inputs: 13 cases change. `NIST_NRC_T2`/`T8` HRR -18 % at the peak (1.178 -> 0.960 MW at 482 s), `T16` 2.30 -> 1.95 MW, `T13` -13 %, `Cabinet_fire_in_MCR_no_ventilation` 702 -> 585 kW, TRGSURT up to -8.3 C.

## Notes

- An unverified search result mentioned #2562; it may be related.
