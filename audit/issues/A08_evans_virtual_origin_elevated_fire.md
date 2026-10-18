# Evans modified virtual origin mixes absolute and fire-relative heights for elevated fires

- **Type:** Wrong result without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A08 in `audit/RAPPORT.md`.

## Summary

In `get_plume_temp_and_velocity`, the modified virtual origin for a target in the upper layer is `z0_prime = zlayer-(tu/tl)**0.6*(zlayer-z0)` (`fire.f90:1097`). `zlayer` is measured from the floor, `z0` from the base of the fire, and `deltaz` is then computed in the fire frame (`zin-zfire-z0_prime`). For a fire above the floor the virtual origin is shifted by zfire*(1-(tu/tl)^0.6), the centerline temperature above the interface is too low, and the continuity of Delta T0 at the interface that defines the equation (Tech Ref `virtual_origin_modified`, `:363-365`) is lost.

## Reproducer

Input file(s): `audit/repro/A08_evans_virtual_origin_elevated_fire.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A08_evans_virtual_origin_elevated_fire.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A08_evans_virtual_origin_elevated_fire.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

300 kW fire with its base at 1.0 m, target on the axis at 3.9 m, at 120 s.

| Case | Master `TRGGAST_1` | With the fix |
|---|---|---|
| Fire base at 1.0 m | 237.4 C | 263.7 C |
| Control: fire base at 0 m | 157.39 C | 157.39 C |

## Root cause

The heights in the Heskestad and Evans correlations must all be measured from the base of the fire. Present since at least 2016.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Use the fire frame:

```diff
--- a/Source/CFAST/fire.f90
+++ b/Source/CFAST/fire.f90
@@ -1094,7 +1094,8 @@
         ! plume temperature
         if (zfire<=zlayer.and.zin>zlayer) then
             ! fire is in lower and and target point is in upper layer
-            z0_prime = zlayer-(tu/tl)**0.6_eb * (zlayer-z0)
+            ! heights in the Heskestad and Evans correlations are measured from the base of the fire
+            z0_prime = (zlayer-zfire)-(tu/tl)**0.6_eb * (zlayer-zfire-z0)
             rho = 352.981915_eb/tu
             deltaz = max(0.1_eb,zin-zfire-z0_prime)
             t_excess = min(t_max,9.1_eb*(tu/(grav_con*cpg**2*rho**2))**onethird * hrr_c**twothirds * deltaz**(-5.0_eb/3.0_eb))
```

## Impact

- Plume temperature and velocity at targets, detectors and sprinklers in the upper layer above an elevated fire (cabinets, storage): TRGGAST, TRGSURT, activation times. 307 V&V inputs have elevated fires.
- Fix alone on 214 V&V inputs with devices: TRGGAST changes by more than 1 C in 43 cases, TRGSURT in 37. Largest: `Verification/NRC_Users_Guide/B_Cabinet_Fire_in_Switchgear/Cabinet_fire_in_switchgear` TRGGAST_4 692 -> 924 C (the corrected value reaches the 900 K cap) and TRGSURT_4 616 -> 641 C; `NIST_NRC_Corner_Effects/cabinet_11` 843 -> 944 C; `corner_400_kW`/`wall_400_kW` +67 to +69 C; `PRISME/PRS_D5`/`D6` +55 C; `DelCo_Trainers/Test_23`-`25` +44 to +48 C. HRR -3 % in `Sprinkler/e_coefficient` (sprinkler activation).
