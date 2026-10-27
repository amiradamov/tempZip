# Windows computer monitoring updater

This repository contains the updater and instructions. Enrollment ZIPs stay on Contabo and are transferred over authenticated SFTP.

## Install or refresh one computer

For installation without login prompts, use the administrator's private `run-monitoring-private.ps1` launcher. Change only its `$Name`, then paste the complete block into Administrator PowerShell. It supplies the download-account password automatically, downloads this public updater, and runs it. The launcher contains a credential and must never be committed or shared publicly.

The automatic transfer downloads the official PuTTY PSCP 0.85 executable, checks its publisher signature, pins the Contabo SSH host key, and supplies the password through a temporary protected file. Temporary transfer files and the process password variable are removed. Git for Windows is required; OpenSSH is needed only for the manual-login alternative below.

For a manual login:

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

Both methods download one bundle containing all 34 ZIPs from Contabo, verify the filenames and selected enrollment, refresh the existing `Documents\tempZip` Git clone, place all ZIPs in that folder, and install only the selected computer. No separate download code, Git pull, ZIP copy, or extraction is required.

The updater refuses to delete a redirected or non-repository `tempZip` folder. Download and installation errors stop the script. The original folder is replaced only after the bundle passes validation.

The `monitoring-download` account is restricted to read-only SFTP inside its download folder. It cannot open a shell or forward ports. Passwords and ZIPs must stay out of Git; downloaded ZIPs and extracted enrollment folders are ignored.
