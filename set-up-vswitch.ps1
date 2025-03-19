#create a internal hyper-v swtich to route the taffic with the name "singbox"
New-VMSwitch -Name "singbox" -SwitchType Internal

#Enable IP forwarding on NIC "singbox_tun"
$singboxTun = Get-NetAdapter -Name "singbox_tun" -ErrorAction SilentlyContinue
if ($singboxTun) {
    Set-NetIPInterface -InterfaceAlias "singbox_tun" -Forwarding Enabled
} else {
    Write-Error "Network adapter 'singbox_tun' not found. Make sure it exists before running this script."
    exit 1
}

#Enable IP forwarding on NIC "vEthernet (singbox)"
$vEthernet = Get-NetAdapter -Name "vEthernet (singbox)" -ErrorAction SilentlyContinue
if ($vEthernet) {
    Set-NetIPInterface -InterfaceAlias "vEthernet (singbox)" -Forwarding Enabled
} else {
    Write-Error "Network adapter 'vEthernet (singbox)' not found. The Hyper-V switch may not have been created properly."
    exit 1
}

# Configure NAT to route traffic from VMs through sing-box interface
# Assuming the singbox_tun interface is using a specific subnet
$singboxIp = (Get-NetIPAddress -InterfaceAlias "singbox_tun" -AddressFamily IPv4).IPAddress
$vSwitchIp = (Get-NetIPAddress -InterfaceAlias "vEthernet (singbox)" -AddressFamily IPv4).IPAddress

# Assign an IP address to the internal switch (typically 192.168.x.1)
New-NetIPAddress -InterfaceAlias "vEthernet (singbox)" -IPAddress "192.168.80.1" -PrefixLength 24
$vSwitchIp = "192.168.80.1"

# Create NAT for internal network on the singbox vSwitch
$natName = "SingboxNAT"
$natPrefix = "192.168.80.0/24"  # The subnet used by your VMs

# Remove existing NAT if it exists
$existingNat = Get-NetNat -Name $natName -ErrorAction SilentlyContinue
if ($existingNat) {
    Remove-NetNat -Name $natName -Confirm:$false
}

# Create the NAT
New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix $natPrefix

# Add routes to ensure traffic from VMs is directed through the singbox_tun interface
if ($singboxIp) {
    # Example route - adjust based on your network requirements
    # This routes all internet traffic through singbox_tun
    # May need to be adjusted based on your specific setup
    route add 0.0.0.0 mask 0.0.0.0 $singboxIp metric 1 -p
}

Write-Host "Hyper-V switch 'singbox' setup completed with NAT configuration."