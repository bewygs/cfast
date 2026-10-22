# Object IDs longer than 50 characters shift CSV values under the wrong headers

- **Type:** Wrong output without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A15 in `audit/RAPPORT.md`.

## Summary

`output_spreadsheet` looks up each column with `character(len=50) :: measurement, device` (`outputspreadsheet.f90:691, 699-700`), while IDs are up to 128 characters (`cfast_structures.f90:12`) and headers use the full ID. For an ID longer than 50 characters the comparison `xxx%id==device` never matches, the value is skipped, and every later value in the row moves one column to the left.

## Reproducer

Input file(s): `audit/repro/A15_long_id_column_shift.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A15_long_id_column_shift.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A15_long_id_column_shift.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

55-character IDs for a room, a fire, a target and a vent.

| CSV | Header fields | Data fields (master) | Data fields (with the fix) |
|---|---|---|---|
| compartments | 69 | 31 | 69 |
| devices | 73 | 37 | 73 |
| vents | 19 | 10 | 19 |
| walls | 9 | 5 | 9 |

## Root cause

String length (b658f455, 2020-03-02). Distinct from #2557/PR #2554 (MATL_ID length). Generated leak IDs ('Ceiling Leak ' + room ID) exceed the limit as soon as a room ID is longer than 37 characters.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Use the full ID length:

```diff
--- a/Source/CFAST/outputspreadsheet.f90
+++ b/Source/CFAST/outputspreadsheet.f90
@@ -688,7 +688,7 @@
     integer i, j, idir, layer
     real(eb) :: fire_ignition, f_height, ssvalue, tjet, flow(4)
     
-    character(len=50) :: measurement, device
+    character(len=128) :: measurement, device
     
     type(detector_type), pointer :: dtectptr
     type(fire_type), pointer :: fireptr
```

## Impact

- Every CSV of a model with a long ID; post-processing that reads columns by name gets other quantities. No V&V input has IDs over 50 characters.
