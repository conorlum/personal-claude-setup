function code { Set-Location "$HOME\Documents\GitHub" }

function matches {
    param([int]$Count = 5)
    & "$HOME\Documents\GitHub\valo-with-friends-tracker\webapp\scripts\refresh_remote.ps1" -Count $Count
}

function reps {
    param([Parameter(Mandatory = $true)][double]$Minutes)
    node "$HOME\Documents\GitHub\NoScrollJustDo\companion-app\request.js" $Minutes
}

function stats {
    node "$HOME\Documents\GitHub\NoScrollJustDo\companion-app\stats.js"
}

# Wraps cswap.exe to add a usage-pace delta to cswap list/cswap ls.
# Pace = (% of the 5h/7d window elapsed) - (% quota used).
# Positive = behind pace, room to use more. Negative = ahead of pace, slow down.
function cswap {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$CmdArgs
    )

    $sub = if ($CmdArgs.Count -gt 0) { $CmdArgs[0] } else { '' }
    $wantsRaw = ($CmdArgs -contains '--json') -or ($CmdArgs -contains '--token-status')

    if ($sub -in @('list', 'ls') -and -not $wantsRaw) {
        # cswap.exe writes UTF-8 (box-drawing chars, bullets); capturing its
        # output into a variable decodes with the console's default codepage
        # unless we force UTF-8 first, which mangles those characters.
        $prevEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

        $data = (& cswap.exe list --json) | ConvertFrom-Json
        $textLines = & cswap.exe @CmdArgs

        $accountsByNum = @{}
        foreach ($acc in $data.accounts) { $accountsByNum[[int]$acc.number] = $acc }
        $currentAcc = $null
        $windowSeconds = @{ fiveHour = 18000; sevenDay = 604800 }

        # Bold neon blue for the active account so it is unmissable.
        $esc = [char]27
        $activeStyle = "$esc[1;38;2;0;229;255m"
        $styleReset = "$esc[0m"

        foreach ($line in $textLines) {
            if ($line -match '^\s(\d+):\s') {
                $currentAcc = $accountsByNum[[int]$Matches[1]]
                if ($line -match '(active)') {
                    Write-Host "$activeStyle$line$styleReset"
                } else {
                    Write-Host $line
                }
                continue
            }

            $window = $null
            if ($line -match '5h:\s([\d.]+)%') { $window = 'fiveHour' }
            elseif ($line -match '7d:\s([\d.]+)%') { $window = 'sevenDay' }

            if ($window -and $currentAcc) {
                $usage = $currentAcc.usage.$window
                $hasReset = $usage.PSObject.Properties.Name -contains 'resetsAt'
                if ($hasReset) {
                    $now = [DateTimeOffset]::Parse($currentAcc.usageFetchedAt)
                    $resetsAt = [DateTimeOffset]::Parse($usage.resetsAt)
                    $seconds = $windowSeconds[$window]
                    $remaining = ($resetsAt - $now).TotalSeconds
                    $elapsed = [math]::Max(0, $seconds - $remaining)
                    $expectedPct = [math]::Min(100, [math]::Max(0, ($elapsed / $seconds) * 100))
                    $delta = $expectedPct - [double]$usage.pct
                    $sign = if ($delta -ge 0) { '+' } else { '' }
                    $label = if ($delta -ge 0) { 'use more' } else { 'slow down' }
                    $color = if ($delta -ge 0) { 'Green' } else { 'Red' }
                    $paceText = "   pace: {0}{1:N1}%  ({2})" -f $sign, $delta, $label
                    Write-Host $line -NoNewline
                    Write-Host $paceText -ForegroundColor $color
                    continue
                }
            }

            Write-Host $line
        }

        [Console]::OutputEncoding = $prevEncoding
        return
    }

    & cswap.exe @CmdArgs
}
