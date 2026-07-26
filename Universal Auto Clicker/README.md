# Universal Auto Click

A GUI-based AutoHotkey v2 tool for automating mouse clicks and keyboard inputs on any window — including windows running in the background, without needing them to be in focus.

---

## Requirements

- [AutoHotkey v2](https://www.autohotkey.com/) installed

---

## Features

- Sends mouse clicks and keyboard inputs to any window, even if it's not in focus
- Optionally hide the target window while automation runs
- Action queue — chain multiple actions in sequence, each with its own delay
- Loop mode — repeat the entire action queue continuously with a configurable interval
- Trigger via any hotkey combination; press the same hotkey again to stop the loop
- Detects your currently active window on startup and auto-selects it
- Refresh button to update the window list without restarting the script
- Supports light and dark mode automatically based on your Windows theme

---

## How to Use

### 1. Target Window
Select the application you want to automate from the dropdown. The window that was active when you launched the script is pre-selected. Use the **↺** button to refresh the list if you opened a new application after the script started.

Optionally check **Hide window from screen while running** to keep the target window invisible during automation.

### 2. Add Action
Build a sequence of actions to be executed:

**Step A — Pick Coordinate**
Click **Pick Coordinate [Click]**, then click anywhere inside the target window. The coordinates are recorded relative to the window's client area, so they remain accurate even if the window is moved.

**Step B — Action Type**
- **Mouse Click** — performs a left, right, or middle click at the picked coordinate
- **Keyboard / Send** — sends a key or key combination using AHK `ControlSend` syntax (e.g. `{Enter}`, `{F5}`, `hello world`)

Set the **Sleep after action** value (in milliseconds) to control how long to wait before the next action in the queue.

Click **+ Add Action to Queue** to add the action.

### 3. Action Queue
The queue shows all actions in order. You can:
- Click a row to load its sleep value into the edit field
- Adjust the sleep and click **Update Sleep** to change it
- **Remove Selected** to delete one action
- **Clear All** to reset the entire queue

### 4. Trigger Hotkey
Click inside the hotkey field and press any key combination to set the trigger (e.g. `F6`, `Ctrl+F9`).

**Loop** — when checked, the queue repeats continuously after each trigger. Set the **Interval between loops** (ms) to add a pause between each full cycle.

### Start / Stop
- Click **START — Activate Hotkey** to register the hotkey and begin listening
- While looping: press the **same hotkey again** to stop, or click **STOP** in the GUI
- The hotkey is global — it works regardless of which application is in focus

---

## Action Syntax (Keyboard)

Uses AutoHotkey `ControlSend` syntax:

| Input | Result |
|---|---|
| `hello` | Types the text "hello" |
| `{Enter}` | Presses Enter |
| `{F5}` | Presses F5 |
| `^c` | Ctrl+C |
| `^{Home}` | Ctrl+Home |
| `+{Tab}` | Shift+Tab |
| `!{F4}` | Alt+F4 |

---

## Notes

- Actions use `ControlClick` and `ControlSend` — they work on background windows without moving your actual mouse cursor
- Coordinates are in the target window's **client coordinate space**, so they stay consistent across window positions and screen resolutions
- If the target window is closed while a loop is running, the loop stops automatically

## Important

- may in some condition is bugging.

