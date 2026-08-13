<#
  Toggles a single monitor between its normal portrait orientation and landscape,
  using NirSoft MultiMonitorTool. Only touches $TargetDisplay - no other monitor,
  resolution, refresh rate, arrangement, or scaling is changed.

  First-time setup: run this once with -ListMonitors to find the correct
  $TargetDisplay value and current orientation for this PC, then fill in the
  config block below. See README.txt for the full walkthrough.
#>

param(
    [switch]$ListMonitors,
    [switch]$DryRun
)

# ---------------- Configuration (edit these for this PC) ----------------
# Device name MultiMonitorTool uses for the target display, e.g. "\\.\DISPLAY2".
# Run this script with -ListMonitors to find the correct value - do not guess.
$TargetDisplay = '\\.\DISPLAY2'

# This display's normal (non-landscape) orientation, in degrees: 90 or 270.
$PortraitOrientation = 90

# The landscape orientation to switch to, in degrees. Normally 0.
$LandscapeOrientation = 0
# ---------------------------------------------------------------------------

$ToolPath = Join-Path $PSScriptRoot 'MultiMonitorTool.exe'

function Show-ErrorBox([string]$Message) {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    [System.Windows.Forms.MessageBox]::Show(
        $Message, 'Monitor Orientation Toggle',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Show-InfoBox([string]$Message, [string]$Title = 'Monitor Orientation Toggle') {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    [System.Windows.Forms.MessageBox]::Show(
        $Message, $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

if (-not (Test-Path -LiteralPath $ToolPath)) {
    Show-ErrorBox "MultiMonitorTool.exe was not found next to this script:`n$ToolPath`n`nDownload it from nirsoft.net and place it in this folder."
    exit 1
}

# Find the property on an Import-Csv row whose header name matches a pattern,
# since MultiMonitorTool's exact column names/casing aren't guaranteed here.
function Get-FieldLike($Row, [string]$Pattern) {
    $prop = $Row.PSObject.Properties | Where-Object { $_.Name -match $Pattern } | Select-Object -First 1
    if ($prop) { return $prop.Value }
    return $null
}

function Get-MonitorRows {
    $csvPath = Join-Path $env:TEMP 'mmt-monitors.csv'
    & $ToolPath /scomma $csvPath | Out-Null
    Start-Sleep -Milliseconds 300
    if (-not (Test-Path -LiteralPath $csvPath)) {
        throw "MultiMonitorTool did not produce a monitor list ($csvPath)."
    }
    $rows = Import-Csv -LiteralPath $csvPath
    Remove-Item -LiteralPath $csvPath -ErrorAction SilentlyContinue
    return $rows
}

if ($ListMonitors) {
    try {
        $rows = Get-MonitorRows
    } catch {
        Show-ErrorBox "Could not read the monitor list:`n$($_.Exception.Message)"
        exit 1
    }
    $lines = foreach ($row in $rows) {
        $name   = Get-FieldLike $row 'Device.*Name|^Name$'
        $orient = Get-FieldLike $row 'Orientation'
        $prim   = Get-FieldLike $row 'Primary'
        "$name`t orientation=$orient`t primary=$prim"
    }
    $text = ($lines -join "`r`n")
    Show-InfoBox "Copy the device name of the target monitor into `$TargetDisplay in this script.`n`n$text" 'Detected Monitors'
    exit 0
}

try {
    $rows = Get-MonitorRows
} catch {
    Show-ErrorBox "Could not read the monitor list:`n$($_.Exception.Message)"
    exit 1
}

$target = $rows | Where-Object { (Get-FieldLike $_ 'Device.*Name|^Name$') -eq $TargetDisplay } | Select-Object -First 1

if (-not $target) {
    Show-ErrorBox "The target monitor ($TargetDisplay) was not found.`n`nIt may be disconnected, or the device name changed. Run this script with -ListMonitors to check."
    exit 1
}

$currentOrientation = [int](Get-FieldLike $target 'Orientation')

if ($currentOrientation -eq 0 -or $currentOrientation -eq 180) {
    $newOrientation = $PortraitOrientation
} else {
    $newOrientation = $LandscapeOrientation
}

if ($DryRun) {
    Show-InfoBox "[Dry run] Would change $TargetDisplay from $currentOrientation to $newOrientation degrees. No change made."
    exit 0
}

& $ToolPath /SetOrientation $TargetDisplay $newOrientation
