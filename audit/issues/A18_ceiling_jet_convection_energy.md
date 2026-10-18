# Ceiling jet convection: gas and ceiling energy budgets differ in large, low rooms

- **Type:** Wrong result without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A18 in `audit/RAPPORT.md`.

## Summary

`convection` limits the ceiling-jet heat transfer area to `lw_eff = min(pi*(4H)**2, LW)` (r/H < 4) and computes the average flux over that area (`convection.f90:67-73`). The gas loses `lw_eff*q` (`w_area = lw_eff`), but `fluxes_convection(i,1)` is then the boundary flux of the whole ceiling (`solve.f90:867`, `conduction.f90:105`), which receives `LW*q`. When LW > pi(4H)^2 the ceiling receives LW/lw_eff times more energy than the gas gives up. The Tech Ref (`eq:cjfluxavg`, `CFAST_Tech_Ref.tex:813`) integrates over the whole ceiling and has no r/H < 4 limit.

## Reproducer

Input file(s): `audit/repro/A18_ceiling_jet_convection_large_room.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A18_ceiling_jet_convection_large_room.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A18_ceiling_jet_convection_large_room.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

40 x 40 x 3 m hall (LW = 1600 m2, pi(4H)^2 = 452 m2), 1 MW fire, at 300 s.

| Quantity | Master | Energy-consistent variant (below) |
|---|---|---|
| `CEILT_1` | 33.9 C | 24.6 C |
| `ULT_1` | 29.2 C | 27.5 C |

From 20 C, the ceiling heats by 13.9 C instead of 4.6 C, a ratio of 3.0 close to LW/lw_eff = 3.5.

## Root cause

`w_area = lw_eff` combined with a per-unit-area flux applied to the full ceiling. The limit was added in 91b3095c (2017-04-24, "Limited area of ceiling jet to valid range of correlation") and `w_area = lw_eff` in 9e7ae542 the same day; firemodels/cfast#675 (2017) may be the related discussion.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Variant (b): keep the r/H < 4 limit and spread its energy over the ceiling:

```diff
--- a/Source/CFAST/convection.f90
+++ b/Source/CFAST/convection.f90
@@ -67,9 +67,10 @@
             ! limit the heat transfer area to the valid limit of the correlation (r/H<4)
             lw_eff = min(pi*(4.0_eb*roomptr%cheight)**2,roomptr%cwidth*roomptr%cdepth)
             qconv_avg = 0.27_eb*qconv/(lw_eff**0.68_eb*roomptr%cheight**0.64_eb)
+            ! spread the ceiling jet heat over the whole ceiling so that the wall and gas energy budgets match
+            qconv_avg = qconv_avg*lw_eff/(roomptr%cwidth*roomptr%cdepth)
             if (qconv_avg>fluxes_convection(i,iwall)) then
                 fluxes_convection(i,iwall) = qconv_avg
-                w_area = lw_eff
             end if
         end if
         
```

## Impact

- Ceiling temperatures, upper-layer temperature and the environment of near-ceiling targets and detectors in large low rooms (for example 30 x 30 x 3 m open-plan offices or 50 x 50 x 6 m warehouses).
- No V&V fire room exceeds the limit (largest ratio 0.92, `Trash_fire_in_cable_spreading_room`), so the fix leaves the V&V unchanged.
- Variant (a) is to integrate over LW as in the Tech Ref (replace `lw_eff` by `cwidth*cdepth` and remove `w_area = lw_eff`). Either way the Tech Ref should describe what is coded.
