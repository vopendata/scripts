<#
 
.SYNOPSIS
This script connects to VMware vCenter and creates the dataset which can manually be uploaded to the http://www.vopendata.org site.
 
.DESCRIPTION
This script will only retrieve data as listed on the http://www.vopendata.org site from the specified vCenter 
and store the data in CSV format in the vopendata-stats.zip file in your desktop folder.
 
.EXAMPLE
./getvOpenData.ps1 -vcname "myvcenter.cor.local"

.EXAMPLE
./getvOpenData.ps1 -vcname "myvcenter.cor.local" -port 443
 
.NOTES
Author: 
	William Lam (www.virtuallyghetto.com)
Change Log:
	Version 1.3 - Adding version.txt 
	Version 1.2 - Fixed issues with commas on host entries
	Version 1.1 - Fixed multiple issues
 
.LINK
http://www.vopendata.org
 
#>

param( 
	[string]$vcname,
	[int]$port
	
	)

Write-Host "Though the data that is collected is already anonymized and non-identifying, please ensure that you are abiding by the privacy policies of your organization when uploading this data. If you are concerned about the data, it is recommended that you audit the zip contents before uploading which are just CSV files. We only ask that you do not modify the schema at all."
$response = Read-Host 'By typing yes and accepting this agreement, your anonymized data can be used for public data repositories [yes|no]'

if($response -ne "yes") {
	Write-Host "Scripting existing ...`n"
	exit
}

if (!$vcname){$vcname = Read-Host 'Please Enter Your vCenter Server'}

if (!(Get-PSSnapin| Where {$_.name -eq "VMware.VimAutomation.Core"})){add-pssnapin -name "VMware.VimAutomation.Core" -ErrorAction SilentlyContinue}
if (!($global:DefaultVIServer|Where {$_.name -eq $vcname})){
	If (!$port) {
		$vcenter = Connect-VIServer $vcname -WarningAction SilentlyContinue
	} Else {
		$vcenter = Connect-VIServer $vcname -WarningAction SilentlyContinue -Port $port
	}
} Else {
	$alreadyconnected = $true
	$vcenter = $global:DefaultVIServer | Where {$_.name -eq $vcname}
}

if (!$vcenter.IsConnected){
	Write-Host "Unable to connect to $vcname, please try again"
	exit
}

$csvReportName = "vopendata-stats.zip"

## DO NOT EDIT BEYOND HERE ##

$global:scriptVersion = 1.3
$global:desktopPath = (Get-Item env:\USERPROFILE).value + "\desktop\"
$global:desktopPathDir = $global:desktopPath + "vopendata\"
$global:uniqueId = ""
$global:hostCount = 0
$global:vmCount = 0
$global:vmdkCount = 0
$global:datastoreCount = 0
$global:lunCount = 0
$global:clusterCount = 0

Function Get-vCenterUUID {
	$sc = $vcenter.ExtensionData.Content
	$global:uniqueId = $sc.About.InstanceUuid
}

