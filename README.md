# Windows computer monitoring updater

This public repository contains the updater and its instructions only. Per-computer enrollment ZIPs contain private keys and are delivered separately; never commit or upload them here.

## Install or refresh one computer

1. Install Git for Windows and open PowerShell as Administrator.
2. Obtain the matching `use_N.zip` privately from the administrator and save it in Downloads.
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

The script replaces the old local clone with a shallow clone, extracts the ZIP from Downloads under `Documents\tempZip\use_N`, verifies its assigned computer name, and runs the installer. The ZIP must match the computer; it is not stored in this repository.
