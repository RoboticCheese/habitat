#!/usr/bin/env powershell

#Requires -Version 5
Set-PSDebug -Trace 1

###################
# Functions

# This creates a new path string from the Environment variable
# This is not the same as doing a path.combine
function New-PathString([string]$StartingPath, [string]$Path) {
    if (-not [string]::IsNullOrEmpty($path)) {
        if (-not [string]::IsNullOrEmpty($StartingPath)) {
            [string[]]$PathCollection = "$path;$StartingPath" -split ';'
            $Path = ($PathCollection |
                Select-Object -Unique |
                Where-Object {-not [string]::IsNullOrEmpty($_.trim())} |
                Where-Object {test-path "$_"}
            ) -join ';'
        }
        $path
    }
    else {
        $StartingPath
    }
}


###################
# 'main'
$env:ChocolateyInstall = "$env:ProgramData\Chocolatey"
$ChocolateyHabitatLibDir = "$env:ChocolateyInstall\lib\habitat_native_dependencies\builds\lib"
$ChocolateyHabitatIncludeDir = "$env:ChocolateyInstall\lib\habitat_native_dependencies\builds\include"
$ChocolateyHabitatBinDir = "C:\ProgramData\chocolatey\lib\habitat_native_dependencies\builds\bin"

Write-Host "--- Installing Native Dependencies"
choco install habitat_native_dependencies --confirm -s https://www.myget.org/F/habitat/api/v2  --allowemptychecksums

Write-Host "--- Installing libzmq"
choco install libzmq_vc120 --version 4.2.3 --confirm -s https://www.nuget.org/api/v2/ --allowemptychecksums
Copy-Item $env:ChocolateyInstall\lib\libzmq_vc120\build\native\bin\libzmq-x64-v120-mt-4_2_3_0.imp.lib $ChocolateyHabitatLibDir\zmq.lib -Force
Copy-Item $env:ChocolateyInstall\lib\libzmq_vc120\build\native\bin\libzmq-x64-v120-mt-4_2_3_0.dll $ChocolateyHabitatBinDir\libzmq.dll -Force

Write-Host "--- Installing libsodium"
choco install libsodium_vc120 --version 1.0.12 --confirm -s https://www.nuget.org/api/v2/
Copy-Item $env:ChocolateyInstall\lib\libsodium_vc120\build\native\bin\libsodium-x64-v120-mt-1_0_12_0.imp.lib $ChocolateyHabitatLibDir\sodium.lib -Force
Copy-Item $env:ChocolateyInstall\lib\libsodium_vc120\build\native\bin\libsodium-x64-v120-mt-1_0_12_0.dll $ChocolateyHabitatBinDir\libsodium.dll -Force

$env:PATH                   = New-PathString -StartingPath $env:PATH    -Path 'C:\Program Files\7-Zip'
$env:PATH                   = New-PathString -StartingPath $env:PATH    -Path $ChocolateyHabitatBinDir
$env:LIB                    = New-PathString -StartingPath $env:LIB     -Path $ChocolateyHabitatLibDir
$env:INCLUDE                = New-PathString -StartingPath $env:INCLUDE -Path $ChocolateyHabitatIncludeDir
$env:SODIUM_LIB_DIR         = $ChocolateyHabitatLibDir
$env:LIBARCHIVE_INCLUDE_DIR = $ChocolateyHabitatIncludeDir
$env:LIBARCHIVE_LIB_DIR     = $ChocolateyHabitatLibDir
$env:OPENSSL_LIBS           = 'ssleay32:libeay32'
$env:OPENSSL_LIB_DIR        = $ChocolateyHabitatLibDir
$env:OPENSSL_INCLUDE_DIR    = $ChocolateyHabitatIncludeDir
$env:LIBZMQ_PREFIX          = Split-Path $ChocolateyHabitatLibDir -Parent

Write-Host "--- Moving build folder to new location"
New-Item -ItemType directory -Path C:\build
Copy-Item -Path C:\workdir\* -Destination C:\build -Recurse

Write-Host "--- Running build"
cd C:\build
Invoke-Expression "cargo build --release " -ErrorAction Stop

exit $LASTEXITCODE