Function Get-HostInfo {
	$hostReport = @()
	$lunReport = @()
	$hostSchema = "s_host,vcInstanceUUID,hostUuid,hostState,hostVersion,hostBuild,hostVendor,hostModel,hostCPUVendor,hostCPUSocket,hostCPUCore,hostCPUSpeed,hostCPUThread,hostMem,hostHBA,hostNic,hostCPUUsage,hostMemUsage,hostUptime,hostDSs,hostVMs"
	$lunSChema = "s_lun,vcInstanceUUID,lunUuid,lunVendor,lunCapacity"
	$hostCSV = $global:desktopPathDir +  "host-stats.csv"
	$lunCSV = $global:desktopPathDir +  "lun-stats.csv"
	$hostReport += $hostSchema
	$lunReport += $lunSChema

	$vmhosts = Get-View -Server $vcenter -ViewType HostSystem -Property Config.Product,Summary.Hardware,Summary.Runtime,Summary.QuickStats,ConfigManager.StorageSystem,Datastore,VM -Filter @{'Summary.Runtime.ConnectionState'='connected'}

	foreach ($vmhost in $vmhosts) {
		$hostRow = "" | select DataType,vcInstanceUUID,hostUuid,hostState,hostVersion,hostBuild,hostVendor,hostModel,hostCPUVendor,hostCPUSocket,hostCPUCore,hostCPUSpeed,hostCPUThread,memorySize,hostHBA,hostNic,hostCPUUsage,hostMemUsage,hostUptime,hostDSs,hostVMs
		$hostRow.DataType = "host"
		$hostRow.vcInstanceUUID = $global:uniqueId
		$hostRow.hostUuid = $vmhost.Summary.Hardware.uuid
		$hostRow.hostState = $vmhost.Summary.Runtime.PowerState
		$hostRow.hostVersion = $vmhost.Config.Product.Version
		$hostRow.hostBuild = $vmhost.Config.Product.Build
		$hostRow.hostVendor = ($vmhost.Summary.Hardware.Vendor).replace(",","")
		$hostRow.hostModel = ($vmhost.Summary.Hardware.Model).replace(",","")
		$hostRow.hostCPUVendor = ($vmhost.Summary.Hardware.CpuModel).replace(",","")
		$hostRow.hostCPUSocket = $vmhost.Summary.Hardware.NumCpuPkgs
		$hostRow.hostCPUCore = $vmhost.Summary.Hardware.NumCpuCores
		$hostRow.hostCPUSpeed = $vmhost.Summary.Hardware.CpuMhz
		$hostRow.hostCPUThread = $vmhost.Summary.Hardware.NumCpuThreads
		$hostRow.memorySize = $vmhost.Summary.Hardware.memorySize
		$hostRow.hostHBA = $vmhost.Summary.Hardware.NumHBAs
		$hostRow.hostNic = $vmhost.Summary.Hardware.NumNics
		$hostRow.hostCPUUsage = $vmhost.Summary.QuickStats.OverallCpuUsage
		$hostRow.hostMemUsage = $vmhost.Summary.QuickStats.OverallMemoryUsage
		$hostRow.hostUptime = $vmhost.Summary.QuickStats.Uptime
		$hostRow.hostDSs = ($vmhost.Datastore | Measure-Object).Count
		$hostRow.hostVMs = ($vmhost.VM | Measure-Object).Count
		$global:hostCount++
		$hostReport += $hostRow | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1
			
		$storageSys = Get-View -Server $vcenter -Id $vmhost.ConfigManager.StorageSystem -Property StorageDeviceInfo
		$luns = $storageSys.StorageDeviceInfo.ScsiLun
		$lunArray = @()
		foreach ($lun in $luns) {
			$lunRow = "" | select DataType,vcInstanceUUID,lunUuid,lunVendor,lunCapacity
			if($lun -is [VMware.Vim.HostScsiDisk]) {
					$lunRow.DataType = "lun"
					$lunRow.vcInstanceUUID = $global:uniqueId
					$lunRow.lunUuid = $lun.Uuid
					$lunRow.lunVendor = $lun.Vendor
					$lunRow.lunCapacity = $lun.capacity.block * $lun.capacity.BlockSize
					$lunReport += $lunRow | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1
					$global:lunCount++
			}
		}
	}
	$hostReport | % { $_ -replace '"', ""} | Out-File $hostCSV -Force -Encoding "UTF8"
	$lunReport | % { $_ -replace '"', ""} | Out-File $lunCSV -Force -Encoding "UTF8"
}

