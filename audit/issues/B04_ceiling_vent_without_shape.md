# Ceiling vent without SHAPE (guide default ROUND) is rejected, and the error message itself aborts

- **Type:** Crash on valid input.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** B04 in `audit/RAPPORT.md`.

## Summary

The User Guide gives ROUND as the default shape (`Input_File_Chapter.tex:309`; the code comment at `input_namelist.f90:1809` agrees), but `set_defaults` uses `shape = 'NULL'` (`:1864`) and the vent is rejected. The rejection message is written with format `'(3a,i0)'` for five strings and one integer (`:1814-1816`), so item 4, a string, meets `i0` and the run stops with a Fortran runtime error before any message reaches the log.

## Reproducer

Input file(s): `audit/repro/B04_ceiling_vent_without_shape.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/B04_ceiling_vent_without_shape.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db B04_ceiling_vent_without_shape.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

| Build | Observed (master) | With the fix |
|---|---|---|
| debug | "Fortran runtime error: Expected INTEGER for item 4 in formatted transfer" at `input_namelist.f90:1816`; nothing in the `.log` | normal exit, vent listed as Round |

## Root cause

Default inconsistent with the guide, and a wrong format. Other messages have similar format errors (`:573`, and `'(3a,i0,a,i0)'` for eight items at `:1663`, `:1727`, `:1795`).

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Guide default and the format:

```diff
--- a/Source/CFAST/input_namelist.f90
+++ b/Source/CFAST/input_namelist.f90
@@ -1812,7 +1812,7 @@
                 else if (trim(shape) == 'SQUARE') then
                     ventptr%shape = 2
                 else
-                    write (errormessage,'(3a,i0)') '***Error, SHAPE must be SQUARE or ROUND. ', shape, ' for vent ', &
+                    write (errormessage,'(5a,i0)') '***Error, SHAPE must be SQUARE or ROUND. ', trim(shape), ' for vent ', &
                         trim(id), ' &VENT number ', counter1 + counter2 + counter3
                     call cfastexit('read_vent',12)
                 end if
@@ -1861,7 +1861,7 @@
     pre_fraction          = 1._eb
     post_fraction         = 1._eb
     setpoint              = 0._eb
-    shape                 = 'NULL'
+    shape                 = 'ROUND'
     t(:)                  = -1001._eb
     top                   = 0._eb
     type                  = 'NULL'
```

## Impact

- Any ceiling or floor vent without `SHAPE`.
