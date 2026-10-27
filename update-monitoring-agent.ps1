#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^use_(?:[1-9]|[12][0-9]|3[0-4])$')]
    [string] $Name
)

$ErrorActionPreference = 'Stop'
$downloadPassword = $env:MONITORING_DOWNLOAD_PASSWORD
Remove-Item Env:MONITORING_DOWNLOAD_PASSWORD -ErrorAction SilentlyContinue
if ($downloadPassword -match '[\r\n]') { throw 'Invalid download-account password.' }
$documents = [Environment]::GetFolderPath('MyDocuments')
$repo = [IO.Path]::GetFullPath((Join-Path $documents 'tempZip')).TrimEnd('\')
$downloads = Join-Path $env:USERPROFILE 'Downloads'
$bundle = Join-Path $downloads 'monitoring-enrollments.zip'
$staging = Join-Path $downloads ('monitoring-enrollments-' + [guid]::NewGuid().ToString('N'))

if (-not $downloadPassword -and -not (Get-Command sftp.exe -ErrorAction SilentlyContinue)) {
    throw 'The Windows OpenSSH Client is required. Install it under Windows Optional Features.'
}
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    throw 'Git for Windows is required to clone the repository.'
}

New-Item -ItemType Directory -Path $downloads -Force | Out-Null
try {
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    & icacls.exe $staging /inheritance:r /grant:r ('*' + $currentSid + ':(OI)(CI)F') '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not protect the temporary transfer folder.' }
    $knownHosts = Join-Path $staging 'known_hosts'
    $sshConfig = Join-Path $staging 'ssh_config'
    $batch = Join-Path $staging 'download.sftp'
    $utf8 = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($knownHosts, '167.86.96.175 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEEsgX5EkwBzVNmab1Olplz+Hwg7QZKLQUJHma912u2U' + [Environment]::NewLine, $utf8)
    $sshConfigText = 'Host *' + [Environment]::NewLine + '    UserKnownHostsFile "' + $knownHosts.Replace('\', '/') + '"' + [Environment]::NewLine
    [IO.File]::WriteAllText($sshConfig, $sshConfigText, $utf8)
    $localBundle = $bundle.Replace('\', '/')
    [IO.File]::WriteAllText($batch, ('get /packages/all.zip "' + $localBundle + '"' + [Environment]::NewLine), $utf8)
    if ($downloadPassword) {
        Write-Host 'Downloading the enrollment bundle automatically from Contabo...'
        $pscp = Join-Path $staging 'pscp.exe'
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing 'https://the.earth.li/~sgtatham/putty/0.85/w64/pscp.exe' -OutFile $pscp -TimeoutSec 120
        $signature = Get-AuthenticodeSignature -LiteralPath $pscp
        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch '(^|,\s*)CN=Simon Tatham(,|$)') {
            throw 'The SFTP transfer tool does not have a valid publisher signature.'
        }
        $passwordFile = Join-Path $staging 'transfer-password.txt'
        try {
            [IO.File]::WriteAllText($passwordFile, $downloadPassword + [Environment]::NewLine, $utf8)
            $downloadPassword = $null
            & $pscp -batch -sftp -noagent -hostkey 'SHA256:Rs/VPuTVCbFRUR0iq+90xrqpI3YOWp2tfnN3k1An9wo' -pwfile $passwordFile 'monitoring-download@167.86.96.175:/packages/all.zip' $bundle
            if ($LASTEXITCODE -ne 0) { throw 'Automatic SFTP download failed. Check the private launcher password and server connection.' }
        } finally {
            Remove-Item -LiteralPath $passwordFile -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host 'Connecting to Contabo. Enter the shared monitoring-download password when asked.'
        $sftpArguments = @(
            '-F', $sshConfig, '-oBatchMode=no', '-oStrictHostKeyChecking=yes',
            '-oConnectTimeout=20', '-b', $batch, 'monitoring-download@167.86.96.175'
        )
        & sftp.exe @sftpArguments
        if ($LASTEXITCODE -ne 0) { throw 'SFTP download failed. Check the download-account password and server connection.' }
    }
    Expand-Archive -LiteralPath $bundle -DestinationPath $staging -Force

    $packages = @(Get-ChildItem -LiteralPath $staging -File -Filter '*.zip')
    if ($packages.Count -ne 34) { throw 'The download must contain exactly 34 enrollment ZIPs.' }
    foreach ($number in 1..34) {
        if (-not (Test-Path -LiteralPath (Join-Path $staging "use_$number.zip") -PathType Leaf)) {
            throw "The download is missing use_$number.zip."
        }
    }

    $selected = Join-Path $staging $Name
    Expand-Archive -LiteralPath (Join-Path $staging "$Name.zip") -DestinationPath $selected -Force
    $enrollment = Get-Content -LiteralPath (Join-Path $selected 'enrollment.json') -Raw | ConvertFrom-Json
    if ($enrollment.DisplayName -ne $Name) {
        throw "The ZIP is for $($enrollment.DisplayName), not $Name. Do not run the installer."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $selected 'install.ps1') -PathType Leaf)) {
        throw 'The selected package is missing install.ps1.'
    }

    if (Test-Path -LiteralPath $repo) {
        $existing = Get-Item -LiteralPath $repo -Force
        if (($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
            -not (Test-Path -LiteralPath (Join-Path $repo '.git'))) {
            throw "Refusing to remove this non-repository or redirected path: $repo"
        }
        if ([IO.Directory]::GetParent($repo).FullName.TrimEnd('\') -ne
            [IO.Path]::GetFullPath($documents).TrimEnd('\')) {
            throw "Refusing to remove a path outside Documents: $repo"
        }
        Set-Location -LiteralPath $documents
        Remove-Item -LiteralPath $repo -Recurse -Force
    }

    & git.exe clone --depth 1 'https://github.com/amiradamov/tempZip.git' $repo
    if ($LASTEXITCODE -ne 0) { throw 'Could not clone the latest tempZip repository.' }
    foreach ($package in $packages) {
        Copy-Item -LiteralPath $package.FullName -Destination $repo -Force
    }

    $folder = Join-Path $repo $Name
    Copy-Item -LiteralPath $selected -Destination $folder -Recurse -Force
    Set-Location -LiteralPath $folder
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\install.ps1'
    if ($LASTEXITCODE -ne 0) { throw 'The monitoring installer did not complete successfully.' }
    Write-Host "Installed $Name. All 34 ZIPs are available in $repo."
} finally {
    $downloadPassword = $null
    # The staging path is a unique child of Downloads, never the repository itself.
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $bundle -Force -ErrorAction SilentlyContinue
}
