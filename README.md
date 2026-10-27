# Windows computer monitoring updater

This public repository contains the updater and its instructions only. Enrollment ZIPs and computer-specific download codes are issued privately; never commit or upload them here.

## Install or refresh one computer

1. Install Git for Windows and open PowerShell as Administrator.
2. Get the computer name (`use_N`) and its private download code from the administrator. The script downloads the ZIP directly; do not copy ZIPs from another computer.
3. Refresh the local helper repository:

   Existing clone:

   ```powershell
   git -C "$env:USERPROFILE\Documents\tempZip" pull --ff-only
   ```

   First-time clone:

   ```powershell
   git clone --depth 1 https://github.com/amiradamov/tempZip.git "$env:USERPROFILE\Documents\tempZip"
   ```

4. Copy the updater out of the folder it will replace:

   ```powershell
   Copy-Item "$env:USERPROFILE\Documents\tempZip\update-monitoring-agent.ps1" "$env:USERPROFILE\Downloads\update-monitoring-agent.ps1" -Force
   ```

5. Run it with that computer's assigned name, for example:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\update-monitoring-agent.ps1" -Name use_30
   ```

The script securely prompts for the private code, downloads only that computer's ZIP over HTTPS, replaces the old local clone with a shallow clone, extracts the ZIP under `Documents\tempZip\use_N`, verifies the assigned computer name, and runs the installer. Tokens are sent in the HTTPS request body and are not saved by the script. Never share a computer's code or use another computer's package.
