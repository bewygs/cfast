# Negative mechanical vent HEIGHTS are not converted for the last compartment

- **Type:** Wrong result without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A16 in `audit/RAPPORT.md`.

## Summary

With `convert_negative_distances` (on by default), a negative height is measured from the ceiling. For mechanical vents the test is `ventptr%room1<n_rooms` / `ventptr%room2<n_rooms` (`input_namelist.f90:1751, 1755`), which skips the last compartment (index `n_rooms`; OUTSIDE is `n_rooms+1`). In a one-room model, or for a fan in the last declared room, a diffuser at -2 m stays below the floor and always draws from the lower layer.

## Reproducer

Input file(s): `audit/repro/A16_mvent_negative_height_last_room.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A16_mvent_negative_height_last_room.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A16_mvent_negative_height_last_room.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

`HEIGHTS = -2` in a 3 m room (meant as 1.0 m from the floor), at 290 s.

| Quantity | Expected (same as `HEIGHTS = 1.0`) | Observed (master) | With the fix |
|---|---|---|---|
| `ULT_1` | 53.45 C | 47.85 C | 53.45 C |
| `HGT_1` | 0.998 m | 1.465 m | 0.998 m |

Adding an unconnected second room to the master run restores the expected values.

## Root cause

Off-by-one in the room index test, since negative positions were added in 126908c3 (2020-05-19).

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Include the last compartment:

```diff
--- a/Source/CFAST/input_namelist.f90
+++ b/Source/CFAST/input_namelist.f90
@@ -1748,11 +1748,11 @@
 
                 ! diffuser locations
                 if (convert_negative_distances) then
-                    if (ventptr%room1<n_rooms) then
+                    if (ventptr%room1<=n_rooms) then
                         from_roomptr => roominfo(ventptr%room1)
                         if (heights(1)<0._eb) heights(1) = from_roomptr%cheight + heights(1)
                     end if
-                    if (ventptr%room2<n_rooms) then
+                    if (ventptr%room2<=n_rooms) then
                         from_roomptr => roominfo(ventptr%room2)
                         if (heights(2)<0._eb) heights(2) = from_roomptr%cheight + heights(2)
                     end if
```

## Impact

- Fans in the last compartment with heights given from the ceiling. No V&V input uses negative fan heights. The negative-distance convention is not documented in the User Guide.
