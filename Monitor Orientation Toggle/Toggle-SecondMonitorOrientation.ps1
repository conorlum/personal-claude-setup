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
# Leave blank to auto-detect: the script picks the connected monitor with the
# LOWEST resolution (by pixel count), since the second monitor is smaller than
# the primary. Only set this if auto-detect picks the wrong monitor (e.g. both
# monitors share the same resolution) - run -ListMonitors to find the value.
$TargetDisplay = ''

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

# MultiMonitorTool's /scomma export reports orientation as text ("Default",
# "90 Degrees", "180 Degrees", "270 Degrees"), not a bare number.
function ConvertTo-OrientationDegrees([string]$Text) {
    if ($Text -match '(\d+)') { return [int]$Matches[1] }
    return 0
}

# Returns width*height in pixels for a monitor row, or $null if it can't be
# determined. Tries dedicated Width/Height columns first, then falls back to
# parsing a combined "Resolution" column like "1920x1080".
function Get-PixelArea($Row) {
    $width  = Get-FieldLike $Row '^Width$|Screen.*Width|Resolution.*Width'
    $height = Get-FieldLike $Row '^Height$|Screen.*Height|Resolution.*Height'
    if ($width -match '^\d+$' -and $height -match '^\d+$') {
        return [int]$width * [int]$height
    }
    $resolution = Get-FieldLike $Row 'Resolution'
    if ($resolution -match '(\d+)\s*x\s*(\d+)') {
        return [int]$Matches[1] * [int]$Matches[2]
    }
    return $null
}

# Picks the device name of the connected monitor with the lowest resolution.
function Get-AutoTargetDisplay($Rows) {
    $candidates = foreach ($row in $Rows) {
        $area = Get-PixelArea $row
        if ($null -ne $area) {
            [PSCustomObject]@{
                Name = Get-FieldLike $row 'Device.*Name|^Name$'
                Area = $area
            }
        }
    }
    if (-not $candidates) {
        throw "Could not read resolution for any monitor - set `$TargetDisplay manually."
    }
    $sorted = $candidates | Sort-Object Area
    if ($sorted.Count -gt 1 -and $sorted[0].Area -eq $sorted[1].Area) {
        throw "Multiple monitors share the lowest resolution ($($sorted[0].Area) px) - set `$TargetDisplay manually to disambiguate."
    }
    return $sorted[0].Name
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
        $area   = Get-PixelArea $row
        "$name`t orientation=$orient`t primary=$prim`t pixels=$area"
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

$resolvedTargetDisplay = $TargetDisplay
if ([string]::IsNullOrWhiteSpace($resolvedTargetDisplay)) {
    try {
        $resolvedTargetDisplay = Get-AutoTargetDisplay $rows
    } catch {
        Show-ErrorBox "Could not auto-detect the second monitor:`n$($_.Exception.Message)"
        exit 1
    }
}

$target = $rows | Where-Object { (Get-FieldLike $_ 'Device.*Name|^Name$') -eq $resolvedTargetDisplay } | Select-Object -First 1

if (-not $target) {
    Show-ErrorBox "The target monitor ($resolvedTargetDisplay) was not found.`n`nIt may be disconnected, or the device name changed. Run this script with -ListMonitors to check."
    exit 1
}

$currentOrientation = ConvertTo-OrientationDegrees (Get-FieldLike $target 'Orientation')

if ($currentOrientation -eq 0 -or $currentOrientation -eq 180) {
    $newOrientation = $PortraitOrientation
} else {
    $newOrientation = $LandscapeOrientation
}

if ($DryRun) {
    Show-InfoBox "[Dry run] Would change $resolvedTargetDisplay from $currentOrientation to $newOrientation degrees. No change made."
    exit 0
}

& $ToolPath /SetOrientation $resolvedTargetDisplay $newOrientation
