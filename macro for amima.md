# Build handoff: second-monitor orientation toggle

## Goal

Build a single clickable Windows shortcut/button that toggles **only the secondary monitor** between its usual portrait orientation and landscape, so the monitor is convenient for watching shows and can be returned to its normal vertical setup just as easily.

The user has limited access to the target PC, but can transfer/copy a small folder and run a setup command or script once.

## Preferred implementation

Use [NirSoft MultiMonitorTool](https://www.nirsoft.net/utils/multi_monitor_tool.html), a portable executable, plus a PowerShell toggle script and a desktop shortcut.

Why this approach:

- No installer, driver, registry edit, scheduled task, or permanently running background app.
- MultiMonitorTool directly supports setting a specific display orientation from the command line.
- It can be kept in one self-contained folder and removed simply by deleting that folder and its shortcut.
- It avoids relying on `Ctrl` + `Alt` + arrow, which is graphics-driver-dependent and commonly unavailable on Windows 11.

Do **not** use `DisplaySwitch.exe`: it changes projection modes, not a specific monitor’s orientation.

## Deliverable layout

Create a folder such as:

```text
Monitor Orientation Toggle/
  MultiMonitorTool.exe
  Toggle-SecondMonitorOrientation.ps1
  Toggle Second Monitor Orientation.lnk
  README.txt
```

The shortcut should run the PowerShell script with a hidden/minimized console, e.g.:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\Monitor Orientation Toggle\Toggle-SecondMonitorOrientation.ps1"
```

Use `-ExecutionPolicy Bypass` only for this one local invocation; do not change the machine-wide policy.

## Discovery/setup requirements

On the target PC, identify the target display using MultiMonitorTool. Its numbering may differ from Windows Settings' visual “2.” Prefer the stable device name (for example, `\\.\DISPLAY2`) if it remains consistent. Record:

- Target display identifier accepted by MultiMonitorTool.
- Current/normal portrait orientation: normally `90` or `270`.
- Desired landscape orientation: normally `0`.
- Any unexpected display behavior (laptop panel, dock, HDR, duplicate display, etc.).

Run MultiMonitorTool interactively once to confirm which entry maps to the physical second monitor. Do not guess.

## Toggle behavior

1. Read the current orientation for the chosen display.
2. If it is landscape (`0` or `180`), set it to the configured normal portrait value (`90` or `270`).
3. If it is portrait (`90` or `270`), set it to landscape (`0`).
4. Show a clear error message if the target monitor is disconnected or cannot be found.
5. Do not modify the primary monitor, resolution, refresh rate, display arrangement, scaling, enabled/disabled state, or projection mode.

Use MultiMonitorTool’s documented orientation command:

```powershell
& $toolPath /SetOrientation $targetDisplay 0
& $toolPath /SetOrientation $targetDisplay 90
```

If querying orientation from its command-line output is brittle, an acceptable alternative is two explicit shortcuts (“Watch mode” and “Work mode”). However, the requested outcome is a **single toggle**, so first attempt state detection.

## Script expectations

- Resolve paths relative to `$PSScriptRoot`; do not hard-code the install folder.
- Keep configuration at the top of the script, with comments for `$TargetDisplay` and `$PortraitOrientation`.
- Quote executable paths and display identifiers safely.
- Use PowerShell only; avoid AutoHotkey unless it adds a concrete benefit.
- Do not require administrator rights.
- Do not leave a console window open on success.
- Use a Windows message box or notification for actionable failures; avoid success popups unless requested.
- Include a `-WhatIf` or `-DryRun` option if practical.

## Important UX notes

- Windows may momentarily redraw/rearrange windows when orientation changes. This is expected.
- If the monitor is physically turned sideways for regular use, its stand and cable slack must accommodate rotating it back for viewing. The script rotates the desktop image only; it does not move the physical monitor.
- Windows may show a confirmation timer when manually changing orientation. Verify whether the command-line operation requires confirmation on the target hardware; the button must not leave the display in an unconfirmed/transient state.

## Verification checklist

- [ ] Clicking the shortcut changes only the intended monitor from portrait to landscape.
- [ ] Clicking it again restores the original portrait direction (not upside-down).
- [ ] Primary monitor remains unchanged.
- [ ] Monitor resolution/refresh/scaling remain unchanged.
- [ ] Script works after sign-in and after a normal reboot.
- [ ] Script fails safely and explains the issue when the target display is disconnected.
- [ ] Shortcut works with a path containing spaces.
- [ ] No administrator elevation or persistent background process is required.

## Handoff questions for the owner, if needed

Ask only if discovery cannot determine them:

1. Which portrait direction is normal: rotated left (`90`) or right (`270`)?
2. Should “watch mode” also move/resize a browser or media app onto that monitor? (Out of scope by default.)
3. Is the desired button a desktop/taskbar shortcut, Stream Deck action, mouse button, or keyboard hotkey? Build the normal Windows shortcut first; those inputs can trigger it later.

## Security/sourcing

Download MultiMonitorTool only from NirSoft’s official website and keep the tool with the script. Its documented `/SetOrientation <Monitor> <0|90|180|270>` capability is the dependency this solution relies on.

