# leakage_flow overwrites vss/vsa of the wall vents that feed vent jet fires

- **Type:** Wrong result without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A04 in `audit/RAPPORT.md`.

## Summary

`leakage_flow` passes `vss(1,i)` and `vsa(1,i)` to `ventw` (`flowhorizontal.f90:206-208`), with `i` the leak index. These arrays belong to the wall vents and are read by `vent_jets` to burn unburned fuel at the doors. Each leak therefore overwrites the slab flows of the wall vent with the same index, and door jet fires depend on the leakage.

## Reproducer

Input file(s): `audit/repro/A04_leakage_overwrites_vent_jet_noleak.in`, `audit/repro/A04_leakage_overwrites_vent_jet_tinyleak.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A04_leakage_overwrites_vent_jet_noleak.in audit/repro/A04_leakage_overwrites_vent_jet_tinyleak.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A04_leakage_overwrites_vent_jet_noleak.in
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A04_leakage_overwrites_vent_jet_tinyleak.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

Same case without leakage, then with a leak of 3.8e-5 m2, which should not change the door jet.

| Quantity at 280 s | No leak (master) | Tiny leak (master) | Tiny leak, with the fix |
|---|---|---|---|
| `DJET_2` | 810 kW | 616 kW | 810 kW |
| `DJET_Outside` | 4.3 kW | 157 kW | 4.3 kW |
| `ULT_2` | 422 C | 384 C | 422 C |

## Root cause

Leak slab flows are written into the wall-vent arrays. Introduced in 5f26ef23 (2019-11-13); present in 7.5 to 8-Beta. Combined with A01, every compartment of every model now has leaks.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Use local arrays for the leaks:

```diff
--- a/Source/CFAST/flowhorizontal.f90
+++ b/Source/CFAST/flowhorizontal.f90
@@ -160,7 +160,7 @@
     real(eb) :: denl(2), denu(2), tu(2), tl(2)
     real(eb) :: rslab(mxfslab), tslab(mxfslab), yslab(mxfslab),xmslab(mxfslab), qslab(mxfslab)
     real(eb) :: cslab(mxfslab,ns),pslab(mxfslab,ns)
-    real(eb) :: height, width
+    real(eb) :: height, width, vss_leak(2), vsa_leak(2)
     integer :: islab, i, iroom1, iroom2, nslab
     real(eb) :: yvbot, yvtop, avent
 
@@ -203,8 +203,9 @@
         ventptr%current_area = avent
 
         if (avent>=1.0e-10_eb) then
+            ! leakage does not feed vent jet fires, so its slab flows must not overwrite vss/vsa of the wall vents
             call ventw (zflor,zlay,tu,tl,denl,denu,pflor,yvtop,yvbot,avent,cp,conl,conu,mxfslab,&
-                epsp,cslab,pslab,qslab,vss(1,i),vsa(1,i),dirs12,dpv1m2,rslab,tslab,yslab,&
+                epsp,cslab,pslab,qslab,vss_leak,vsa_leak,dirs12,dpv1m2,rslab,tslab,yslab,&
                 yvelev,xmslab,nslab,ventptr%cvent)
 
             ventptr%n_slabs = nslab
```

## Impact

- Door jet heat release (`DJET_*`) and the downstream temperatures and species, in any model with leakage and unburned fuel.
- Fix alone on the 8 V&V cases with non-zero vent jets: at most 0.6 C; `HRR_E1` 0 -> 51 W in `DelCo_Trainers/Test_04`. The size of the effect depends on how the slabs line up.

## Notes

- `ventw` declares `vss`/`vsa` `intent(out)` but sets them only for some slabs; zeroing them on entry would make the routine safer.
