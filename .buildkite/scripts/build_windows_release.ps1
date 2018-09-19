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
$Path="."

Write-Host "--- Installing Chocolatey"
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | out-null

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

# We need the Visual C++ tools to build Rust crates (provides a compiler and linker)
Write-Host "--- Installing Visual C++ Tools"
choco install 'visualcppbuildtools' --version '14.0.25123' --confirm --allowemptychecksum

Write-Host "--- Installing 7zip"
choco install 7zip --version '16.02.0.20160811' --confirm

# Install some rust
Write-Host "--- Installing rustup and stable-x86_64-pc-windows-msvc Rust."
invoke-restmethod -usebasicparsing 'https://static.rust-lang.org/rustup/dist/i686-pc-windows-gnu/rustup-init.exe' -outfile 'rustup-init.exe'
./rustup-init.exe -y --no-modify-path
$env:PATH                   = New-PathString -StartingPath $env:PATH    -Path "$env:USERPROFILE\.cargo\bin"
rustup install stable-x86_64-pc-windows-msvc

Write-Host "--- Installing protoc and protobuf"
choco install protoc -y
invoke-expression "cargo install protobuf"

$env:PATH                   = New-PathString -StartingPath $env:PATH    -Path 'C:\Program Files\7-Zip'
$env:PATH                   = New-PathString -StartingPath $env:PATH    -Path $ChocolateyHabitatBinDir
#$env:PATH                   = New-PathString -StartingPath $env:PATH    -Path Env:
$env:LIB                    = New-PathString -StartingPath $env:LIB     -Path $ChocolateyHabitatLibDir
$env:INCLUDE                = New-PathString -StartingPath $env:INCLUDE -Path $ChocolateyHabitatIncludeDir
$env:SODIUM_LIB_DIR         = $ChocolateyHabitatLibDir
$env:LIBARCHIVE_INCLUDE_DIR = $ChocolateyHabitatIncludeDir
$env:LIBARCHIVE_LIB_DIR     = $ChocolateyHabitatLibDir
$env:OPENSSL_LIBS           = 'ssleay32:libeay32'
$env:OPENSSL_LIB_DIR        = $ChocolateyHabitatLibDir
$env:OPENSSL_INCLUDE_DIR    = $ChocolateyHabitatIncludeDir
$env:LIBZMQ_PREFIX          = Split-Path $ChocolateyHabitatLibDir -Parent

Write-Host "--- Downloading cacerts.pem"
$current_protocols = [Net.ServicePointManager]::SecurityProtocol
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri "http://curl.haxx.se/ca/cacert.pem" -OutFile "$env:TEMP\cacert.pem"
}
finally {
    [Net.ServicePointManager]::SecurityProtocol = $current_protocols
}

$env:SSL_CERT_FILE="$env:TEMP\cacert.pem"
$env:PROTOBUF_PREFIX=$env:ChocolateyInstall

# We need to create a new directory since rust has issues with docker mounted filesystems
Write-Host "--- Moving build folder to new location"
New-Item -ItemType directory -Path C:\build
Copy-Item -Path C:\workdir\* -Destination C:\build -Recurse

Write-Host "--- Running build"
cd C:\build
$cargo = "cargo"
Invoke-Expression "RUST_DEBUG=1 $cargo build" -ErrorAction Stop

exit $LASTEXITCODE