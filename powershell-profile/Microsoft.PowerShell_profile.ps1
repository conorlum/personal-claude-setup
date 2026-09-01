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

# Builds the latest CatBnB Unity playtest player and force-pushes it to
# the public conorlum/catbnb-playtest repo. The build/push logic lives in
# bash (cygpath, powershell.exe calls) so this just shells out to it.
function buildcats {
    # Explicit path, not just "bash": on this machine PATH resolves the bare
    # name to the WSL launcher stub in WindowsApps ahead of Git's bash.exe.
    & "C:\Program Files\Git\bin\bash.exe" "$HOME\Documents\GitHub\CatBnB\scripts\ship_playtest_build.sh"
}

# Wraps cswap.exe to add a usage-pace delta to cswap list/cswap ls, then a
# combined block underneath that pools every account into one set of numbers.
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

        # "<account number>|<window>" -> the "resets ... in ..." tail exactly as
        # cswap.exe printed it. The combined block reuses one of these verbatim
        # rather than recomputing a clock that lands a minute off the rows above.
        $resetTails = @{}

        # Bold neon blue for the active account so it is unmissable.
        $esc = [char]27
        $activeStyle = "$esc[1;38;2;0;229;255m"
        $boldStyle = "$esc[1m"
        $dimStyle = "$esc[2m"
        $styleReset = "$esc[0m"

        # How far into the window we are, as a percentage. $null when the window
        # carries no reset timestamp to measure elapsed time against.
        function Get-ElapsedPct($Account, $Window) {
            $usage = $Account.usage.$Window
            if (-not $usage) { return $null }
            if (-not ($usage.PSObject.Properties.Name -contains 'resetsAt')) { return $null }
            $seconds = $windowSeconds[$Window]
            $fetchedAt = [DateTimeOffset]::Parse($Account.usageFetchedAt)
            $remaining = ([DateTimeOffset]::Parse($usage.resetsAt) - $fetchedAt).TotalSeconds
            $elapsed = [math]::Max(0, $seconds - $remaining)
            [math]::Min(100, [math]::Max(0, ($elapsed / $seconds) * 100))
        }

        function Write-PaceSuffix($Delta) {
            $sign = if ($Delta -ge 0) { '+' } else { '' }
            $label = if ($Delta -ge 0) { 'use more' } else { 'slow down' }
            $color = if ($Delta -ge 0) { 'Green' } else { 'Red' }
            Write-Host ("   pace: {0}{1:N1}%  ({2})" -f $sign, $Delta, $label) -ForegroundColor $color
        }

        # Every account pooled into one row per window. The accounts hold
        # equal-sized quotas, so the share of the total that is spent is the
        # mean of their percentages, and averaging their elapsed-time figures
        # the same way gives what that share should be by now. Their windows
        # reset on staggered clocks, so the row shows the soonest of them.
        function Write-CombinedBlock {
            $rows = @()
            foreach ($window in 'fiveHour', 'sevenDay') {
                $parts = @()
                foreach ($acc in $data.accounts) {
                    $elapsedPct = Get-ElapsedPct $acc $window
                    if ($null -eq $elapsedPct) { continue }
                    $usage = $acc.usage.$window
                    $key = "$($acc.number)|$window"
                    if ($resetTails.ContainsKey($key)) {
                        # A trailing "<middot> 3m ago" marks one account's usage
                        # data as stale, which says nothing about a row that
                        # stands for all of them, so drop it here.
                        $tail = $resetTails[$key] -replace "\s+$([char]0xB7)\s.*$", ''
                    } else {
                        $tail = 'resets {0}in {1}' -f ([string]$usage.clock).PadRight(14), $usage.countdown
                    }
                    $parts += [pscustomobject]@{
                        Pct         = [double]$usage.pct
                        ExpectedPct = $elapsedPct
                        ResetsAt    = [DateTimeOffset]::Parse($usage.resetsAt)
                        Tail        = $tail
                    }
                }
                # With one account there is nothing to combine; the row above it
                # already says the same thing.
                if ($parts.Count -lt 2) { continue }
                $label = if ($window -eq 'fiveHour') { '5h' } else { '7d' }
                $usedPct = ($parts | Measure-Object Pct -Average).Average
                $duePct = ($parts | Measure-Object ExpectedPct -Average).Average
                $rows += [pscustomobject]@{
                    Label    = $label
                    Pct      = $usedPct
                    Delta    = $duePct - $usedPct
                    Tail     = ($parts | Sort-Object ResetsAt | Select-Object -First 1).Tail
                    Accounts = $parts.Count
                }
            }
            if ($rows.Count -eq 0) { return }

            # Box-drawing chars as escapes, not literals, so this profile stays
            # plain ASCII on disk and does not ride on how PowerShell decodes it.
            $tee = [char]0x251C
            $elbow = [char]0x2514
            $n = ($rows | Measure-Object Accounts -Maximum).Maximum
            Write-Host "$boldStyle  ALL: $n accounts combined$styleReset$dimStyle  (average usage, soonest reset)$styleReset"
            for ($i = 0; $i -lt $rows.Count; $i++) {
                $branch = if ($i -eq $rows.Count - 1) { $elbow } else { $tee }
                $row = $rows[$i]
                Write-Host ("     {0} {1}:{2,4:N0}%   {3}" -f $branch, $row.Label, $row.Pct, $row.Tail) -NoNewline
                Write-PaceSuffix $row.Delta
            }
            Write-Host ''
        }

        $seenAccount = $false
        $combinedWritten = $false

        foreach ($line in $textLines) {
            # The accounts section runs until the next unindented heading, and
            # the combined block belongs directly under the last account.
            if ($seenAccount -and -not $combinedWritten -and $line -match '^\S') {
                Write-CombinedBlock
                $combinedWritten = $true
            }

            if ($line -match '^\s+(\d+):\s') {
                $currentAcc = $accountsByNum[[int]$Matches[1]]
                $seenAccount = $true
                if ($line -match '(active)') {
                    Write-Host "$activeStyle$line$styleReset"
                } else {
                    Write-Host $line
                }
                continue
            }

            $window = $null
            if ($line -match '5h:\s+([\d.]+)%') { $window = 'fiveHour' }
            elseif ($line -match '7d:\s+([\d.]+)%') { $window = 'sevenDay' }

            if ($window -and $currentAcc) {
                if ($line -match '(resets\s.*?)\s*$') {
                    $resetTails["$($currentAcc.number)|$window"] = $Matches[1]
                }
                $expectedPct = Get-ElapsedPct $currentAcc $window
                if ($null -ne $expectedPct) {
                    Write-Host $line -NoNewline
                    Write-PaceSuffix ($expectedPct - [double]$currentAcc.usage.$window.pct)
                    continue
                }
            }

            Write-Host $line
        }

        if ($seenAccount -and -not $combinedWritten) { Write-CombinedBlock }

        [Console]::OutputEncoding = $prevEncoding
        return
    }

    & cswap.exe @CmdArgs
}
