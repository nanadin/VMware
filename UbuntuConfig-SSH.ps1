# --- Configuration ---
$VMHostOrIP  = "10.140.223.50" 
$GuestUser     = "rmassey"
$PlainTextPassword = "VMware1!23456" 

# Build standard PSCredential object safely
$SecurePassword = $PlainTextPassword | ConvertTo-SecureString -AsPlainText -Force
$GuestCreds    = New-Object System.Management.Automation.PSCredential($GuestUser, $SecurePassword)

# --- Prerequisites Check ---
if (-not (Get-Module -ListAvailable Posh-SSH)) {
    Write-Host "Posh-SSH module not found. Installing it now..." -ForegroundColor Yellow
    Install-Module -Name Posh-SSH -Force -AllowClobber -Scope CurrentUser
}

# --- The Bash Script to Inject ---
$BashScript = @"
echo '$PlainTextPassword' | sudo -S sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf
echo '$PlainTextPassword' | sudo -S mkdir -p /etc/dconf/profile
echo -e "user-db:user\nsystem-db:gdm\nfile-db:/usr/share/gdm/greeter-dconf-defaults" | echo '$PlainTextPassword' | sudo -S tee /etc/dconf/profile/gdm > /dev/null
echo '$PlainTextPassword' | sudo -S mkdir -p /etc/dconf/db/gdm.d
echo -e "[org/gnome/desktop/session]\nidle-delay=uint32 0\n\n[org/gnome/desktop/screensaver]\nlock-enabled=false" | echo '$PlainTextPassword' | sudo -S tee /etc/dconf/db/gdm.d/01-prevent-blanking > /dev/null
echo '$PlainTextPassword' | sudo -S dconf update

gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false

echo '$PlainTextPassword' | sudo -S systemctl restart gdm3
"@

# --- Execute via SSH ---
Write-Host "Connecting via SSH and executing configuration on $VMHostOrIP..." -ForegroundColor Cyan

try {
    # Swapped version-dependent parameters for the universal -Force switch
    $Session = New-SSHSession -ComputerName $VMHostOrIP -Credential $GuestCreds -Force
    
    # Run the entire Bash block
    $Result = Invoke-SSHCommand -SessionId $Session.SessionId -Command $BashScript
    
    # Print outputs
    if ($Result.Output) { Write-Host $Result.Output -ForegroundColor Gray }
    if ($Result.Error) { Write-Warning $Result.Error }

    Write-Host "Done! GDM3 has been reconfigured and restarted via SSH." -ForegroundColor Green
}
catch {
    Write-Error "SSH Execution failed: $_"
}
finally {
    # Clean up the SSH session
    if ($Session) { Remove-SSHSession -SessionId $Session.SessionId }
}