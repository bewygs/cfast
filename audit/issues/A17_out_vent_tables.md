# .out vent tables: area and flow swapped, default times and fractions printed, ramps not listed

- **Type:** Wrong output without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A17 in `audit/RAPPORT.md`.

## Summary

The VENT CONNECTIONS and VENT RAMPS tables of the `.out` misreport the inputs of ceiling/floor and mechanical vents (`output.f90:816-948`), while the wall vent table (`:757-783`) is correct:
1. Times and fractions are printed from `opening_initial_time` and related fields, which are never set from the input any more (`set_criterion`, `input_namelist.f90:1874-1898`, stores them in `t(:)`/`f(:)`), so 0/1/0/1 is printed whatever the input.
2. For a fan with a ramp, area and flow are swapped (`:871`).
3. For a fan triggered by temperature or flux, `ventptr%area` (never set for fans) is printed instead of `diffuser_area(1)` (`:876, 882`).
4. The VENT RAMPS table is written only when there are more than two vents of a type (`n_hvents>2`, `n_vvents>2`, `n_mvents>2`, `:907, 923, 939`).

## Reproducer

Input file(s): `audit/repro/A17_out_vent_tables.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A17_out_vent_tables.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A17_out_vent_tables.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

| Item | Expected in `.out` | Observed (master) | With the fix |
|---|---|---|---|
| CF1 (T = 30, 40; F = 0, 1) | 30.00 0.00 40.00 1.00 | 0.00 1.00 0.00 1.00 | expected |
| CF2 (PRE 0.2, POST 0.9) | 0.20 / 0.90 | 1.00 / 1.00 | expected |
| MV2 ramp (AREAS 0.3, FLOW 0.05) | 0.30 / 0.05 | 0.05 / 0.30 | expected |
| MV3 (AREAS 0.4, temperature trigger) | 0.40 | 0.00 | expected |
| VENT RAMPS | WV1 and MV2 | one ramp, under vent number 1 | both listed |

The vents CSV shows the real behavior (for example `CFF_2_1_1` is 0 until 30 s).

## Root cause

Stale fields and copy errors in `output_initial_conditions`: the area/flow swap dates from 33458ca1 (2018-06-13); the times and fractions became stale when 7ef57d97 (2021-02-04) moved them to `t(:)`/`f(:)`; the `>2` tests date from 79211d92 (2021-02-08). The User Guide example (`Output_Chapter.tex:137-138`) reproduces the swapped area and flow.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Print the stored inputs:

```diff
--- a/Source/CFAST/output.f90
+++ b/Source/CFAST/output.f90
@@ -812,10 +812,11 @@
             roomptr => roominfo(ventptr%room2)
             if (ventptr%opening_type==trigger_by_time) then
                 ctrigger = 'Time'
-                if (ventptr%npoints<=2) then
+                if (ventptr%npoints==0) then
+                    write (iofilo,5050) ciout, cjout, ventptr%counter, csout, ventptr%area, ctrigger, 0.0_eb, 1.0_eb
+                else if (ventptr%npoints<=2) then
                     write (iofilo,5050) ciout, cjout, ventptr%counter, csout, ventptr%area, &
-                        ctrigger, ventptr%opening_initial_time, ventptr%opening_initial_fraction, &
-                        ventptr%opening_final_time, ventptr%opening_final_fraction
+                        ctrigger, (ventptr%t(j), ventptr%f(j), j=1,ventptr%npoints)
                 else
                     iramp = iramp + 1
                     write (crout,'(a6,1x,i0)') 'RAMP #',iramp
@@ -825,14 +826,12 @@
                 ctrigger = 'Temp'
                 targptr => targetinfo(ventptr%opening_target)
                 write (iofilo,5055) ciout, cjout, ventptr%counter, csout, ventptr%area, &
-                    ctrigger, ventptr%opening_criterion-kelvin_c_offset, targptr%id, ventptr%opening_initial_fraction, &
-                    ventptr%opening_final_fraction
+                    ctrigger, ventptr%opening_criterion-kelvin_c_offset, targptr%id, ventptr%f(1), ventptr%f(2)
             else 
                 ctrigger = 'Flux'
                 targptr => targetinfo(ventptr%opening_target)
                 write (iofilo,5055) ciout, cjout, ventptr%counter, csout, ventptr%area, &
