# --- Configuration ---
$vCenterServer = "vc.551aee9c52c94651bf961c.westus.avs.azure.com"
$VMName        = "rmlinux-01"

# Guest OS Credentials (Must have sudo rights)
$GuestUser     = "rmassey"
$GuestPassword = "VMware1!123456" | ConvertTo-SecureString -AsPlainText -Force
$GuestCreds    = New-Object System.Management.Automation.PSCredential($GuestUser, $GuestPassword)

# --- Connect to vCenter ---
Connect-VIServer -Server $vCenterServer

# --- The Bash Script to Inject ---
# We use a HERE-string to pass all the Linux commands in one go.
$BashScript = @"
#!/bin/bash

# 1. Disable Wayland in GDM3 config
sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf

# 2. Create the GDM dconf profile
sudo mkdir -p /etc/dconf/profile
echo -e "user-db:user\nsystem-db:gdm\nfile-db:/usr/share/gdm/greeter-dconf-defaults" | sudo tee /etc/dconf/profile/gdm > /dev/null

# 3. Create the dconf settings file to disable idle timeout
sudo mkdir -p /etc/dconf/db/gdm.d
echo -e "[org/gnome/desktop/session]\nidle-delay=uint32 0\n\n[org/gnome/desktop/screensaver]\nlock-enabled=false" | sudo tee /etc/dconf/db/gdm.d/01-prevent-blanking > /dev/null

# 4. Update the system configuration database
sudo dconf update

# 5. Apply the same idle settings to the local user account running this script
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false

# 6. Restart GDM3 to apply all changes
sudo systemctl restart gdm3
"@

# --- Execute on the VM ---
Write-Host "Injecting configuration into $VMName..." -ForegroundColor Cyan

Invoke-VMScript -VM $VMName `
                -ScriptType Bash `
                -ScriptText $BashScript `
                -GuestCredential $GuestCreds

Write-Host "Done! GDM3 has been reconfigured and restarted." -ForegroundColor Green

# --- Disconnect ---
Disconnect-VIServer -Server $vCenterServer -Confirm:$false