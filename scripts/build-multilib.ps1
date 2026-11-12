param(
    [string]$Source = "x265/source",
    [string]$BuildRoot = "x265/build",
    [switch]$DisableAssembly
)
$ErrorActionPreference = "Stop"
$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$buildPath = [IO.Path]::GetFullPath($BuildRoot)
$main10 = Join-Path $buildPath "windows-x64-10bit"
$main8 = Join-Path $buildPath "windows-x64"
$assembly = if ($DisableAssembly) { "OFF" } else { "ON" }
function Invoke-Native([string]$File, [string[]]$Arguments) {
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$File failed ($LASTEXITCODE)." }
}
# Build a namespaced 10-bit static library, then link it into the 8-bit CLI.
Invoke-Native cmake @("-S", $sourcePath, "-B", $main10, "-G", "Visual Studio 17 2022", "-A", "x64",
    "-DHIGH_BIT_DEPTH=ON", "-DMAIN12=OFF", "-DEXPORT_C_API=OFF", "-DENABLE_CLI=OFF",
    "-DENABLE_SHARED=OFF", "-DENABLE_ASSEMBLY=$assembly")
Invoke-Native cmake @("--build", $main10, "--config", "Release", "--target", "x265-static", "--parallel", "4")
$library = (Join-Path $main10 "Release/x265-static.lib").Replace('\', '/')
if (-not (Test-Path -LiteralPath $library)) { throw "10-bit static library is missing: $library" }
Invoke-Native cmake @("-S", $sourcePath, "-B", $main8, "-G", "Visual Studio 17 2022", "-A", "x64",
    "-DHIGH_BIT_DEPTH=OFF", "-DEXPORT_C_API=ON", "-DENABLE_CLI=ON", "-DENABLE_SHARED=OFF",
    "-DENABLE_ASSEMBLY=$assembly", "-DLINKED_10BIT=ON", "-DEXTRA_LIB=$library")
Invoke-Native cmake @("--build", $main8, "--config", "Release", "--target", "cli", "--parallel", "4")