-                    ctrigger, ventptr%opening_criterion, targptr%id, ventptr%opening_initial_fraction, &
-                    ventptr%opening_final_fraction
+                    ctrigger, ventptr%opening_criterion, targptr%id, ventptr%f(1), ventptr%f(2)
             end if
         end do
     end if
@@ -861,27 +860,27 @@
             if (ventptr%room2==n_rooms+1) cjout = 'Outside'
             if (ventptr%opening_type==trigger_by_time) then
                 ctrigger = 'Time'
-                if (ventptr%npoints<=2) then
+                if (ventptr%npoints==0) then
                     write (iofilo,5130) ciout, cjout, ventptr%counter, ventptr%diffuser_area(1), ventptr%coeff(1), &
-                        ctrigger, ventptr%opening_initial_time, ventptr%opening_initial_fraction, &
-                        ventptr%opening_final_time, ventptr%opening_final_fraction
+                        ctrigger, 0.0_eb, 1.0_eb
+                else if (ventptr%npoints<=2) then
+                    write (iofilo,5130) ciout, cjout, ventptr%counter, ventptr%diffuser_area(1), ventptr%coeff(1), &
+                        ctrigger, (ventptr%t(j), ventptr%f(j), j=1,ventptr%npoints)
                 else
                     iramp = iramp + 1
                     write (crout,'(a6,1x,i0)') 'RAMP #',iramp
-                    write (iofilo,5130) ciout, cjout, ventptr%counter, ventptr%coeff(1), ventptr%diffuser_area(1), crout
+                    write (iofilo,5130) ciout, cjout, ventptr%counter, ventptr%diffuser_area(1), ventptr%coeff(1), crout
                 end if
             else if (ventptr%opening_type==trigger_by_temp) then
                 ctrigger = 'Temp'
                 targptr => targetinfo(ventptr%opening_target)
-                write (iofilo,5135) ciout, cjout, ventptr%counter, ventptr%area, ventptr%coeff(1), &
-                    ctrigger, ventptr%opening_criterion-kelvin_c_offset, targptr%id, ventptr%opening_initial_fraction, &
-                    ventptr%opening_final_fraction
+                write (iofilo,5135) ciout, cjout, ventptr%counter, ventptr%diffuser_area(1), ventptr%coeff(1), &
+                    ctrigger, ventptr%opening_criterion-kelvin_c_offset, targptr%id, ventptr%f(1), ventptr%f(2)
             else 
                 ctrigger = 'Flux'
                 targptr => targetinfo(ventptr%opening_target)
-                write (iofilo,5135) ciout, cjout, ventptr%counter, ventptr%area, ventptr%coeff(1), &
-                    ctrigger, ventptr%opening_criterion, targptr%id, ventptr%opening_initial_fraction, &
-                    ventptr%opening_final_fraction
+                write (iofilo,5135) ciout, cjout, ventptr%counter, ventptr%diffuser_area(1), ventptr%coeff(1), &
+                    ctrigger, ventptr%opening_criterion, targptr%id, ventptr%f(1), ventptr%f(2)
             end if
         end do
     end if
@@ -904,7 +903,7 @@
      iramp = 0
      
      ! horizontal flow vents
-     if (n_hvents>2) then
+     if (n_hvents>0) then
          do i = 1, n_hvents
              ventptr => hventinfo(i)
              if (ventptr%npoints>2) then
@@ -920,7 +919,7 @@
      end if
              
     ! vertical flow vents
-    if (n_vvents>2) then
+    if (n_vvents>0) then
          do i = 1, n_vvents
              ventptr => vventinfo(i)
              if (ventptr%npoints>2) then
@@ -936,7 +935,7 @@
     end if
              
     ! mecahnical flow vents
-    if (n_mvents>2) then
+    if (n_mvents>0) then
          do i = 1, n_mvents
              ventptr => mventinfo(i)
              if (ventptr%npoints>2) then
```

## Impact

- The `.out` is often attached to study reports as the record of the inputs; reviewers who check openings there are misled. 65 V&V inputs have a ceiling, floor or mechanical vent with T/F or a trigger.
