# Windows computer monitoring updater

This repository contains the updater and instructions. Enrollment ZIPs stay on Contabo and are transferred over authenticated SFTP.

## Install or refresh one computer

1. Install Git for Windows and enable the Windows OpenSSH Client (normally already installed).
2. Open PowerShell as Administrator. Run this block, changing `use_30` to the assigned computer name (`use_1` through `use_34`):

   ```powershell
   $Name = 'use_30'
   $Updater = Join-Path (Join-Path $env:USERPROFILE 'Downloads') 'update-monitoring-agent.ps1'
   New-Item -ItemType Directory -Path (Split-Path $Updater) -Force | Out-Null
   Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/amiradamov/tempZip/main/update-monitoring-agent.ps1' -OutFile $Updater
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Updater -Name $Name
   ```

3. At the SSH password prompt, enter the shared `monitoring-download` account password provided by the administrator. It is the same password for all 34 computers. This is a restricted download account.

The updater downloads one bundle containing all 34 ZIPs from Contabo, verifies the filenames and selected enrollment, refreshes the existing `Documents\tempZip` Git clone, places all ZIPs in that folder, and installs only the selected computer. It pins the server's SSH host key, so there is no first-connection host-key confirmation. No separate download code, Git pull, ZIP copy, or extraction is required.

The updater refuses to delete a redirected or non-repository `tempZip` folder. Download and installation errors stop the script. The original folder is replaced only after the bundle passes validation.

The `monitoring-download` account is restricted to read-only SFTP inside its download folder. It cannot open a shell or forward ports. Passwords and ZIPs must stay out of Git; downloaded ZIPs and extracted enrollment folders are ignored.