Function Get-VMInfo {
	$vmReport = @()
	$vmdkReport = @()
	$vmSchema = "s_vm,vcInstanceUUID,vmUuid,vmState,vmOS,vmCPU,vmMem,vmNIC,vmDisk,vmCPUUsage,vmMemUsage,vmCpuResv,vmMemResv,vmStorageTot,vmStorageUsed,vmUptime,vmFT,vmVHW"
	$vmdkSchema = "s_vmdk,vcInstanceUUID,vmdkKey,vmdkType,vmdkCapacity"
	$vmCSV = $global:desktopPathDir +  "vm-stats.csv"
	$vmdkCSV = $global:desktopPathDir + "vmdk-stats.csv"
	$vmReport += $vmSchema
	$vmdkReport += $vmdkSchema
	
	$vms = get-view -Server $vcenter -ViewType VirtualMachine -Property Summary.Config,Summary.Runtime,Summary.QuickStats,Summary.Storage,Config.Hardware.Device,Config.Version,Config.Template -Filter @{'Summary.Runtime.ConnectionState'='connected';'Config.Template'='False'}

	foreach ($vm in $vms) {
		$vmRow = "" | select DataType,vcInstanceUUID,vmUuid,vmState,vmOS,vmCPU,vmMem,vmNIC,vmDisk,vmCPUUsage,vmMemUsage,vmCpuResv,vmMemResv,vmStorageTot,vmStorageUsed,vmUptime,vmFT,vmVHW
		$vmRow.Datatype = "vm"
		$vmRow.vcInstanceUUID = $global:uniqueId
		$vmRow.vmUuid = $vm.Summary.Config.InstanceUuid
		$vmRow.vmState = $vm.Summary.Runtime.PowerState
		$vmRow.vmOS = ($vm.Summary.Config.GuestFullName).replace(",","")
		$vmRow.vmCPU = $vm.Summary.Config.NumCpu
		$vmRow.vmMem = $vm.Summary.Config.MemorySizeMB
		$vmRow.vmNic = $vm.Summary.Config.NumEthernetCards
		$vmRow.vmDisk = $vm.Summary.Config.NumVirtualDisks
		$vmRow.vmCPUUsage = $vm.Summary.QuickStats.OverallCpuUsage
		$vmRow.vmMemUsage = $vm.Summary.QuickStats.GuestMemoryUsage
		$vmRow.vmCpuResv = $vm.Summary.Config.CpuReservation
		$vmRow.vmMemResv = $vm.Summary.Config.MemoryReservation
		$vmRow.vmStorageTot = $vm.Summary.Storage.Committed + $_.Summary.Storage.Uncommitted
		$vmRow.vmStorageUsed = $vm.Summary.Storage.Committed
		$vmRow.vmUptime = $vm.Summary.QuickStats.UptimeSeconds
		$vmRow.vmFT = $vm.Summary.Runtime.FaultToleranceState
		$vmRow.vmVHW = $vm.Config.Version
		$global:vmCount++
		$vmReport += $vmRow | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1
		
		$devices = $vm.Config.Hardware.Device
		foreach ($device in $devices) {
			$vmdkRow = "" | select Datatype,vcInstanceUUID,vmdkKey,vmdkType,vmdkCapacity
			if($device -is [VMware.Vim.VirtualDisk]) {
				$vmdkRow.Datatype = "vmdk"
				$vmdkRow.vcInstanceUUID = $global:uniqueId
				$vmdkRow.vmdkKey = $vm.Summary.Config.InstanceUuid + "-" + $device.Key
				$vmdkType = ""
				if($device.Backing -is [VMware.Vim.VirtualDiskFlatVer2BackingInfo]) {
					if($device.Backing.ThinProvisioned) {
						$vmdkRow.vmdkType = "thin"
					} elseif($device.Backing.EagerlyScrub) {
						$vmdkRow.vmdkType = "eagerzeroedthick"
					} else {
						$vmdkRow.vmdkType = "zeroedthick";
					}
				} elseif($device.Backing -is [VMware.Vim.VirtualDiskRawDiskVer2BackingInfo] -or $device.Backing -is [VMware.Vim.VirtualDiskRawDiskMappingVer1BackingInfo]) {
					if($device.Backing.CompatibilityMode.Value -eq "physicalMode") {
						$vmdkRow.vmdkType = "prdm";
					} else {
						$vmdkRow.vmdkType = "vrdm";
					}
				}
				$vmdkRow.vmdkCapacity = $device.CapacityInKB;
				$global:vmdkCount++
				$vmdkReport += $vmdkRow | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1
			}
		}
	}
	$vmReport | % { $_ -replace '"', ""} | Out-File $vmCSV -Force -Encoding "UTF8"
	$vmdkReport | % { $_ -replace '"', ""} | Out-File $vmdkCSV -Force -Encoding "UTF8"
}

