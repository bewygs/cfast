# More than 455 targets (or about 389 wall vents) overflow the 16384-field spreadsheet buffer

- **Type:** Crash or out-of-bounds write on valid input.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** B05 in `audit/RAPPORT.md`.

## Summary

`ssprintresults` uses `character(len=35), dimension(16384) :: out` and format `(16384a)` (`outputspreadsheet.f90:1568-1575`), while the column limit is `mxss` = 32767 (`cfast_parameters.f90:19`) and the value arrays are sized for it. A target writes 36 columns to `_devices.csv`, so 456 targets exceed the buffer although `mxtarg` = 2525; the same limit is reached with about 389 wall vents in the zone file.

## Reproducer

Input file(s): `audit/repro/B05_many_targets_buffer_overflow.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/B05_many_targets_buffer_overflow.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db B05_many_targets_buffer_overflow.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

| Build | Observed (master) | With the fix |
|---|---|---|
| debug, 456 targets | "Index 16385 of array out above upper bound of 16384" at `outputspreadsheet.f90:1573` | normal exit, 16417 fields per row including the header |
| debug, 455 targets | normal exit | |
| release | unchecked write past the array | |

## Root cause

Buffer sized below `mxss` (8d3aeef2, 2017-01-05). The header writers at `ssHeaders.f90:197-198` and `:379-380` also use `(16384a)`; beyond 16384 items format reversion would split the header line, so `(*(a))` fits there too.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Size the buffer with mxss:

```diff
--- a/Source/CFAST/outputspreadsheet.f90
+++ b/Source/CFAST/outputspreadsheet.f90
@@ -1565,14 +1565,14 @@
     integer, intent(in) :: iounit, ic
 
     integer i
-    character(len=35), dimension(16384) :: out
+    character(len=35), dimension(mxss) :: out
     
     if (ic>0) then
         out = ' '
         do i = 1, ic
             write (out(i),"(e12.5)" ) array(i)
         end do
-        write (iounit,"(16384a)") (trim(out(i)) // ',',i=1,ic-1),out(ic)
+        write (iounit,"(*(a))") (trim(out(i)) // ',',i=1,ic-1),out(ic)
     end if
     
     end subroutine ssprintresults
```

## Impact

- Large models with many targets or vents.
