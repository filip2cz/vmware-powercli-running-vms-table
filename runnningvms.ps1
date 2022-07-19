# You need to connect to server first with this command:
# connect-viserver [adress] -User [user] -Password [password] -Force
# something like connect-viserver 192.168.1.50 -User administrator@vsphere.local -Password 12345 -Force

$date_current = Get-Date -Format "dd.MM.yyyy HH:mm:ss"

$Report = @()
$VMs = Get-VM | Where {$_.PowerState -eq "PoweredOn"}
$Datastores = Get-Datastore | Select Name, Id
$PowerOnEvents = Get-VIEvent -Entity $VMs -MaxSamples ([int]::MaxValue) | where {$_ -is [VMware.Vim.VmPoweredOnEvent]} | Group-Object -Property {$_.Vm.Name}
foreach ($VM in $VMs) {
    $lastPO = ($PowerOnEvents | Where { $_.Group[0].Vm.Vm -eq $VM.Id }).Group | Sort-Object -Property CreatedTime -Descending | Select -First 1
    $row = "" | select VMName,Powerstate,PoweredOnTime,OS,Host,Cluster,Datastore,NumCPU,MemMb,DiskGb,PoweredOnBy
    $row.VMName = $vm.Name
    #$RunningTime = (Get-Date -Format "dd.MM.yyyy HH:mm:ss").AddDays(-1).ToString("dd.MM.yyyy HH:mm:ss")
    $row.Powerstate = $vm.Powerstate
    if($lastPO.CreatedTime -eq $null) {
        $row.PoweredOnTime = "empty"
    }
    else {
        $row.PoweredOnTime = $lastPO.CreatedTime
    }
    $row.OS = $vm.Guest.OSFullName
    $row.Host = $vm.VMHost.name
    $row.Cluster = $vm.VMHost.Parent.Name
    $row.Datastore = $Datastores | Where{$_.Id -eq ($vm.DatastoreIdList | select -First 1)} | Select -ExpandProperty Name
    $row.NumCPU = $vm.NumCPU
    $row.MemMb = $vm.MemoryMB
    $row.DiskGb = Get-HardDisk -VM $vm | Measure-Object -Property CapacityGB -Sum | select -ExpandProperty Sum
    $row.PoweredOnBy   = $lastPO.UserName
    $report += $row
}

# Output to screen
$report | Sort PoweredOnTime, Cluster, Host, VMName | Select VMName, Cluster, Host, NumCPU, MemMb, @{N='DiskGb';E={[math]::Round($_.DiskGb,2)}}, PoweredOnTime, PoweredOnBy | ft -a

# Output to CSV - change path/filename as appropriate
$report | Sort PoweredOnTime, Cluster, Host, VMName | Export-Csv -Path "C:\Users\$env:UserName\Desktop\Powered_On_VMs.csv" -NoTypeInformation -UseCulture