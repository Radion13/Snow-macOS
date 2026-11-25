#!/usr/bin/env python3
"""65-second sanity check, not acceptance of the 10-minute/1-hour NF budgets.

Measures process CPU time deltas (100% = one core) and ps RSS; excludes warm-up
and the transition to hidden. Run with no other Snow instance running.
"""
import json
import pathlib
import statistics
import subprocess
import time

root = pathlib.Path(__file__).resolve().parent.parent
binary = root / "build/Release/Snow.app/Contents/MacOS/Snow"
process = subprocess.Popen([str(binary), "--resource-check"], stdout=subprocess.DEVNULL)
started = time.monotonic()
samples = {"running": [], "hidden": []}
previous = None


def cpu_seconds(text):
    parts = text.split(":")
    return sum(float(value) * (60 ** index) for index, value in enumerate(reversed(parts)))


try:
    while process.poll() is None:
        output = subprocess.run(["/bin/ps", "-p", str(process.pid), "-o", "time=", "-o", "rss="], capture_output=True, text=True).stdout.strip()
        now = time.monotonic()
        elapsed = now - started
        if output:
            cpu, rss = output.split()
            cpu = cpu_seconds(cpu)
            if previous:
                dt = now - previous[0]
                phase = "running" if 8 <= elapsed <= 32 else ("hidden" if 42 <= elapsed <= 62 else None)
                if phase:
                    samples[phase].append({"cpu": max(0, (cpu - previous[1]) / dt * 100), "rss_mib": int(rss) / 1024, "dt": dt})
            previous = (now, cpu)
        time.sleep(1)
finally:
    if process.poll() is None:
        process.terminate()
        process.wait(timeout=5)

result = {"method": "ps time deltas / monotonic wall time; RSS", "duration_seconds": round(time.monotonic() - started, 2), "exit_code": process.returncode}
for phase, values in samples.items():
    result[phase] = {
        "samples": len(values),
        "cpu_mean_percent_one_core": round(statistics.mean(x["cpu"] for x in values), 2) if values else None,
        "rss_peak_mib": round(max(x["rss_mib"] for x in values), 2) if values else None,
    }
print(json.dumps(result, indent=2))
