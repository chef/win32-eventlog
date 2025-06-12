   # Windows 11 and above have Remote Event Log Management disabled at the firewall by default.
   # hwre we detect that and enable it if necessary.
   $osInfo = Get-ComputerInfo
   if ($osInfo.OsProductName -like "*Windows Server 2025*") {
        Write-Host "Enabling Remote Event Log Management Firewall Rule for Windows Server 2025"
        Enable-NetFirewallRule -DisplayGroup "Remote Event Log Management"
   } 