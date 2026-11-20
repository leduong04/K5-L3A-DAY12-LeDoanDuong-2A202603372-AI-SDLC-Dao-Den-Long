# Phase 1 verification record

## Engine and compile checks

Engine: Godot `4.7.2.stable.official.ed1daf0bf` at `/home/leduong/Draft/Godot_v4.7.2-stable_linux.x86_64`.

| Check | Result | Notes |
|---|---|---|
| `"$GODOT" --headless --path . --editor --quit` | **PASS — exit 0** | No GDScript parse/compile errors. Godot printed sandbox environment errors for local socket creation and saving `~/.config/godot/editor_settings-4.7.tres`; raw output is in [editor-compile-output.txt](editor-compile-output.txt). |
| `"$GODOT" --headless --path . --quit-after 3` | **PASS — exit 0** | Main project scene ran for three frames without a script error. This is not a GUI visual check. |
| `export GODOT=...; python3 tests/run_contract.py` | **PASS — 6/6** | Actual output is preserved in `contract-test-output.txt`. The runner now accepts the documented `GODOT` environment variable in addition to `GODOT_BIN`; its assertions and fixtures are unchanged. |
| Launch GUI with `"$GODOT" --path .` | **NOT VERIFIED** | Process reports no X11 display and no Wayland display, then exits; the launch output is preserved in [gui-launch-attempt.txt](gui-launch-attempt.txt). CUA reports no available apps/windows, so interactive GUI input and screenshots cannot be captured in this environment. |

The six headless checks cover deterministic output, tick 0/end records, pickup/deposit/light events, pulse stun, shade hit, and malformed scenario exit code. They verify simulation behavior, not rendered appearance or keyboard controls in the GUI.

## GUI acceptance checklist

| Requirement | Status | Evidence/limitation |
|---|---|---|
| 3D island and camera visible/working | **NOT VERIFIED** | GUI cannot initialize without X11/Wayland. |
| Mây movement and jump via keyboard | **NOT VERIFIED** | Requires interactive GUI. |
| Exactly five large lanterns visible | **NOT VERIFIED** | Not visually inspected. |
| Fireflies visible and collectible | **NOT VERIFIED** | Headless pickup check passed; rendered fireflies not inspected. |
| Carry fireflies to lantern and light it | **NOT VERIFIED** | Headless deposit/light check passed; GUI interaction not tried. |
| Shades visible and chase player | **NOT VERIFIED** | Headless hit behavior passed; visual chase not inspected. |
| Pulse stuns/pushes shades | **NOT VERIFIED** | Headless stun check passed; push distance and visual effect not inspected in GUI. |
| Player loses flames on contact | **NOT VERIFIED** | Headless hit check passed; HUD response not inspected. |
| HUD values are accurate/readable | **NOT VERIFIED** | GUI cannot initialize. |
| Win after all five lanterns are lit | **NOT VERIFIED** | No GUI playthrough or win screenshot. |
| Lose after all flames are lost | **NOT VERIFIED** | No GUI playthrough or loss screenshot. |
| Replay after win/loss | **NOT VERIFIED** | Requires GUI interaction. |

No screenshot is included: none could be captured from a running GUI, and no substitute image was generated.

## README and tuning review

README has two run commands after installing Godot 4.2+, lists controls and scoring, and includes “Sáng tạo của tôi” and links to assumptions. Static comparison against `simulation.gd` found these contract values aligned: player speed 6.0, carry capacity 5, lantern cost 3, pulse cost 1, pulse radius 6.0, starting flames 3, safe radius 4.0, shade speed 2.2, shade hit radius 1.0; score is 10/mote, 100/lit lantern, 15/stunned shade, 1/second left, and 25/flame left on victory.

## Manual GUI check on a desktop

From the project root on a Linux desktop with a working display:

```sh
export GODOT="/home/leduong/Draft/Godot_v4.7.2-stable_linux.x86_64"
"$GODOT" --path .
```

Use `WASD` or arrows to move, `Space` to jump, `E` near a lantern to deposit carried fireflies, `Q` near a shade to pulse, and `R` after the end screen to replay. Confirm the HUD carry count before/after collecting and depositing, observe flames when touched, and light all five lanterns for the win state. Save genuine screenshots of gameplay, a lit lantern, and a terminal state in this directory if reached. None are present yet.
