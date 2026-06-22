# --- Configuration ---
$VMHostOrIP        = "10.140.223.50" 
$GuestUser         = "rmassey"
$PlainTextPassword = "VMware1!23456" 

# Build standard PSCredential object safely
$SecurePassword = $PlainTextPassword | ConvertTo-SecureString -AsPlainText -Force
$GuestCreds     = New-Object System.Management.Automation.PSCredential($GuestUser, $SecurePassword)

# --- Prerequisites Check ---
if (-not (Get-Module -ListAvailable Posh-SSH)) {
    Write-Host "Posh-SSH module not found. Installing it now..." -ForegroundColor Yellow
    Install-Module -Name Posh-SSH -Force -AllowClobber -Scope CurrentUser
}

# --- The Bash Script to Inject ---
# The `-replace "`r", ""` at the very end strips out invisible Windows line endings 
# so that the Linux Bash interpreter doesn't throw syntax errors.
$BashScript = @"
# 1. Disable Wayland
echo '$PlainTextPassword' | sudo -S sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf

# 2. Setup GDM Profile
echo '$PlainTextPassword' | sudo -S mkdir -p /etc/dconf/profile
echo -e "user-db:user\nsystem-db:gdm\nfile-db:/usr/share/gdm/greeter-dconf-defaults" > /tmp/gdm-profile
echo '$PlainTextPassword' | sudo -S mv /tmp/gdm-profile /etc/dconf/profile/gdm

# 3. Setup Prevent Blanking Policy
echo '$PlainTextPassword' | sudo -S mkdir -p /etc/dconf/db/gdm.d
echo -e "[org/gnome/desktop/session]\nidle-delay=uint32 0\n\n[org/gnome/desktop/screensaver]\nlock-enabled=false" > /tmp/01-prevent-blanking
echo '$PlainTextPassword' | sudo -S mv /tmp/01-prevent-blanking /etc/dconf/db/gdm.d/01-prevent-blanking

# 4. Update dconf database
echo '$PlainTextPassword' | sudo -S dconf update

# 5. Artificially launch a DBUS session to apply gsettings over SSH
# Check if dbus-x11 is installed, and install it silently if missing
if ! command -v dbus-launch &> /dev/null; then
    echo '$PlainTextPassword' | sudo -S apt-get update -qq
    echo '$PlainTextPassword' | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y dbus-x11 -qq
fi

export XDG_RUNTIME_DIR="/run/user/`$(id -u)"
dbus-launch gsettings set org.gnome.desktop.session idle-delay 0
dbus-launch gsettings set org.gnome.desktop.screensaver lock-enabled false

# 6. Restart GDM3
echo '$PlainTextPassword' | sudo -S systemctl restart gdm3
"@ -replace "`r", ""

# --- Execute via SSH ---
Write-Host "Connecting via SSH and executing configuration on $VMHostOrIP..." -ForegroundColor Cyan

try {
    # Open the SSH session using the universal -Force switch
    $Session = New-SSHSession -ComputerName $VMHostOrIP -Credential $GuestCreds -Force
    
    # Run the sanitized Bash script block with a 5-minute (300 seconds) timeout
    $Result = Invoke-SSHCommand -SessionId $Session.SessionId -Command $BashScript -Timeout 300
    
    # Print execution outputs to the console
    if ($Result.Output) { Write-Host $Result.Output -ForegroundColor Gray }
    if ($Result.Error) { Write-Warning $Result.Error }

    Write-Host "Done! GDM3 has been reconfigured and restarted via SSH." -ForegroundColor Green
}
catch {
    Write-Error "SSH Execution failed: $_"
}
finally {
    # Clean up and close the SSH session silently
    if ($Session) { Remove-SSHSession -SessionId $Session.SessionId | Out-Null }
}