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
$zip = Join-Path (Join-Path $env:USERPROFILE 'Downloads') "$Name.zip"

if (-not (Test-Path -LiteralPath $zip -PathType Leaf)) {
    throw "Place the assigned package here first: $zip"
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
