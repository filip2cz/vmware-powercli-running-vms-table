$script_server = "x"
$script_user = "x"
$script_password = "x"

connect-viserver $script_server -User $script_user -Password $script_password -Force

$date_current = Get-Date -Format "dd.MM.yyyy HH:mm:ss"

$Report = @()
$VMs = Get-VM | Where {$_.PowerState -eq "PoweredOn"}
$Datastores = Get-Datastore | Select Name, Id
$PowerOnEvents = Get-VIEvent -Entity $VMs -MaxSamples ([int]::MaxValue) | where {$_ -is [VMware.Vim.VmPoweredOnEvent]} | Group-Object -Property {$_.Vm.Name}
foreach ($VM in $VMs) {
    $lastPO = ($PowerOnEvents | Where { $_.Group[0].Vm.Vm -eq $VM.Id }).Group | Sort-Object -Property CreatedTime -Descending | Select -First 1
    $row = "" | select VMName,RunningTime,Powerstate,OS,Host,Cluster,Datastore,NumCPU,MemMb,DiskGb,PoweredOnTime,PoweredOnBy
    $row.VMName = $vm.Name
    $RunningTime = (Get-Date -Format "dd.MM.yyyy HH:mm:ss").AddDays(-1).ToString("dd.MM.yyyy HH:mm:ss")
    $row.Powerstate = $vm.Powerstate
    $row.OS = $vm.Guest.OSFullName
    $row.Host = $vm.VMHost.name
    $row.Cluster = $vm.VMHost.Parent.Name
    $row.Datastore = $Datastores | Where{$_.Id -eq ($vm.DatastoreIdList | select -First 1)} | Select -ExpandProperty Name
    $row.NumCPU = $vm.NumCPU
    $row.MemMb = $vm.MemoryMB
    $row.DiskGb = Get-HardDisk -VM $vm | Measure-Object -Property CapacityGB -Sum | select -ExpandProperty Sum
    $row.PoweredOnTime = $lastPO.CreatedTime
    $row.PoweredOnBy   = $lastPO.UserName
    $report += $row
}

# Output to screen
$report | Sort Cluster, Host, VMName | Select VMName, Cluster, Host, NumCPU, MemMb, @{N='DiskGb';E={[math]::Round($_.DiskGb,2)}}, PoweredOnTime, PoweredOnBy | ft -a

# Output to CSV - change path/filename as appropriate
$report | Sort Cluster, Host, VMName | Export-Csv -Path "C:\Users\$env:UserName\Desktop\Powered_On_VMs.csv" -NoTypeInformation -UseCulture