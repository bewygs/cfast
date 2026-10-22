# Ceiling vent to OUTSIDE: outside air density is computed from the offset pressure (about 4e-4 kg/m3)

- **Type:** Wrong result without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A03 in `audit/RAPPORT.md`.

## Summary

In `vent_flow` for a vertical vent whose top side is OUTSIDE, the density of the outside air is computed as `(exterior_abs_pressure - den(1))/rgas/T` (`flowvertical.f90:257-258`). After `initialize_ambient`, `exterior_abs_pressure` is no longer the absolute pressure but the small offset -xxpmin (`initialization.f90:116`), so the outside density is about 4e-4 kg/m3 instead of 1.2 kg/m3. The unstable-exchange (Cooper) flow then never occurs and the pressure-driven flow is wrong.

## Reproducer

Input file(s): `audit/repro/A03_ceiling_vent_outside_density_exhaust.in`, `audit/repro/A03_ceiling_vent_outside_density_fire.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A03_ceiling_vent_outside_density_exhaust.in audit/repro/A03_ceiling_vent_outside_density_fire.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A03_ceiling_vent_outside_density_exhaust.in
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A03_ceiling_vent_outside_density_fire.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

| Case | Quantity | Observed (master) | With the fix |
|---|---|---|---|
| Exhaust through a roof vent | `PRS_1` | -249.4 Pa | -0.323 Pa |
| same | vent flow | 0.309 kg/s | 0.598 kg/s |
| 200 kW fire under a roof vent, 590 s | HRR | 135 kW (oxygen-limited) | 200 kW |
| same | HGT | 0.10 m | 0.47 m |
| same | exchange inflow | 0 | 0.257 kg/s |

## Root cause

`exterior_abs_pressure` is used as if it still held the absolute pressure. Introduced in 0fabcc3dc (2022-12-31); present in 7.7.4 to 8-Beta. The absolute pressure is `pressure_offset + relp`.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Use the absolute pressure:

```diff
--- a/Source/CFAST/flowvertical.f90
+++ b/Source/CFAST/flowvertical.f90
@@ -11,7 +11,7 @@
     use cparams, only: u, l, m, q, deltatemp_min, pp, mxrooms
     use option_data, only: option, on
     use room_data, only: n_rooms, ns, roominfo, exterior_ambient_temperature, interior_ambient_temperature, exterior_rho, &
-                        exterior_abs_pressure
+                        pressure_offset
     use vent_data, only: n_vvents, vventinfo
 
     implicit none
@@ -255,7 +255,7 @@
         den(1) = toproomptr%rho(ilay(1))
     else
         den(1) = botroomptr%exterior_relp_initial-grav_con*botroomptr%cheight*botroomptr%exterior_den_initial
-        den(1) = (exterior_abs_pressure - den(1))/rgas/exterior_ambient_temperature
+        den(1) = (pressure_offset + den(1))/rgas/exterior_ambient_temperature
     end if
     if (ibot<=n_rooms) then
         den(2) = botroomptr%rho(ilay(2))
```

## Impact

- Every ceiling or floor vent that opens to the outside above the compartment (102 of 421 V&V inputs).
- Fix alone on those 102 cases: HGT changes in 63 of 73 cases with fires, PRS in 16. `FMSNL_13` -770 -> -27 Pa, `FMSNL_12` -250 -> -25 Pa, `FMSNL_11` HGT 1.34 -> 1.70 m, `DelCo_Trainers/Test_05` HRR 2.5 W -> 397 kW and ULT_2 576 -> 389 C.
