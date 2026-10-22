# Target SURFACE_TEMPERATURE is read in kelvin; the User Guide says Celsius

- **Type:** Wrong result without warning for a user who follows the guide (needs a maintainer decision).
- **Version:** 41798d8 (firemodels/cfast master, 2026-10-16, merge of PR #2590).
- **Audit reference:** A12 in `audit/RAPPORT.md`.

## Summary

`read_devc` copies `SURFACE_TEMPERATURE` without conversion and defaults it to `interior_ambient_temperature` in K (`input_namelist.f90:784, 970`); `target.f90:374-376` uses it in K for the gauge heat flux. The User Guide says "Fixed target surface temperature in C" (`Input_File_Chapter.tex:536`), and every other temperature input is in C. A user who enters 20 gets a 20 K gauge.

## Reproducer

Input file(s): `audit/repro/A12_target_surface_temperature_celsius.in`.

Run with the debug executable built by `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` (gfortran 13.3.0), from the repository root:

```sh
mkdir -p /tmp/run && cp audit/repro/A12_target_surface_temperature_celsius.in /tmp/run/ && cd /tmp/run
<cfast>/Build/CFAST/gnu_linux_db/cfast8_linux_db A12_target_surface_temperature_celsius.in
```

Columns are read in `<case>_compartments.csv`, `<case>_devices.csv` or `<case>_vents.csv` (short names on line 1, data from line 5).

## Observed and expected

`SURFACE_TEMPERATURE = 20` (ambient in C).

| Quantity at 120 s | Expected (same as the default) | Observed (master) | With option (b) |
|---|---|---|---|
| `TRGFLXTG_1` | 12.01 kW/m2 | 15.17 kW/m2 | 12.01 kW/m2 |

## Root cause

The legacy VB CEdit stores temperatures in K and converts `INTERIOR_TEMPERATURE` and `SETPOINT` when writing (`Source/Cedit/IO.vb:2405, 2802`), but writes `SURFACE_TEMPERATURE` unconverted (`IO.vb:3087-3088`). Its files are therefore in K, consistent with the code. CeditQt only preserves the value. No V&V input uses it.

## Proposed fix

Compiled with the repository debug flags (`-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`) without warnings, and checked on the reproducer.

Option (b): convert from C as the guide says:

```diff
--- a/Source/CFAST/input_namelist.f90
+++ b/Source/CFAST/input_namelist.f90
@@ -781,7 +781,7 @@
                 targptr%center = location
                 targptr%normal = normal
                 targptr%surface_orientation = surface_orientation
-                targptr%surface_temperature = surface_temperature
+                targptr%surface_temperature = surface_temperature + kelvin_c_offset
                 
                 targptr%thickness = thickness
 
@@ -967,7 +967,7 @@
     matl_id                         = 'NULL'
     normal(:)                       = (/0., 0., 1./)
     surface_orientation             = "NULL"
-    surface_temperature             = interior_ambient_temperature
+    surface_temperature             = interior_ambient_temperature - kelvin_c_offset
     thickness                       = 0._eb
     rti                             = default_rti
     setpoint                        = -1001._eb
```

## Impact

- Gauge heat flux (`TRGFLXTG` and the `.out`), which is what is compared with water-cooled flux gauges.
- Option (a) is to change the guide to K, which keeps old CEdit files valid.
