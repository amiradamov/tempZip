# Windows computer monitoring updater

This public repository contains the updater and its instructions only. Enrollment ZIPs and computer-specific download codes are issued privately; never commit or upload them here.

## Install or refresh one computer

1. Install Git for Windows and open PowerShell as Administrator.
2. Get the computer name (`use_N`) and its private download code from the administrator.
3. Run this block, changing `use_30` to the assigned computer name:

   ```powershell
   $Name = 'use_30'
   $Updater = Join-Path "$env:USERPROFILE\Downloads" 'update-monitoring-agent.ps1'
   Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/amiradamov/tempZip/main/update-monitoring-agent.ps1' -OutFile $Updater
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Updater -Name $Name
   ```

No separate `git pull` is needed. The command downloads the current updater directly. On first install, it securely prompts for the private code, downloads only that computer's ZIP over HTTPS, replaces the old local clone with a shallow clone, verifies the assigned computer name, and runs the installer. After a successful install, the code is saved with Windows permissions limited to SYSTEM and Administrators; future runs for that same `use_N` reuse it without prompting. Never share a computer's code or use another computer's package.
