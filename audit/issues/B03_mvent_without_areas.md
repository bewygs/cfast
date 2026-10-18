# Mechanical vent without AREAS (guide default 0.25 m2) divides by zero

- **Type:** Crash on valid input.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** B03 in `audit/RAPPORT.md`.

## Summary

The User Guide gives a default diffuser area of 0.25 m2 (`Input_File_Chapter.tex:344`), but `read_vent` defaults `areas(:) = 0` (`input_namelist.f90:1843`). With a zero area `mv_fraction` gets `zupper = zlower` and `tanhsmooth` divides by their difference (`flowfan.f90:256-267`, `utilities.f90:88`). No input check rejects a zero or negative area.

## Reproducer

Input file(s): `audit/repro/B03_mvent_without_areas.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/B03_mvent_without_areas.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db B03_mvent_without_areas.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

| Build | Observed (master) | With the fix |
|---|---|---|
| debug | SIGFPE in `tanhsmooth` (`utilities.f90:88`) called from `mv_fraction` (`flowfan.f90:267`) | normal exit, fan flow 0.093 kg/s at 60 s |

## Root cause

Default inconsistent with the guide. The guide also names the parameters `AREA`/`HEIGHT` (and `FLOW` default 0.02 m3/s), while the code reads `AREAS`/`HEIGHTS` (and `FLOW` defaults to 0); `AREA` is a valid VENT name, so it is read and silently ignored for a fan.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Guide default and an input check:

```diff
--- a/Source/CFAST/input_namelist.f90
+++ b/Source/CFAST/input_namelist.f90
@@ -1757,6 +1757,11 @@
                         if (heights(2)<0._eb) heights(2) = from_roomptr%cheight + heights(2)
                     end if
                 end if
+                if (areas(1)<=0._eb .or. areas(2)<=0._eb) then
+                    write (errormessage,'(3a,i0)') '***Error, AREAS must be positive for mechanical vent ', trim(id), &
+                        ' &VENT number ', counter1 + counter2 + counter3
+                    call cfastexit('read_vent',14)
+                end if
                 ventptr%height(1) = heights(1)
                 ventptr%diffuser_area(1) = areas(1)
                 ventptr%height(2) = heights(2)
@@ -1840,7 +1845,7 @@
     subroutine set_defaults
 
     area                  = 0._eb
-    areas(:)              = 0._eb
+    areas(:)              = 0.25_eb
     bottom                = 0._eb
     comp_ids(:)           = 'NULL'
     criterion             = 'TIME'
```

## Impact

- Any fan without `AREAS`. Stop code 14 is unused in `read_vent`.
