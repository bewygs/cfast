# Run never ends when the layer interface reaches the base of an elevated fire

- **Type:** Hang on valid input.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** B01 in `audit/RAPPORT.md`.

## Summary

When the upper layer descends to the base of an elevated fire, `lower_plume_height` goes to zero and the fixed-point loop between entrainment and oxygen-limited HRR in `do_fire` (`fire.f90:362-391`) stops converging. It exits after 5 passes on a non-converged value whose parity depends on the pass count, so the residual seen by DASSL is not a smooth function of the state. DASSL shrinks the step to about 1e-8 s, which stays above the `stpmin` = 1e-9 s guard (`initialization.f90:397-399`), and the run advances by nanoseconds forever without any message.

## Reproducer

Input file(s): `audit/repro/B01_interface_at_fire_base_hang.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/B01_interface_at_fire_base_hang.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db B01_interface_at_fire_base_hang.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

150 kW fire with its base at 2.0 m, 0.3 m from the left wall, 1.2 m high door, `FLOW_COEFFICIENT = 0`.

| Quantity | Expected | Observed (master) |
|---|---|---|
| Run time for 600 s | a few seconds | never ends; `.status` stays at T = 110 s after 300 s of CPU |
| DASSL step | | about 1.4e-8 s near t = 112.67 s, interface at 2.00007 m |
| Instrumented `do_fire` | | loop exits with ipass = 6; `hrr_lower` alternates between about 0.4 kW and 59 kW |

The hang also occurs with the fix for the upper-plume argument order, and with both the debug and -O0 builds.

## Root cause

Non-convergent iteration and a non-smooth entrainment as the plume height goes to zero. The `z_l = max(0.0001_eb, ...)` clamp in `heskestad_plume` contributes: removing it (diff below) lets the run reach 570 s instead of 112 s, but with steps of about 3e-5 s, so it is not a complete fix.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Partial fix, tested (not sufficient):

```diff
--- a/Source/CFAST/fire.f90
+++ b/Source/CFAST/fire.f90
@@ -494,8 +494,9 @@
 
         ! entrainment is based on convective HRR and the mean flame height
         qj = 0.001_eb*q_c*xf
-        z_l = max(0.0001_eb,d*(-1.02_eb + 3.7*qstar**0.4_eb))
-        if (z>z_l) then
+        ! mean flame height; a negative value means there is no visible flame and the far-field correlation applies
+        z_l = d*(-1.02_eb + 3.7_eb*qstar**0.4_eb)
+        if (z>=z_l) then
             factor = 1.0_eb
             deltaz = max(0.0001_eb, z-z0)
         else
```

## Impact

- Any elevated fire (cabinets, shelves) whose upper layer reaches its base: an interactive run hangs; a batch run consumes its allocation with no result or diagnostic. 307 V&V inputs have elevated fires; none hangs in debug.
- Suggested directions: make the `ipass` loop converge (for example bisection on the constrained HRR) and deterministic when it does not; make entrainment continuous and differentiable as the plume height goes to zero; add a no-progress guard (minimum simulated time over N steps) that stops with an explicit message. The last one is independent and low risk.
