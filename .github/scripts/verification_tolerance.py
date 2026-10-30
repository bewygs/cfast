"""Summarize the Verification error-tolerance check written by fdsplotlib.scatplot.

Usage: verification_tolerance.py <repo> <figure output dir>

Prints a Markdown report, copies the figures of quantities outside their error tolerance to the output
directory, and exits with 1 when any quantity is out of tolerance or the statistics file is missing.
"""

import csv
import shutil
import sys
from pathlib import Path

repo, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
manuals = repo / 'Manuals' / 'CFAST_Validation_Guide'
stats_file = manuals / 'SCRIPT_FIGURES' / 'Scatterplots' / 'verification_scatterplot_output.csv'

if not stats_file.is_file():
    print('Verification plots could not be made, so no quantity was checked against its tolerance. See plots.log.')
    sys.exit(1)


def num(text):
    """Round a value to four significant digits for display."""
    try:
        return f'{float(text):.4g}'
    except ValueError:
        return text


with open(stats_file, newline='', encoding='utf-8') as f:
    rows = list(csv.DictReader(f))
failed = [r for r in rows if r['Within Specified Error Tolerance'].strip() != 'Yes']
print(f'{len(rows) - len(failed)} of {len(rows)} Verification quantities are within their specified error tolerance.')
if not failed:
    sys.exit(0)

print()
print('| Case | Quantity | Expected | Predicted | Error | Tolerance | Figure |')
print('|---|---|---|---|---|---|---|')
for r in failed:
    print(f"| {r['Case Name']} | {r['Predicted Quantity']} ({r['Dependent Variable']}) | {num(r['Expected Value'])} "
          f"| {num(r['Predicted Value'])} | {num(r['Error'])} ({r['Type of Error'].lower()}) "
          f"| {num(r['Error Tolerance'])} | {Path(r['Plot Filename']).name} |")

# Plot filenames in the inputs do not always match the case of the file on disk.
figures = {p.stem.lower(): p for p in (manuals / 'SCRIPT_FIGURES' / 'Verification').glob('*.pdf')}
out_dir.mkdir(parents=True, exist_ok=True)
for name in sorted({Path(r['Plot Filename']).name.lower() for r in failed}):
    if name in figures:
        shutil.copy2(figures[name], out_dir)
print()
print('The figures of these quantities are attached to the run.')
sys.exit(1)
