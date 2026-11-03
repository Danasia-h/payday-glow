param([string]$OutputDirectory = "", [switch]$SkipTests)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root "dist/PaydayGlow-Windows-x64" }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (-not $SkipTests) {
    dotnet run --project "$PSScriptRoot/PaydayGlow.Tests/PaydayGlow.Tests.csproj" -c Release
    if ($LASTEXITCODE -ne 0) { throw "Windows calculation tests failed" }
}
dotnet publish "$PSScriptRoot/PaydayGlow.Windows/PaydayGlow.Windows.csproj" -c Release -r win-x64 --self-contained true -o "$root/build/windows-publish"
if ($LASTEXITCODE -ne 0) { throw "Windows publish failed" }
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
Copy-Item "$root/build/windows-publish/PaydayGlow.exe" $OutputDirectory -Force
Copy-Item "$PSScriptRoot/README-Windows.txt" "$OutputDirectory/开始使用.txt" -Force
Copy-Item "$PSScriptRoot/THIRD-PARTY-NOTICES.txt" $OutputDirectory -Force
Copy-Item "$root/docs/licenses/*.TXT" $OutputDirectory -Force
# Bundle the exact runtime notices and license from the restored runtime packages.
$nuget = if ($env:NUGET_PACKAGES) { $env:NUGET_PACKAGES } else { Join-Path $env:USERPROFILE ".nuget/packages" }
foreach ($name in @("microsoft.netcore.app.runtime.win-x64", "microsoft.windowsdesktop.app.runtime.win-x64")) {
    $package = Join-Path $nuget $name
    if (Test-Path $package) {
        $version = Get-ChildItem $package -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        foreach ($file in @("LICENSE.TXT", "THIRD-PARTY-NOTICES.TXT")) {
            $notice = Get-ChildItem $version.FullName -Recurse -File | Where-Object Name -IEQ $file | Select-Object -First 1
            if ($notice) { Copy-Item $notice.FullName (Join-Path $OutputDirectory "$name-$file") -Force }
        }
    }
}
$exe = Get-Item "$OutputDirectory/PaydayGlow.exe"
Write-Host "Portable EXE: $($exe.FullName) ($([Math]::Round($exe.Length / 1MB, 1)) MB)"