Function Get-DatastoreInfo {
	$dsReport = @()
	$dsSchema = "s_datastore,vcInstanceUUID,dsUuid,dsType,dsSSD,dsVMFSVersion,dsCapacity,dsFree,dsVMs"
	$dsCSV = $global:desktopPathDir + "datastore-stats.csv"
	$dsReport += $dsSchema

	# Extending property filter for get-view cmdlet
	$datastores = Get-View -server $vcenter -ViewType Datastore -Property Info,Summary.Type,Summary.Capacity,Summary.FreeSpace,Vm -Filter @{'Summary.Accessible'='true'}

	foreach ($datastore in $datastores) {
		$dsRow = "" | select DataType,vcInstanceUUID,dsUuid,dsType,dsSSD,dsVMFSVersion,dsCapacity,dsFree,dsVMs
		$dsRow.DataType = "datastore"
		$dsRow.vcInstanceUUID = $global:uniqueId
		$dsRow.dsUuid = $global:uniqueId + "-" + $datastore.MoRef.Value
		$dsRow.dsType = $datastore.Summary.Type
		$dsRow.dsSSD = $false
		$dsRow.dsVMFSVersion = "N/A"
		if($dsRow.dsType -eq "VMFS") {
			$dsRow.dsSSD = $datastore.Info.Vmfs.Ssd 
			$dsRow.dsVMFSVersion = $datastore.Info.Vmfs.Version
		}
		$dsRow.dsCapacity = $datastore.Summary.Capacity
		$dsRow.dsFree = $datastore.Summary.FreeSpace
		$dsRow.dsVMs = ($datastore.Vm | Measure-Object).Count
		$global:datastoreClount++
		$dsReport += $dsRow | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1
	}
	$dsReport | % { $_ -replace '"', ""} | Out-File $dsCSV -Force -Encoding "UTF8"
}

Function Get-ClusterInfo {
	$clusterReport = @()
	$clusterSchema = "s_cluster,vcInstanceUUID,clusterUuid,clusterTotCpu,clusterTotMem,clusterAvailCpu,clusterAvailMem,clusterHA,clusterDRS,clusterHost,clusterDatastore,clusterVM"
	$clusterCSV = $global:desktopPathDir + "cluster-stats.csv"
	$clusterReport += $clusterSchema
	
	$clusters = Get-View -server $vcenter -ViewType ClusterComputeResource -Property Summary,Datastore,ResourcePool,ConfigurationEx
	
	foreach ($cluster in $clusters) {
		$clusterRow = "" | select DataType,vcInstanceUUID,clusterUuid,clusterTotCpu,clusterTotMem,clusterAvailCpu,clusterAvailMem,clusterHA,clusterDRS,clusterHost,clusterDatastore,clusterVM
		$clusterRow.DataType = "cluster"
		$clusterRow.vcInstanceUUID = $global:uniqueId
		$clusterRow.clusterUuid = $global:uniqueId + "-" + $cluster.MoRef.Value
		$clusterRow.clusterTotCpu = $cluster.Summary.TotalCpu
		$clusterRow.clusterTotMem = $cluster.Summary.TotalMemory
		$clusterRow.clusterAvailCpu = $cluster.Summary.EffectiveCpu
		$clusterRow.clusterAvailMem = $cluster.Summary.EffectiveMemory
		
		$clusterRow.clusterHA = "N/A"
		$clusterROw.clusterDRS = "N/A"
		if($cluster.ConfigurationEx -is [VMware.Vim.ClusterConfigInfoEx]) {
			$clusterRow.clusterHA = $cluster.ConfigurationEx.DasConfig.Enabled
			$clusterRow.clusterDRS = $cluster.ConfigurationEx.DasConfig.Enabled
		}
		$clusterRow.clusterHost = $cluster.Summary.numHosts
		$clusterRow.clusterDatastore = ($cluster.Datastore | Measure-Object).Count
		$clusterRow.clusterVM = 0
		$clusterRow.clusterVM += (Get-View -ViewType VirtualMachine -SearchRoot $cluster.MoRef -Property Name).Count
		$global:clusterCount++
		$clusterReport += $clusterRow | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1
	}
	$clusterReport | % { $_ -replace '"', ""} | Out-File $clusterCSV -Force -Encoding "UTF8"
}

