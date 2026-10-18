# Mechanical vent: mv_pressure subtracts the compartment elevation a second time

- **Type:** Wrong result without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A05 in `audit/RAPPORT.md`.

## Summary

`mv_pressure` computes the pressure at an inside diffuser as `roomptr%relp - interior_rho*grav_con*roomptr%z0 - (layer hydrostatics)` (`flowfan.f90:223`). `relp` is already the pressure at the floor of the compartment in the global frame (it contains -rho g z0, `initialization.f90:93`), so z0 is counted twice. The fan sees a spurious back-pressure of rho g z0 (about 12 Pa per meter of elevation) and is throttled by the 200/300 Pa cutoffs. An exhaust fan in a compartment above about 17 m loses flow, and stops entirely near 25 m.

## Reproducer

Input file(s): `audit/repro/A05_fan_elevated_compartment_z0.in`, `audit/repro/A05_fan_elevated_compartment_z25.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A05_fan_elevated_compartment_z0.in audit/repro/A05_fan_elevated_compartment_z25.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A05_fan_elevated_compartment_z0.in
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A05_fan_elevated_compartment_z25.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

Same room and 1 m3/s exhaust fan, translated vertically. The outside diffuser is given at the same absolute elevation as the inside one (z0 + 2.5 m, the convention used by `Verification/Ventilation/VVent_Tests.in`), so the expected result does not depend on how the outside height is interpreted (see the related note).

| z0 | Master `M_1_Outside_1` | With the fix |
|---|---|---|
| 0 m | 1.195 kg/s | 1.195 kg/s |
| 15 m | 1.193 kg/s | 1.193 kg/s |
| 20 m | 1.032 kg/s | 1.193 kg/s |
| 25 m | 0.0039 kg/s | 1.192 kg/s |
| 30 m | 0 | 1.191 kg/s |

## Root cause

The `- interior_rho*grav_con*roomptr%z0` term. The code dates from a842174b (2016, "Continuing simplification of mechanical vents. It's totally broken at the moment").

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Remove the double count:

```diff
--- a/Source/CFAST/flowfan.f90
+++ b/Source/CFAST/flowfan.f90
@@ -10,7 +10,7 @@
     use cenviro, only: cp
     use cparams, only: u, l, m, q, soot, soot_flaming, soot_smolder, ts, mxrooms
     use option_data, only: option, off
-    use room_data, only: n_rooms, ns, roominfo, exterior_rho, interior_rho, exterior_abs_pressure
+    use room_data, only: n_rooms, ns, roominfo, exterior_rho, exterior_abs_pressure
     use vent_data, only: n_mvents, mventinfo
 
     implicit none
@@ -220,7 +220,8 @@
         hu = max(0.0_eb,height-hl)
         rhou = roomptr%rho(u)
         rhol = roomptr%rho(l)
-        mv_pressure = roomptr%relp - interior_rho*grav_con*roomptr%z0 - (rhol*grav_con*hl + rhou*grav_con*hu)
+        ! relp is already the pressure at the floor of the compartment, z0 included
+        mv_pressure = roomptr%relp - (rhol*grav_con*hl + rhou*grav_con*hu)
     else
         mv_pressure =  exterior_abs_pressure - exterior_rho*grav_con*height
     end if
```

## Impact

- Mechanical ventilation of compartments above about 17 m (high-rise, atria), and every downstream smoke and oxygen result.
- Fix alone on the 94 V&V inputs with mechanical vents: outputs are bit-identical, because the error never exceeds the 200 Pa cutoff there (largest: 118 Pa for `Comp 3 Down` at 10 m in `VVent_Tests.in`). No V&V case exercises the defect.

## Notes

- Related documentation gap: the User Guide says the diffuser height is "above the floor" (`Input_File_Chapter.tex:345`), which is undefined for OUTSIDE; the code uses an absolute elevation there, and V&V inputs use both readings (`VVent_Tests.in` absolute; `ventilation_2.in` and `LLNL_17`-`59` floor-relative). If a user gives the outside height from the room floor (`audit/repro/C12_mvent_outside_height_convention.in`, z0 = 20 m, `HEIGHTS = 2.5, 2.5`), master gives 0 kg/s, this fix alone 1.032 kg/s, and measuring the outside height from the floor of the connected compartment (as wall vents do, `flowhorizontal.f90:640-645`) gives 1.193 kg/s. The audit report gives that second diff; it needs a decision on the convention.
