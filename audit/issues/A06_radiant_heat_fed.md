# Radiant heat FED is 64 times too large: (4.2 q)^1.9 instead of q^1.9/4.2

- **Type:** Wrong result without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A06 in `audit/RAPPORT.md`.

## Summary

The radiant term of the heat FED is coded as `1/(4.2*q/1000)**(-1.9)` (`target.f90:142`), that is (4.2 q)^1.9 per minute. The Tech Ref (ISO 13571) uses t_rad = 4.2 q^-1.9 min, so the increment should be q^1.9/4.2 per minute. The coded value is 4.2^2.9 = 64.3 times too large for any flux.

## Reproducer

Input file(s): `audit/repro/A06_fed_radiant_heat.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A06_fed_radiant_heat.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A06_fed_radiant_heat.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

500 kW fire, target 1.5 m away facing the fire, output every second, q = 5.86 kW/m2, gas at 21.7 C.

| Quantity | Expected | Observed (master) | With the fix |
|---|---|---|---|
| FED increment per 1 s step | (1/60)(5.86^1.9/4.2 + 21.7^3.61/4.1e8) = 0.114 | 7.33 | 0.114 |
| `TRGFEDH_1` at 60 s | 6.85 | 439.9 | 6.854 |

## Root cause

Parenthesization: 4.2 is inside the base of the power. Introduced in 1c705386 (2018-03-14). The Tech Ref equation (`CFAST_Tech_Ref.tex:989`) is written `\frac{1}{{4.2 \, \dq''}^{-1.9}}`, whose LaTeX grouping also puts 4.2 under the exponent; it should read `4.2 \, (\dq'')^{-1.9}`. `Verification/Species/heat_tenability.in` has no fire, so only the convective term is verified.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Minimal fix:

```diff
--- a/Source/CFAST/target.f90
+++ b/Source/CFAST/target.f90
@@ -139,7 +139,7 @@
         if (targptr%flux_incident_front<2500._eb) then
             fed_heat_increment = (dt/60._eb)*1/(4.1e8_eb*(targptr%tgas-kelvin_c_offset)**(-3.61))
         else
-            fed_heat_increment = (dt/60._eb)*(1._eb/(4.2*targptr%flux_incident_front/1000._eb)**(-1.9_eb)) + &
+            fed_heat_increment = (dt/60._eb)*((targptr%flux_incident_front/1000._eb)**1.9_eb/4.2_eb) + &
                 (dt/60._eb)*(1._eb/(4.1e8_eb*(targptr%tgas-kelvin_c_offset)**(-3.61)))
         end if
         targptr%dfed_heat = targptr%dfed_heat + fed_heat_increment
```

Combined with the fix for the NaN below 0 C (B02):

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

- `TRGFEDH`, `TRGDFEDH` and the heat FED column of the `.out`, for every target above 2.5 kW/m2. The time to FED = 1 is divided by 64, which makes the heat criterion meaningless.
- Combined fix on the 162 V&V inputs with targets: `TRGFEDH` changes for 3279 targets; 457 targets in 17 cases reach FED = 1 on master but not with the fix; 1818 targets in 73 cases reach 0.3 later or never; no other device column changes.

## Notes

- `flux_incident_front` already includes the emissivity (`target.f90:83, 364-366`); the Tech Ref could state which flux enters the FED.