Function Get-vCenterInfo {
	$vcCSV = $global:desktopPathDir + "vc-stats.csv"
	$versionFile = $global:desktopPathDir + "version.txt"
	$vcReport = @()
	$vcSchema = "s_vcenter,instanceUuid,vcVersion,vcBuild,hostCount,vmCount,vmdkCount,datastoreCount,lunCount,clusterCount"
	$vcReport += $vcSchema
	
	$sc = $vcenter.ExtensionData.Content
	$vcRow = "" | select DataType,instanceUuid,vcVersion,vcBuild,hostCount,vmCount,vmdkCount,datastoreCount,lunCount,clusterCount
	$vcRow.DataType = "vcenter"
	$vcRow.instanceUuid = $sc.About.InstanceUuid
	$vcRow.vcVersion = $sc.About.Version
	$vcRow.vcBuild = $sc.About.Build
	$vcRow.hostCount = $global:hostCount
	$vcRow.vmCount = $global:vmCount
	$vcRow.vmdkCount = $global:vmdkCount
	$vcRow.datastoreCount = $global:datastoreClount
	$vcRow.lunCount = $global:lunCount
	$vcRow.clusterCount = $global:clusterCount
	$vcReport += $vcRow | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1
	$vcReport | % { $_ -replace '"', ""} | Out-File $vcCSV -Force -Encoding "UTF8"
	
	$global:scriptVersion | Out-File $versionFile -Force -Encoding "UTF8"
}

Function Create-ZipFile {
	$zipFileName = $global:desktopPath + $csvReportName
	set-content $zipFileName ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18)) 
	$zipFile = (new-object -com shell.application).NameSpace($zipFileName)
	Foreach ($csvfile in (Get-Childitem -Path ($global:desktopPathDir + "*") -Include ("*.csv","*.txt"))) {
		$zipFile.CopyHere($csvfile.fullname)
		# Adding a little sleep in the process in order to avoid access error in zip file
		do {
			Start-sleep -milliseconds 500
		} until (($zipFile.Items() | Where { $_.Name -eq $csvfile.Name }).size -eq $csvfile.length)
	}
	Write-Host "Succesfully created " $csvReportName
	Remove-Item -Recurse -Force $global:desktopPathDir
}


Write-Host "`nCollecting vSphere Stats & Generating" $csvReportName "..."
Write-Host "This may take a second or two depending on the size of your environment. Go ahead and check out vopendata.org to see what you can expect while you are waiting`n"

New-Item -ItemType directory -Path $global:desktopPathDir -Force | Out-Null

Get-vCenterUUID
Get-HostInfo
Get-VMInfo
Get-DatastoreInfo
Get-ClusterInfo
Get-vCenterInfo
Create-ZipFile

if (!$alreadyconnected){
	Disconnect-VIServer -Server $vcenter -Confirm:$false
}