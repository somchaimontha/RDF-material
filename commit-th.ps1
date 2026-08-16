# ============================================================================
# commit-th.ps1 - commit that avoids Thai mojibake on Windows
#
# Problem: Windows console codepage is 874 (Thai). Running
#   git commit -m "Thai text..."
# sends the text as windows-874 bytes -> git stores those bytes -> commit
# shows as "เธฃเธงเธก..." (garbled) on GitHub.
#
# Usage (from this project folder):
#   Method 1 (recommended, reliable): write the message into a UTF-8 file, then
#       .\commit-th.ps1 -FilePath message.txt
#   Method 2 (only if console shows Thai correctly):
#       .\commit-th.ps1 -Message "summary..."
#
# Both write the message to a temp UTF-8 file and run `git commit -F <file>`,
# so git receives correct UTF-8 bytes instead of console-mangled ones.
# ============================================================================
param(
    [Parameter(Mandatory = $false)]
    [string]$Message,

    [Parameter(Mandatory = $false)]
    [string]$FilePath
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1) Pick the message source: a UTF-8 file wins, else fall back to -Message.
$raw = ''
if ($FilePath) {
    $full = $FilePath
    if (-not [System.IO.Path]::IsPathRooted($full)) { $full = Join-Path $repo $FilePath }
    if (-not (Test-Path $full)) { throw "msg file not found: $full" }
    # Read explicitly as UTF-8, independent of console encoding.
    $raw = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
} elseif ($Message) {
    $raw = $Message
} else {
    throw 'specify -FilePath or -Message'
}

# 2) Write the message to a temp UTF-8 file (no BOM) as the commit source.
$tmp = Join-Path $env:TEMP ('rdf_commit_' + [guid]::NewGuid().ToString('N') + '.txt')
try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $raw = $raw.TrimEnd() + [Environment]::NewLine
    [System.IO.File]::WriteAllText($tmp, $raw, $utf8NoBom)

    # 3) Commit using the file so git gets clean UTF-8 bytes.
    git -C $repo commit -F $tmp
    if ($LASTEXITCODE -ne 0) { throw "git commit failed (exit $LASTEXITCODE)" }

    # 4) Verify it was stored correctly (read back).
    $saved = git -C $repo -c core.quotepath=false log -1 --pretty=%B
    $first = $saved | Select-Object -First 1
    Write-Host ("OK - committed: " + $first)
} finally {
    if (Test-Path $tmp) { Remove-Item $tmp -Force }
}