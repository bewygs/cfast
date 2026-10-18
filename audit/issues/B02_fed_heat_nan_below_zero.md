# Heat FED raises the gas temperature in C to the power -3.61: NaN below 0 C

- **Type:** Crash (debug) or NaN output on valid input.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** B02 in `audit/RAPPORT.md`.

## Summary

The convective heat FED term is `1/(4.1e8*(T-273.15)**(-3.61))` (`target.f90:140, 143`). For a gas below 0 C the base is negative and the non-integer power is NaN. Ambient temperatures down to -50 C are accepted (`input.f90:97-101`), so an unheated building in winter is a valid input.

## Reproducer

Input file(s): `audit/repro/B02_cold_ambient_fed_nan.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/B02_cold_ambient_fed_nan.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db B02_cold_ambient_fed_nan.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

Interior and exterior at -10 C, one target.

| Build | Observed (master) | With the fix |
|---|---|---|
| debug | SIGFPE in `pow` called from `target` | normal exit, `TRGFEDH_1` = 1.2e-9 at 30 s |
| -O0 without traps | `TRGFEDH_1` = nan from 30 s on | |

## Root cause

Correlation evaluated outside its range; at exactly 0 C it gives +Inf and an increment of 0, which happens to be harmless.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Clamp the temperature (combined with the radiant FED fix):

```diff
--- a/Source/CFAST/target.f90
+++ b/Source/CFAST/target.f90
@@ -46,7 +46,7 @@
     real(eb) :: x_node(nnodes_trg), walldx(nnodes_trg), tgrad(2), wk(1), wspec(1), wrho(1), tempin, tempout
     real(eb) :: wfluxin, wfluxout, wfluxavg, xl
     real(eb) :: flux(2), dflux(2), ttarg(2), t_inf
-    real(eb) :: nu_co2, fed_gas_increment, fed_heat_increment
+    real(eb) :: nu_co2, fed_gas_increment, fed_heat_increment, tgas_c
     integer :: i, itarg, nmnode(2), iieq, iwbound, nslab, iroom, ilayer
 
     type(target_type), pointer :: targptr
@@ -136,11 +136,12 @@
             (roomptr%species_output(ilayer,hcn)*10000)**2.36_eb/1.2e6_eb)
         targptr%dfed_gas = targptr%dfed_gas + fed_gas_increment
         targptr%fed_gas = targptr%fed_gas + fed_gas_increment
-        if (targptr%flux_incident_front<2500._eb) then
-            fed_heat_increment = (dt/60._eb)*1/(4.1e8_eb*(targptr%tgas-kelvin_c_offset)**(-3.61))
-        else
-            fed_heat_increment = (dt/60._eb)*(1._eb/(4.2*targptr%flux_incident_front/1000._eb)**(-1.9_eb)) + &
-                (dt/60._eb)*(1._eb/(4.1e8_eb*(targptr%tgas-kelvin_c_offset)**(-3.61)))
+        ! the convected heat correlation uses the gas temperature in C; it is negligible at or below 1 C
+        tgas_c = max(targptr%tgas-kelvin_c_offset, 1._eb)
+        fed_heat_increment = (dt/60._eb)*tgas_c**3.61_eb/4.1e8_eb
+        if (targptr%flux_incident_front>=2500._eb) then
+            ! radiant heat: time to incapacitation 4.2*q**(-1.9) min, with q in kW/m2
+            fed_heat_increment = fed_heat_increment + (dt/60._eb)*(targptr%flux_incident_front/1000._eb)**1.9_eb/4.2_eb
         end if
         targptr%dfed_heat = targptr%dfed_heat + fed_heat_increment
         targptr%fed_heat = targptr%fed_heat + fed_heat_increment
```

## Impact

- Every model with a target and ambient air below 0 C. No V&V case is below 0 C.
