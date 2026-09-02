Monitor Orientation Toggle
===========================

What this does
---------------
Double-clicking the shortcut/button flips the SECOND monitor only, between its
normal portrait setup and landscape (for watching shows), and back again.
Nothing else on the PC is touched: not the primary monitor, resolution,
refresh rate, arrangement, or scaling.

Full background/design notes are in "macro for amima.md" in the repo this
folder came from.

One-time setup on her PC
-------------------------
1. Download MultiMonitorTool (portable, no installer) from the official
   NirSoft page:
       https://www.nirsoft.net/utils/multi_monitor_tool.html
	https://www.nirsoft.net/utils/multimonitortool.zip
   Get the .zip, extract "MultiMonitorTool.exe", and place it directly in
   this same folder, next to the .ps1 and .bat files.

2. The script auto-detects the second monitor by picking whichever connected
   display has the LOWEST resolution (by pixel count) - no device name needed
   in the normal case. To confirm it picks the right one (and to check the
   real portrait orientation value), open PowerShell in this folder and run:

       powershell -ExecutionPolicy Bypass -File ".\Toggle-SecondMonitorOrientation.ps1" -ListMonitors

   (Most PCs block .ps1 files from running directly - the -ExecutionPolicy
   Bypass part works around that for just this one command, without changing
   any system-wide setting. If you see a red "running scripts is disabled on
   this system" error, that's why - use the command above instead of
   ".\Toggle-SecondMonitorOrientation.ps1 -ListMonitors".)

   A popup will list every detected display with its device name (e.g.
   "\\.\DISPLAY2"), current orientation in degrees, whether it's the primary
   display, and its pixel count. Note the device name and current orientation
   of the physical second monitor (the lower pixel-count one).

3. Open "Toggle-SecondMonitorOrientation.ps1" in Notepad and edit:

       $PortraitOrientation   her monitor's normal orientation: 90 or 270
       $LandscapeOrientation  usually 0 (leave as-is unless it looks wrong)

   Save the file. Leave $TargetDisplay blank unless both monitors share the
   same resolution (auto-detect can't tell them apart) - in that case, set it
   to the device name from step 2, e.g. \\.\DISPLAY2.

4. Test it: run the .bat file once by double-clicking
   "Toggle Second Monitor Orientation.bat". The second monitor should flip
   to landscape. Run it again - it should return to the original portrait
   orientation (not upside-down). If nothing happens or you get an error
   popup, see Troubleshooting below.

5. Create a desktop shortcut: right-click
   "Toggle Second Monitor Orientation.bat" -> Show more options -> Send to
   -> Desktop (create shortcut). Using "Send to" (rather than copying the
   .bat itself) keeps the shortcut's target path correct no matter where
   this folder ends up on her PC. Rename the desktop shortcut to whatever's
   friendliest, e.g. "Flip Monitor".

   Optional: right-click the new desktop shortcut -> Properties -> Change
   Icon, to give it a recognizable picture.

That's it - the desktop shortcut is the button amima clicks.

Optional: global keyboard shortcut (e.g. Ctrl+Alt+=)
-------------------------------------------------------
Makes the toggle run from anywhere with a key combo, no need to see the
desktop or click anything. Uses Ctrl+Alt+= as the example here since it's
unlikely to already be claimed by Windows or another app - pick any letter
or symbol key that isn't already in use.

1. The shortcut MUST live on the Desktop (or in a Start Menu folder) for
   Windows to honor its hotkey - it silently does nothing anywhere else
   (e.g. left inside this project folder). If you made the desktop shortcut
   in step 5 above, it's already in the right place.

2. Right-click the desktop shortcut -> Properties -> Shortcut tab -> click
   into the "Shortcut key" field -> press "=". Windows fills in
   "Ctrl + Alt + =" (it always forces Ctrl+Alt as the base combo; hold Shift
   too while pressing the key if you want Ctrl+Alt+Shift+<key> instead, e.g.
   to dodge a conflict). Click Apply, then OK.

3. IMPORTANT: on the same Properties dialog, check the "Advanced..." button
   (Shortcut tab) and make sure "Run as administrator" is UNCHECKED. If it's
   checked, every run triggers a "Do you want to allow this app to make
   changes to your device?" UAC prompt - the toggle doesn't need admin
   rights, so this should stay off.

4. Test: click on empty desktop space (so nothing else has focus), then
   press Ctrl+Alt+=. The monitor should flip with no popups. If a "Windows
   protected your PC" or "Open File - Security Warning" popup appears
   instead, MultiMonitorTool.exe (or another file in this folder) still has
   Windows' "downloaded from the internet" flag on it - run this once in
   PowerShell to clear it (only affects this one file, not any system-wide
   setting):

       Unblock-File -Path ".\MultiMonitorTool.exe"

Dry run / checking without changing anything
----------------------------------------------
   powershell -ExecutionPolicy Bypass -File ".\Toggle-SecondMonitorOrientation.ps1" -DryRun
Shows what it WOULD do without actually changing the orientation. Useful
after editing the config values in step 3.

Troubleshooting
-----------------
- "running scripts is disabled on this system" / "UnauthorizedAccess" - you
  ran the .ps1 directly. Use the -ExecutionPolicy Bypass command shown in
  step 2 instead (this is expected on most PCs and is not something to fix
  system-wide).
- "MultiMonitorTool.exe was not found" - it wasn't placed in this folder, or
  was renamed. Re-check step 1.
- "The target monitor was not found" - the monitor is disconnected/asleep,
  or $TargetDisplay no longer matches. Re-run with -ListMonitors and update
  the config value.
- "Multiple monitors share the lowest resolution" - auto-detect can't tell
  the monitors apart because they're the same resolution. Set $TargetDisplay
  manually to the device name from -ListMonitors.
- Nothing visibly changes - re-check $PortraitOrientation and
  $LandscapeOrientation match what -ListMonitors reported for that monitor's
  two real states.
- A console window flashes briefly - normal, this is PowerShell starting up;
  it closes itself and does not stay open.
- The keyboard shortcut does nothing - the shortcut file isn't on the
  Desktop/Start Menu (Windows only honors hotkeys from there), or another
  app already grabbed that combo (try a different key). Full-screen games
  can also swallow the combo before Windows sees it - test on the desktop
  first, outside any game.
- "Do you want to allow this app to make changes to your device?" (UAC) on
  every run - the shortcut's "Run as administrator" got checked. Properties
  -> Advanced... -> uncheck it.
- "Windows protected your PC" / "Open File - Security Warning" popup on
  every run - a file in this folder still has the internet "Mark of the
  Web" flag from being downloaded. Run
  Unblock-File -Path ".\MultiMonitorTool.exe" once (per-file fix, no
  system-wide setting changes).

Do not use
------------
DisplaySwitch.exe or Ctrl+Alt+Arrow - neither reliably targets a single
secondary monitor's orientation the way this script needs.
