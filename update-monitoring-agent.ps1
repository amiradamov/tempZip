#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^use_(?:[1-9]|[12][0-9]|3[0-4])$')]
    [string] $Name
)

$ErrorActionPreference = 'Stop'
$documents = [Environment]::GetFolderPath('MyDocuments')
$repo = [IO.Path]::GetFullPath((Join-Path $documents 'tempZip')).TrimEnd('\')
$downloads = Join-Path $env:USERPROFILE 'Downloads'
$zip = Join-Path $downloads "$Name.zip"
$stateRoot = Join-Path $env:ProgramData 'ComputerMonitoring'
$tokenCache = Join-Path $stateRoot 'download-code.json'

function Read-PrivateDownloadCode {
    $secureToken = Read-Host -Prompt "Enter the private download code for $Name" -AsSecureString
    $tokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    try {
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenPointer)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPointer)
    }
}

function Download-AssignedPackage([string] $DownloadCode) {
    $body = @{ name = $Name; token = $DownloadCode } | ConvertTo-Json -Compress
    try {
        Invoke-WebRequest -Uri 'https://167.86.96.175/enrollment-download.php' `
            -Method Post -ContentType 'application/json' -Body $body -OutFile $zip -UseBasicParsing | Out-Null
    } catch {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        throw
    }
}

$token = $null
if (Test-Path -LiteralPath $tokenCache -PathType Leaf) {
    $saved = Get-Content -LiteralPath $tokenCache -Raw | ConvertFrom-Json
    if ($saved.Name -ne $Name -or $saved.Token -notmatch '^[a-f0-9]{64}$') {
        throw "Saved download code does not belong to $Name."
    }
    $token = [string]$saved.Token
    try {
        Download-AssignedPackage $token
    } catch {
        $response = $_.Exception.Response
        $status = if ($response -and $response.StatusCode) { [int]$response.StatusCode } else { 0 }
        if ($status -ne 403) { throw 'Secure package download failed. Check the server connection.' }
        Write-Warning 'The saved code was rejected. Enter the current code to refresh it.'
        Remove-Item -LiteralPath $tokenCache -Force
        $token = Read-PrivateDownloadCode
        Download-AssignedPackage $token
    }
} else {
    $token = Read-PrivateDownloadCode
    try {
        Download-AssignedPackage $token
    } catch {
        throw 'Secure package download failed. Check the code and server connection.'
    }
}

if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    throw 'Git for Windows is required to clone the repository.'
}

if (Test-Path -LiteralPath $repo) {
    $existing = Get-Item -LiteralPath $repo -Force
    if (($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        -not (Test-Path -LiteralPath (Join-Path $repo '.git'))) {
        throw "Refusing to remove this non-repository or redirected path: $repo"
    }
    Remove-Item -LiteralPath $repo -Recurse -Force
}

& git.exe clone --depth 1 'https://github.com/amiradamov/tempZip.git' $repo
if ($LASTEXITCODE -ne 0) { throw 'Could not clone the latest tempZip repository.' }

$folder = Join-Path $repo $Name
Expand-Archive -LiteralPath $zip -DestinationPath $folder -Force
$enrollment = Get-Content -LiteralPath (Join-Path $folder 'enrollment.json') -Raw | ConvertFrom-Json
if ($enrollment.DisplayName -ne $Name) {
    throw "The ZIP is for $($enrollment.DisplayName), not $Name. Do not run the installer."
}

Set-Location -LiteralPath $folder
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\install.ps1'
if ($LASTEXITCODE -ne 0) { throw 'The monitoring installer did not complete successfully.' }

New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
$cacheJson = @{ Name = $Name; Token = $token } | ConvertTo-Json -Compress
[IO.File]::WriteAllText($tokenCache, $cacheJson + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$aclArgs = @($tokenCache, '/inheritance:r', '/grant:r', '*S-1-5-18:F', '*S-1-5-32-544:F')
& icacls.exe @aclArgs | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not protect the saved download code.' }
$token = $null
$cacheJson = $null
