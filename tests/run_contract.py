#!/usr/bin/env python3
"""Execute Phase 1 scenarios against the actual Godot headless runner."""
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures"
GODOT = os.environ.get("GODOT") or os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")


def run(args):
    return subprocess.run([GODOT, "--headless", "--path", str(ROOT), "--script",
                           "res://src/headless.gd", "--", *args], cwd=ROOT,
                          text=True, capture_output=True, check=False)


def read_lines(path):
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    if not GODOT:
        raise SystemExit("Godot 4 executable not found; install Godot 4 or set GODOT_BIN")
    with tempfile.TemporaryDirectory(prefix="dao-den-long-") as temp:
        temp = Path(temp)
        base = ["--seed", "73", "--night", "1", "--ticks", "5", "--snapshot-every", "1"]

        # Same deterministic inputs must produce byte-identical JSONL.
        out1, out2 = temp / "deterministic-1.jsonl", temp / "deterministic-2.jsonl"
        for out in (out1, out2):
            result = run(base + ["--out", str(out)])
            require(result.returncode == 0, result.stderr)
        require(out1.read_bytes() == out2.read_bytes(), "same seed produced different JSONL")
        rows = read_lines(out1)
        require(rows[0]["type"] == "snapshot" and rows[0]["tick"] == 0, "missing initial snapshot")
        require(rows[-1]["type"] == "end" and rows[-1]["ticks"] == 5, "wrong end record")

        pickup = temp / "pickup.jsonl"
        result = run(base + ["--scenario", str(FIXTURES / "pickup_deposit_scenario.json"),
                             "--inputs", str(FIXTURES / "pickup_deposit_inputs.json"), "--out", str(pickup)])
        require(result.returncode == 0, result.stderr)
        rows = read_lines(pickup)
        names = [row["name"] for row in rows if row["type"] == "event"]
        require(names[:3] == ["deposit", "lantern_lit", "mote_picked"], f"unexpected pickup/deposit events: {names}")
        require(any(row.get("lanterns", [{}])[0].get("lit") for row in rows if row["type"] == "snapshot"), "L1 not lit")

        pulse = temp / "pulse.jsonl"
        result = run(base + ["--scenario", str(FIXTURES / "pulse_scenario.json"),
                             "--inputs", str(FIXTURES / "pulse_inputs.json"), "--out", str(pulse)])
        require(result.returncode == 0, result.stderr)
        rows = read_lines(pulse)
        event = next(row for row in rows if row.get("name") == "pulse")
        require(event["data"]["stunned_ids"] == ["ShadeTest"], "pulse did not stun nearby shade")
        snapshot = next(row for row in rows if row.get("type") == "snapshot" and row["tick"] == 1)
        require(snapshot["shades"][0]["state"] == "stunned", "shade snapshot not stunned")

        hit = temp / "hit.jsonl"
        result = run(base + ["--scenario", str(FIXTURES / "hit_scenario.json"), "--out", str(hit)])
        require(result.returncode == 0, result.stderr)
        rows = read_lines(hit)
        hit_event = next(row for row in rows if row.get("name") == "player_hit")
        require(hit_event["data"] == {"by": "shade", "flames": 2, "dropped": 0}, "unexpected hit result")

        bad_json = temp / "bad.json"
        bad_json.write_text("{broken", encoding="utf-8")
        result = run(base + ["--scenario", str(bad_json), "--out", str(temp / "bad-output.jsonl")])
        require(result.returncode == 2, f"invalid scenario returned {result.returncode}, expected 2")

    print("PASS: 6 headless contract checks (determinism, tick/output, pickup+deposit, pulse, hit, invalid JSON)")


if __name__ == "__main__":
    main()
