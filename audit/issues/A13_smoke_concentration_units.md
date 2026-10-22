# Compartment smoke concentration in mg/m3 assumes sigma = 8700 m2/kg for all soot

- **Type:** Wrong output without warning.
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A13 in `audit/RAPPORT.md`.

## Summary

The `ULOD`, `LLOD`, `ULODF`/`ULODS` and `LLODF`/`LLODS` columns (units `mg/m^3`, `outputspreadsheet.f90:91`) are computed as optical density times 264.6903 (`outputspreadsheet.f90:907-940`), which is ln(10)/8700*1e6. The optical density uses sigma_s(flaming) = 8700 or sigma_s(smoldering) = 4400 m2/kg (`fire.f90:1187-1190`), and both can be changed with `SPECIFIC_EXTINCTION`. Smoldering soot concentrations are therefore 1.98 times too low, and so is the total whenever smoldering soot is present.

## Reproducer

Input file(s): `audit/repro/A13_smoke_concentration_smoldering.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A13_smoke_concentration_smoldering.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A13_smoke_concentration_smoldering.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

Smoldering fire, at 200 s.

| Quantity | Expected (soot mass / upper-layer volume = 0.014897 kg / 41.734 m3) | Observed (master) | With the fix |
|---|---|---|---|
| `ULODS_1` = `ULOD_1` | 357.0 mg/m3 | 180.55 mg/m3 | 356.96 mg/m3 |

## Root cause

Hard-coded conversion factor, wrong since flaming and smoldering soot got different sigma values in eb63f390 (2018-02-28).

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Use the soot density:

```diff
--- a/Source/CFAST/outputspreadsheet.f90
+++ b/Source/CFAST/outputspreadsheet.f90
@@ -904,8 +904,8 @@
             roomptr => roominfo(i)
             if (roomptr%id==device) then
                 if (index(measurement,'Mass')==0) then
-                    ssvalue = roomptr%species_output(layer,soot)
-                    ssvalue = ssvalue*264.6903_eb ! converts converts od to mg/m^3
+                    ! soot density in mg/m3; optical density depends on the soot type
+                    ssvalue = roomptr%species_rho(layer,soot)*1.0e6_eb
                 else
                     ssvalue = roomptr%species_mass(layer,soot)
                 end if
@@ -920,8 +920,8 @@
             roomptr => roominfo(i)
             if (roomptr%id==device) then
                 if (index(measurement,'Mass')==0) then
-                    ssvalue = roomptr%species_output(layer,soot_flaming)
-                    ssvalue = ssvalue*264.6903_eb ! converts converts od to mg/m^3
+                    ! soot density in mg/m3; optical density depends on the soot type
+                    ssvalue = roomptr%species_rho(layer,soot_flaming)*1.0e6_eb
                 else
                     ssvalue = roomptr%species_mass(layer,soot_flaming)
                 end if
@@ -936,8 +936,8 @@
             roomptr => roominfo(i)
             if (roomptr%id==device) then
                 if (index(measurement,'Mass')==0) then
-                    ssvalue = roomptr%species_output(layer,soot_smolder)
-                    ssvalue = ssvalue*264.6903_eb ! converts converts od to mg/m^3
+                    ! soot density in mg/m3; optical density depends on the soot type
+                    ssvalue = roomptr%species_rho(layer,soot_smolder)*1.0e6_eb
                 else
                     ssvalue = roomptr%species_mass(layer,soot_smolder)
                 end if
```

## Impact

- Smoke concentration columns of `_compartments.csv` (not the detector obscuration or `fed_obs`, which read the optical density directly). No V&V case has smoldering soot; for flaming soot with default sigma the fix changes values by 4e-6 relative.
