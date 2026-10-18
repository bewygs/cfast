# Without &INIT the ambient O2 and N2 mass fractions are zero and no fire burns

- **Type:** Wrong result without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A09 in `audit/RAPPORT.md`.

## Summary

`read_init` sets `interior/exterior_ambient_o2_mass_fraction` and the N2 fractions only inside `if (initflag)` (`input_namelist.f90:314-317`). `initialize_memory` sets defaults for temperature, pressure and humidity (`initialization.f90:405-413`) but not for O2/N2. The User Guide gives a default for every &INIT parameter (O2 = 0.23 kg/kg, `Input_File_Chapter.tex:49-51`), so &INIT is optional, but without it the initial atmosphere contains no oxygen.

## Reproducer

Input file(s): `audit/repro/A09_missing_init_no_oxygen.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A09_missing_init_no_oxygen.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A09_missing_init_no_oxygen.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

| Quantity at 240 s | Expected (same file with `&INIT /`) | Observed (master) | With the fix |
|---|---|---|---|
| `HRR_1` | 300 kW | 0 | 300 kW |
| `ULT_1` | 127.6 C | 20 C | 127.56 C |
| `LLO2_1` | 0.204 | 0 | 0.204 |

The run ends with "Normal exit" and no warning.

## Root cause

Missing defaults for four module variables, since the O2 inputs were added to &INIT in ab13c539 (2025-10-30, #2216); before that commit 0.23 was hard-coded in `initialization.f90` and a file without &INIT burned normally. Released in 7.7.6, 7.7.7 and 8-Beta. With gfortran they are zero because they are in static storage; formally they are undefined.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Defaults in initialize_memory:

```diff
--- a/Source/CFAST/initialization.f90
+++ b/Source/CFAST/initialization.f90
@@ -14,7 +14,7 @@
         xlrg, default_grid, face_front, trigger_by_time, h2o, ns_mass, w_from_room, w_to_room, w_from_wall, w_to_wall, &
         smoked, mxss
     use defaults, only: default_temperature, default_pressure, default_relative_humidity, default_rti, &
-        default_activation_temperature, default_lower_oxygen_limit, default_radiative_fraction
+        default_activation_temperature, default_lower_oxygen_limit, default_radiative_fraction, default_o2_mass_fraction
     use devc_data, only: n_detectors, detectorinfo, n_targets, targetinfo, alloc_devc, init_devc
     use fire_data, only: n_fires, fireinfo, n_tabls, tablinfo, n_furn, mxpts, lower_o2_limit, tgignt, alloc_fire, init_fire
     use material_data, only: n_matl, material_info, alloc_matl, init_matl
@@ -411,6 +411,10 @@
         exterior_ambient_temperature = interior_ambient_temperature
         exterior_abs_pressure = interior_abs_pressure
         relative_humidity = default_relative_humidity
+        interior_ambient_o2_mass_fraction = default_o2_mass_fraction
+        exterior_ambient_o2_mass_fraction = default_o2_mass_fraction
+        interior_ambient_n2_mass_fraction = 1.0_eb - default_o2_mass_fraction
+        exterior_ambient_n2_mass_fraction = 1.0_eb - default_o2_mass_fraction
     end if 
 
     !thermal properties. initialize to nothing
```

## Impact

- Every input without &INIT (all V&V inputs and both editors write it, so only hand-written or third-party files are affected).
