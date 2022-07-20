# You need to connect to server first with this command:
# connect-viserver [adress] -User [user] -Password [password] -Force
# something like connect-viserver 192.168.1.50 -User administrator@vsphere.local -Password 12345 -Force

$date_current = Get-Date -Format "dd.MM.yyyy HH:mm:ss" #get current date

$Report = @() #create empty array
$VMs = Get-VM | Where {$_.PowerState -eq "PoweredOn"} #get all powered on VMs
$Datastores = Get-Datastore | Select Name, Id #get all datastores
$PowerOnEvents = Get-VIEvent -Entity $VMs -MaxSamples ([int]::MaxValue) | where {$_ -is [VMware.Vim.VmPoweredOnEvent]} | Group-Object -Property {$_.Vm.Name} #get all power on events
foreach ($VM in $VMs) {
    $tmpdate = $null #clear some variables
    $bettertime = $null #clear some variables
    $morebettertime = $null #clear some variables
    $besttime = $null #clear some variables

    $lastPO = ($PowerOnEvents | Where { $_.Group[0].Vm.Vm -eq $VM.Id }).Group | Sort-Object -Property CreatedTime -Descending | Select -First 1
    $row = "" | select VMName,Powerstate,PoweredOnTime,Cluster,Host,Datastore,OS,NumCPU,MemMb,DiskGb,PoweredOnBy
    $row.VMName = $vm.Name #add VM name
    $row.Powerstate = $vm.Powerstate #add VM powerstate
    if($lastPO.CreatedTime -eq $null) { #if there is no power time in lastPO.CreatedTime variable
        $vmxPath = $vm.ExtensionData.Config.Files.VmpathName #get vmx path
        $dsObj = Get-Datastore -Name $vmxPath.Split(']')[0].TrimStart('[') #get datastore name
        New-PSDrive -Location $dsObj -Name DS -PSProvider VimDatastore -Root "\" | Out-Null #create new datastore drive
        $tempFile = [System.IO.Path]::GetTempFileName() #create temp file
        Copy-DatastoreItem -Item "DS:\$($vm.Name)\vmware.log" -Destination $tempFile #copy vmware.log to temp file
        
        $tmpdate = cat $tempFile | Select-String "PowerOn" | Select-Object -First 1 | ForEach-Object { ($_.ToString().Split("|"))[0] } | ForEach-Object { ($_.ToString().Split("."))[0] }
        #get only time from tmpupdate and put it into rot.PoweredOnTime variable
        $bettertime = $tmpdate.replace('T',' ')
        $morebettertime = [Datetime]::ParseExact($bettertime, 'yyyy-MM-dd HH:mm:ss', $null)
        $besttime = $morebettertime.GetDateTimeFormats()[24]
        $row.PoweredOnTime = $besttime
        Remove-PSDrive -Name DS -Confirm:$false #remove datastore drive
    }
    else { #if power on time is in lastPO.CreatedTime variable
        $bettertime = $lastPO.CreatedTime.GetDateTimeFormats()[24]
        $row.PoweredOnTime = $bettertime #add power on time from lastPO.CreatedTime variable
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

    echo "One more VM is done..."
}

# Output to screen
$report | Sort PoweredOnTime, Cluster, Host, VMName | Select VMName, Cluster, Host, NumCPU, MemMb, @{N='DiskGb';E={[math]::Round($_.DiskGb,2)}}, PoweredOnTime, PoweredOnBy | ft -a

# Output to CSV - change path/filename as appropriate
$report | Sort PoweredOnTime, Cluster, Host, VMName | Export-Csv -Path "C:\Users\$env:UserName\Desktop\Powered_On_VMs.csv" -NoTypeInformation -UseCulture