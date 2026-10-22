# SENSOD of a dual-threshold smoke detector reports only the flaming component

- **Type:** Wrong output without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A14 in `audit/RAPPORT.md`.

## Summary

The spreadsheet writes `dtectptr%value` for 'Sensor Obscuration' (`outputspreadsheet.f90:1529`). For a dual detector `value` holds only the flaming optical density; the smoldering part is in `value_smolder` (`target.f90:787-795, 823-825`). The `.out` prints the total `obscuration`.

## Reproducer

Input file(s): `audit/repro/A14_dual_detector_obscuration.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A14_dual_detector_obscuration.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A14_dual_detector_obscuration.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

Single and dual detectors at the same point, smoldering fire.

| Quantity | Expected (same as the single detector and the `.out`) | Observed (master) | With the fix |
|---|---|---|---|
| `SENSOD_2` at 100 s / 200 s | 0.120 / 0.194 | 0 / 0 | 0.120 / 0.194 |

## Root cause

Wrong field; introduced with dual detectors (549836c5, 2019). For single detectors `value` equals `obscuration` after each update, so the fix does not change them.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Write the total obscuration:

```diff
--- a/Source/CFAST/outputspreadsheet.f90
+++ b/Source/CFAST/outputspreadsheet.f90
@@ -1526,7 +1526,8 @@
         do i = 1, n_detectors
             dtectptr =>detectorinfo(i)
             if (dtectptr%id==device) then
-                call ssaddtolist (position, dtectptr%value,outarray)
+                ! value is only the flaming component for a dual detector
+                call ssaddtolist (position, dtectptr%obscuration,outarray)
             end if
         end do
     case ('Sensor Temperature')
```

## Impact

- CSV obscuration of dual detectors only; activation is not affected. One V&V input (`Verification/Bundle_Examples/Large_Building.in`).
