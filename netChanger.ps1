# Load Windows Forms assembly
Add-Type -AssemblyName System.Windows.Forms

# Create form
$form = New-Object System.Windows.Forms.Form
$form.Text = "netChanger"
$form.Size = New-Object System.Drawing.Size(700, 340)  # Increased height
$form.StartPosition = "CenterScreen"

# Create controls
$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh"
$btnRefresh.Location = New-Object System.Drawing.Point(10, 10)
$btnRefresh.Size = New-Object System.Drawing.Size(240, 30)
$btnRefresh.Add_Click({
    Refresh-NetworkInterface
})

$listBoxInterfaces = New-Object System.Windows.Forms.ListBox
$listBoxInterfaces.Location = New-Object System.Drawing.Point(10, 50)
$listBoxInterfaces.Size = New-Object System.Drawing.Size(240, 200)
$listBoxInterfaces.Add_SelectedIndexChanged({
    Get-SelectedInterfaceInfo
})

$textBoxInfo = New-Object System.Windows.Forms.TextBox
$textBoxInfo.Location = New-Object System.Drawing.Point(260, 50)
$textBoxInfo.Size = New-Object System.Drawing.Size(420, 200)
$textBoxInfo.Multiline = $true
$textBoxInfo.ReadOnly = $true

$btnCaptureCurrentIPv4 = New-Object System.Windows.Forms.Button
$btnCaptureCurrentIPv4.Text = "Capture Current IPv4"
$btnCaptureCurrentIPv4.Location = New-Object System.Drawing.Point(10, 260)
$btnCaptureCurrentIPv4.Size = New-Object System.Drawing.Size(240, 30)
$btnCaptureCurrentIPv4.Add_Click({
    Capture-Current-IPv4
})

$btnCaptureIPtoSet = New-Object System.Windows.Forms.Button
$btnCaptureIPtoSet.Text = "Capture to Set"
$btnCaptureIPtoSet.Location = New-Object System.Drawing.Point(260, 260)
$btnCaptureIPtoSet.Size = New-Object System.Drawing.Size(420, 30)  # Adjusted width
$btnCaptureIPtoSet.Enabled = $false
$btnCaptureIPtoSet.Add_Click({
    Set-Captured-IP
})

$btnSetDhcpLinkLocal = New-Object System.Windows.Forms.Button
$btnSetDhcpLinkLocal.Text = "Set IP to Dynamic"
$btnSetDhcpLinkLocal.Location = New-Object System.Drawing.Point(10, 300)  # Adjusted location
$btnSetDhcpLinkLocal.Size = New-Object System.Drawing.Size(670, 30)  # Full width
$btnSetDhcpLinkLocal.Add_Click({
    Set-DHCP-LinkLocal-IP
})
$btnSetLinkLocal = New-Object System.Windows.Forms.Button
$btnSetLinkLocal.Text = "Set to Force Link Local"
$btnSetLinkLocal.Location = New-Object System.Drawing.Point(10, 340)  # Adjusted location
$btnSetLinkLocal.Size = New-Object System.Drawing.Size(670, 30)  # Adjusted width
$btnSetLinkLocal.Add_Click({
    Set-LinkLocal-IP
})
# Function to set the DHCP and Link Local IP for the selected interface
function Set-DHCP-LinkLocal-IP {
    $selectedInterface = $listBoxInterfaces.SelectedItem

    if ($selectedInterface -ne $null) {
        Write-Host "Setting DHCP IP for $($selectedInterface)"

        # Set DHCP IP for the selected interface using Netsh
        try {
            netsh interface ipv4 set address name=$selectedInterface source=dhcp
            [Windows.Forms.MessageBox]::Show("DHCP IP set successfully for: $($selectedInterface)", "DHCP IP Set")
        } catch {
            Write-Host "Error setting DHCP IP: $_"
            [Windows.Forms.MessageBox]::Show("Failed to set DHCP IP. Check for errors.", "DHCP IP Set Error")
        }

        # Refresh the displayed information after setting the DHCP/Link Local IP
        Get-SelectedInterfaceInfo
    }
}

# Function to refresh network interfaces
function Refresh-NetworkInterface {
    $interfaces = Get-NetAdapter

    $listBoxInterfaces.Items.Clear()
    foreach ($interface in $interfaces) {
        $interfaceAlias = $interface.InterfaceAlias
        if (-not [string]::IsNullOrEmpty($interfaceAlias)) {
            $listBoxInterfaces.Items.Add($interfaceAlias)
        }
    }
}

