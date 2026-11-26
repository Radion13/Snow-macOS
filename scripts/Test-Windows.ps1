param(
    [string]$Executable = "$PSScriptRoot\..\dist-native\Snow\Snow.exe",
    [string]$OutputDirectory = "$PSScriptRoot\..\build\diagnostics",
    [ValidateRange(5, 120)][int]$TimeoutSeconds = 30
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Run native lifecycle diagnostics on Windows.'
}
$Executable = (Resolve-Path $Executable).Path
$directory = Join-Path $OutputDirectory ("SnowSmoke-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
New-Item -ItemType Directory -Path $directory | Out-Null
$output = Join-Path $directory 'result.json'
$errors = Join-Path $directory 'stderr.txt'
try {
    $process = Start-Process -FilePath $Executable -WorkingDirectory (Split-Path $Executable -Parent) -ArgumentList '--smoke-test' -PassThru -RedirectStandardOutput $output -RedirectStandardError $errors
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) { $process.Kill(); $process.WaitForExit(); throw 'Smoke test timed out.' }
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "Snow exited with code $($process.ExitCode)." }
    $text = Get-Content -Raw $output
    if (-not $text) { throw 'No diagnostics returned. Close an already running Snow instance first.' }
    $result = $text | ConvertFrom-Json
    if ($null -eq $result -or $result -isnot [pscustomobject]) { throw 'Expected a diagnostics JSON object.' }
    $properties = @($result.PSObject.Properties)
    if ($properties.Count -eq 0) { throw 'Diagnostics returned no checks.' }
    $failed = @($properties | Where-Object { $_.Value -isnot [bool] -or -not $_.Value })
    if ($failed.Count) { throw ("Failed: " + ($failed.Name -join ', ')) }
    Write-Host ("Passed {0} Windows lifecycle checks." -f $properties.Count)
    $text
} finally {
    Write-Host "Logs: $directory"
}
