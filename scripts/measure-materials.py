#!/usr/bin/env python3
"""54-second controlled CPU/RSS comparison; not a GPU/energy acceptance test."""
import json
import pathlib
import statistics
import subprocess
import time

root = pathlib.Path(__file__).resolve().parent.parent
log = root / "build/logs/material-frames-0.2.8.json"
stderr = root / "build/logs/material-resources-0.2.8.stderr"
samples = [[], [], []]
with log.open("w") as output, stderr.open("w") as errors:
    process = subprocess.Popen([str(root / "build/Release/Snow.app/Contents/MacOS/Snow"), "--material-lab"], stdout=output, stderr=errors)
    start = time.monotonic()
    previous = None
    try:
        while process.poll() is None:
            result = subprocess.run(["/bin/ps", "-p", str(process.pid), "-o", "time=", "-o", "rss="], capture_output=True, text=True).stdout.split()
            now = time.monotonic()
            elapsed = now - start
            phase = int(elapsed // 18)
            if len(result) == 2:
                cpu = sum(float(v) * 60 ** i for i, v in enumerate(reversed(result[0].split(":"))))
                if previous and phase < 3 and 4 <= elapsed % 18 <= 16:
                    samples[phase].append(((cpu - previous[1]) / (now - previous[0]) * 100, int(result[1]) / 1024))
                previous = now, cpu
            if elapsed > 75:
                raise TimeoutError("Material fixture did not finish")
            time.sleep(0.5)
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)

phases = []
for i, values in enumerate(samples):
    phases.append({"appearance": "textured" if i == 1 else "simple", "samples": len(values),
                   "cpu_mean_percent_one_core": round(statistics.mean(x[0] for x in values), 2) if values else None,
                   "rss_peak_mib": round(max(x[1] for x in values), 2) if values else None})
print(json.dumps({"duration_seconds": round(time.monotonic() - start, 2), "exit_code": process.returncode,
                  "method": "ps CPU time deltas / monotonic wall time; RSS; same production scene, 9 windows + floor + 3 snowmen, 30 Hz",
                  "phases": phases}, indent=2))