# Function to get selected interface info
function Get-SelectedInterfaceInfo {
    $selectedInterface = $listBoxInterfaces.SelectedItem

    if ($selectedInterface) {
        $interfaceInfo = Get-NetAdapter | Where-Object { $_.InterfaceAlias -eq $selectedInterface }

        $infoText = "Interface: $($interfaceInfo.InterfaceAlias)`r`n"
        $infoText += "Status: $($interfaceInfo.Status)`r`n"
        
        # Retrieve IPv4 and IPv6 addresses using Get-NetIPAddress
        $ipv4Addresses = (Get-NetIPAddress -InterfaceAlias $selectedInterface -AddressFamily IPv4).IPAddress
        $ipv4SubnetMask = (Get-NetIPAddress -InterfaceAlias $selectedInterface -AddressFamily IPv4).PrefixLength
        
        $ipv6Addresses = (Get-NetIPAddress -InterfaceAlias $selectedInterface -AddressFamily IPv6).IPAddress
        
        $infoText += "IPv4 Addresses: $($ipv4Addresses -join ', ')`r`n"
        $infoText += "IPv4 Subnet Mask: $ipv4SubnetMask`r`n"
        $infoText += "IPv6 Addresses: $($ipv6Addresses -join ', ')`r`n"
        
        # Check internet connection status
        $internetConnection = Test-Connection -ComputerName "www.google.com" -Count 2 -Quiet
        $internetStatus = if ($internetConnection) { "Connected" } else { "Disconnected" }
        $infoText += "Internet Connection: $internetStatus`r`n"
        
        $infoText += "MAC Address: $($interfaceInfo.MacAddress)"

        $textBoxInfo.Text = $infoText

        # Enable the "Capture to Set" button when an interface is selected
        $btnCaptureIPtoSet.Enabled = $true

        # Set the text of the "Capture to Set" button to display the captured IP
        if ($CapturedIPs.ContainsKey($selectedInterface)) {
            $btnCaptureIPtoSet.Text = "Set IP to $($CapturedIPs[$selectedInterface])"
        } else {
            $btnCaptureIPtoSet.Text = "Capture to Set"
        }
    }
}

# Function to capture the current IPv4 of the selected interface
function Capture-Current-IPv4 {
    $selectedInterface = $listBoxInterfaces.SelectedItem

    if ($selectedInterface) {
        $currentIPv4 = (Get-NetIPAddress -InterfaceAlias $selectedInterface -AddressFamily IPv4).IPAddress
        Write-Host "Captured current IPv4 for $($selectedInterface): $($currentIPv4)"

        # Store the captured IPv4 in a variable unique to the adapter
        $CapturedIPs[$selectedInterface] = $currentIPv4

        # Update the label of the "Capture to Set" button
        $btnCaptureIPtoSet.Text = "Set IP to $currentIPv4"
    }
}

# Function to set the captured IP using Netsh
function Set-Captured-IP {
    $selectedInterface = $listBoxInterfaces.SelectedItem

    if ($selectedInterface -ne $null -and $CapturedIPs.ContainsKey($selectedInterface)) {
        $capturedIP = $CapturedIPs[$selectedInterface]
        Write-Host "Setting IP for $($selectedInterface): $($capturedIP)"

        # Set the captured IP for the selected interface using Netsh
        try {
            netsh interface ipv4 set address name=$selectedInterface static $capturedIP 255.255.255.0
            [Windows.Forms.MessageBox]::Show("IP set successfully to: $($capturedIP)", "IP Set")
        } catch {
            Write-Host "Error setting IP: $_"
            [Windows.Forms.MessageBox]::Show("Failed to set IP. Check the provided IP address.", "IP Set Error")
        }

        # Refresh the displayed information after setting the IP
        Get-SelectedInterfaceInfo
    }
}
# Function to set the IPv4 address of the selected interface to Link Local
function Set-LinkLocal-IP {
    $selectedInterface = $listBoxInterfaces.SelectedItem

    if ($selectedInterface -ne $null) {
        Write-Host "Setting Link Local IP for $($selectedInterface)"

        # Set the Link Local IP for the selected interface using Netsh
        try {
            netsh interface ipv4 set address name=$selectedInterface source=static address=169.254.138.138 mask=255.255.0.0
            [Windows.Forms.MessageBox]::Show("Link Local IP set successfully for: $($selectedInterface)", "Link Local IP Set")
        } catch {
            Write-Host "Error setting Link Local IP: $_"
            [Windows.Forms.MessageBox]::Show("Failed to set Link Local IP. Check for errors.", "Link Local IP Set Error")
        }

        # Refresh the displayed information after setting the Link Local IP
        Get-SelectedInterfaceInfo
		    }
}
# Function to set a random Link Local IPv4 address for the selected interface
function Set-RandomLinkLocal-IP {
    $selectedInterface = $listBoxInterfaces.SelectedItem

    if ($selectedInterface -ne $null) {
        Write-Host "Setting Random Link Local IP for $($selectedInterface)"

        # Generate a random Link Local IP address
        $randomIp = "169.254.{0}.{1}" -f (Get-Random -Minimum 1 -Maximum 255), (Get-Random -Minimum 1 -Maximum 255)

        # Set the Link Local IP for the selected interface using Netsh
        try {
            netsh interface ipv4 set address name=$selectedInterface source=static address=$randomIp mask=255.255.0.0
            [Windows.Forms.MessageBox]::Show("Link Local IP set successfully for: $($selectedInterface)`nIP Address: $($randomIp)", "Link Local IP Set")
        } catch {
            Write-Host "Error setting Link Local IP: $_"
            [Windows.Forms.MessageBox]::Show("Failed to set Link Local IP. Check for errors.", "Link Local IP Set Error")
        }

        # Refresh the displayed information after setting the Link Local IP
        Get-SelectedInterfaceInfo
    }
}

# Hash table to store captured IPs
$CapturedIPs = @{}

# Add controls to form
$form.Controls.Add($btnRefresh)
$form.Controls.Add($listBoxInterfaces)
$form.Controls.Add($textBoxInfo)
$form.Controls.Add($btnCaptureCurrentIPv4)
$form.Controls.Add($btnCaptureIPtoSet)
$form.Controls.Add($btnSetLinkLocal)
$form.Controls.Add($btnSetDhcpLinkLocal)

# Set form event handler
$form.Add_Shown({
    Refresh-NetworkInterface
})

# Display the form
[Windows.Forms.Application]::Run($form)
