param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Release',
    [switch]$Smoke,
    [switch]$Launch
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Run this script on Windows with Visual Studio C++, Windows SDK and CMake.'
}
$root = Split-Path $PSScriptRoot -Parent
$cmake = Get-Command cmake -ErrorAction SilentlyContinue
if (-not $cmake) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($installation) {
            $candidate = Join-Path $installation 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
            if (Test-Path $candidate) { $cmake = Get-Item $candidate }
        }
    }
}
if (-not $cmake) { throw 'Install Visual Studio 2022 or newer with Desktop development with C++ and C++ CMake tools for Windows.' }
$cmakePath = if ($cmake -is [System.Management.Automation.CommandInfo]) { $cmake.Source } else { $cmake.FullName }
$ctest = Join-Path (Split-Path $cmakePath -Parent) 'ctest.exe'
$build = Join-Path $root 'build-native'
$stage = Join-Path $root 'dist-native\Snow'
function Invoke-Native([string]$Tool, [string[]]$Arguments) {
    & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Tool failed with exit code $LASTEXITCODE." }
}
Invoke-Native $cmakePath @('-S', $root, '-B', $build, '-A', 'x64')
Invoke-Native $cmakePath @('--build', $build, '--config', $Configuration, '--parallel')
Invoke-Native $ctest @('--test-dir', $build, '-C', $Configuration, '--output-on-failure')
Invoke-Native $cmakePath @('--install', $build, '--config', $Configuration, '--prefix', $stage)
$executable = Join-Path $stage 'Snow.exe'
if ($Smoke) { & (Join-Path $PSScriptRoot 'Test-Windows.ps1') -Executable $executable }
Write-Host "Built and tested: $executable"
if ($Launch) { Start-Process -FilePath $executable -ArgumentList '--settings' }
