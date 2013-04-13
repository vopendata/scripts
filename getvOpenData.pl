#!/usr/bin/perl -w

# http://www.vopendata.org/
# vOpenData Script by William Lam
# www.virtuallyghetto.com

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Path;

my $scriptVersion = 1.4;

my %opts = (
   reportname => {
      type => "=s",
      help => "Name of output file",
      required => 0,
      default => "vopendata-stats.zip"
   },
   debug => {
      type => "=s",
      help => "Enable debugging (print to stdout)",
      required => 0,
      default => 0
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $reportName = Opts::get_option('reportname');
my $debug = Opts::get_option('debug');
my ($uniqueID,$startTime,$endTime);
my ($hostCount,$vmCount,$vmdkCount,$datastoreCount,$lunCount,$clusterCount) = (0,0,0,0,0,0);
my $dirName = "vopendata";

print "Though the data that is collected is already anonymized and non-identifying, please ensure that you are abiding by the privacy policies of your organization when uploading this data. If you are concerned about the data, it is recommended that you audit the zip contents before uploading which are just CSV files. We only ask that you do not modify the schema at all.\n";
my $response = &promptUser("By typing yes and accepting this agreement, your anonymized data can be used for public data repositories [yes|no]");
if($response =~ m/yes/) {
	mkdir $dirName;
	print "Collecting vSphere Stats ...\n";
	print "This may take a second or two depending on the size of your environment. Go ahead and check out www.vopendata.org to see what you can expect while you are waiting " . "\n\n";
	&getvCenterUUID;
	&getHostInfo;
	&getVMInfo;
	&getDatastoreInfo;
	&getClusterInfo;
	&getvCenterInfo
} else {
	print "Script Exiting ...\n";
	Util::disconnect();
	exit 1;
}

Util::disconnect();

&generateZip;

sub getvCenterUUID {
	print "Retrieving vCenterUUID Info...\n";
	$startTime = time();
	my $sc = Vim::get_service_content();
	if(defined($sc->about->instanceUuid)) {
		$uniqueID = $sc->about->instanceUuid;
		$endTime = time();
		print "vCenterUUID Info took " . ($endTime - $startTime) . " seconds\n\n";
	} else {
		print "This script is only supported on vCenter Server 4.0 or greater\n";
		exit 1;
	}
}

sub getvCenterInfo {
	print "Retrieving vCenter Data...\n";
	$startTime = time();
	my $vcString = "s_vcenter,instanceUuid,vcVersion,vcBuild,hostCount,vmCount,vmdkCount,datastoreCount,lunCount,clusterCount" . "\n";	

	my $sc = Vim::get_service_content();
	my $vcVersion = $sc->about->version;
	my $vcBuild = $sc->about->build;
	my $instanceUuid = $sc->about->instanceUuid;
	$uniqueID = $instanceUuid;
	$vcString .= "vcenter,$instanceUuid,$vcVersion,$vcBuild,$hostCount,$vmCount,$vmdkCount,$datastoreCount,$lunCount,$clusterCount" . "\n";
			
	open(CSV_REPORT_OUTPUT, ">$dirName/vc-stats.csv");
	print CSV_REPORT_OUTPUT $vcString;
	close(CSV_REPORT_OUTPUT);

	open(CSV_REPORT_OUTPUT, ">$dirName/version.txt");
	print CSV_REPORT_OUTPUT $scriptVersion;
	close(CSV_REPORT_OUTPUT);	
	$endTime = time();
	print "vCenter Info took " . ($endTime - $startTime) . " seconds\n\n";
}

sub getHostInfo {
	print "Retrieving Host Info ...\n";
	$startTime = time();
	my $hostString = "s_host,vcInstanceUUID,hostUuid,hostState,hostVersion,hostBuild,hostVendor,hostModel,hostCPUVendor,hostCPUSocket,hostCPUCore,hostCPUSpeed,hostCPUThread,hostMem,hostHBA,hostNic,hostCPUUsage,hostMemUsage,hostUptime,hostDSs,hostVMs" . "\n";
        my $lunString = "s_lun,vcInstanceUUID,lunUuid,lunVendor,lunCapacity" . "\n";
	my $hostOutput = "$dirName/host-stats.csv";
	my $lunOutput = "$dirName/lun-stats.csv";

	my $vmhosts = Vim::find_entity_views(view_type => 'HostSystem', properties => ['config.product','summary.hardware','summary.runtime','summary.quickStats','configManager.storageSystem','datastore','vm'], filter => {'summary.runtime.connectionState' => 'connected'});
	foreach my $vmhost (@$vmhosts) {
		my $hostUuid = $vmhost->{'summary.hardware'}->uuid;
		my $hostState = $vmhost->{'summary.runtime'}->powerState->val;
		my $hostVersion = $vmhost->{'config.product'}->version;
		my $hostBuild = $vmhost->{'config.product'}->build;
		my $hostVendor = $vmhost->{'summary.hardware'}->vendor;
		$hostVendor =~ s/,//g;
		my $hostModel = $vmhost->{'summary.hardware'}->model;
		$hostModel =~ s/,//g;
		my $hostCPUVendor = $vmhost->{'summary.hardware'}->cpuModel;
		$hostCPUVendor =~ s/,//g;
		my $hostCPUSocket = $vmhost->{'summary.hardware'}->numCpuPkgs;
		my $hostCPUCore = $vmhost->{'summary.hardware'}->numCpuCores;
		my $hostCPUSpeed = $vmhost->{'summary.hardware'}->cpuMhz;
		my $hostCPUThread = $vmhost->{'summary.hardware'}->numCpuThreads;
		my $hostMem = $vmhost->{'summary.hardware'}->memorySize;
		my $hostHBA = $vmhost->{'summary.hardware'}->numHBAs;
		my $hostNic = $vmhost->{'summary.hardware'}->numNics;
		# MHZ
		my $hostCPUUsage = $vmhost->{'summary.quickStats'}->overallCpuUsage;
		# MB
		my $hostMemUsage = $vmhost->{'summary.quickStats'}->overallMemoryUsage;
		# SECONDS
		my $hostUptime = $vmhost->{'summary.quickStats'}->uptime;
		my $hostDSs = scalar(@{Vim::get_views(mo_ref_array => $vmhost->{'datastore'}, properties => ['name'])});
		my $hostVMs = scalar(@{Vim::get_views(mo_ref_array => $vmhost->{'vm'}, properties => ['name'])});
		$hostCount++;

		$hostString .= "host,$uniqueID,$hostUuid,$hostState,$hostVersion,$hostBuild,$hostVendor,$hostModel,$hostCPUVendor,$hostCPUSocket,$hostCPUCore,$hostCPUSpeed,$hostCPUThread,$hostMem,$hostHBA,$hostNic,$hostCPUUsage,$hostMemUsage,$hostUptime,$hostDSs,$hostVMs" . "\n";

		my $storageSys = Vim::get_view(mo_ref => $vmhost->{'configManager.storageSystem'});
		my $luns = $storageSys->storageDeviceInfo->scsiLun;
		foreach my $lun (@$luns) {
			if($lun->lunType eq "disk" && $lun->isa('HostScsiDisk')) {
				my $lunUuid = $lun->uuid;
				my $lunVendor = $lun->vendor;
				my $lunCapacity = $lun->capacity->block * $lun->capacity->blockSize;
				$lunCount++;

				$lunString .= "lun,$uniqueID,$lunUuid,$lunVendor,$lunCapacity" . "\n";
			}
		}
	}
	open(CSV_REPORT_OUTPUT, ">$hostOutput");
        print CSV_REPORT_OUTPUT $hostString;
        close(CSV_REPORT_OUTPUT);

        open(CSV_REPORT_OUTPUT, ">$lunOutput");
        print CSV_REPORT_OUTPUT $lunString;
        close(CSV_REPORT_OUTPUT);
	$endTime = time();
	print "Host Info took " . ($endTime - $startTime) . " seconds\n\n";
}

sub getVMInfo {
	print "Retrieving VM Info...\n";
	$startTime = time();
        my $vmString = "s_vm,vcInstanceUUID,vmUuid,vmState,vmOS,vmCPU,vmMem,vmNic,vmDisk,vmCPUUsage,vmMemUsage,vmCPUResv,vmMemResv,vmStorageTot,vmStorageUsed,vmUptime,vmFT,vmVHW" . "\n";
        my $vmdkString = "s_vmdk,vcInstanceUUID,vmdkKey,vmdkType,vmdkCapacity" . "\n";
	my $vmOutput = "$dirName/vm-stats.csv";
	my $vmdkOutput = "$dirName/vmdk-stats.csv";

	my $vms = Vim::find_entity_views(view_type => 'VirtualMachine', properties => ['summary.config','summary.runtime.powerState','summary.runtime.faultToleranceState','summary.quickStats','summary.storage','config.hardware.device','config.version','config.template'], filter => {'summary.runtime.connectionState' => 'connected','config.template' => 'false'});
	foreach my $vm (@$vms) {
		my $vmUuid = $vm->{'summary.config'}->instanceUuid;
		my $vmState = $vm->{'summary.runtime.powerState'}->val;
		my $vmOS = $vm->{'summary.config'}->guestFullName;
		$vmOS =~ s/,//g;
		my $vmCPU = $vm->{'summary.config'}->numCpu;
		my $vmMem = $vm->{'summary.config'}->memorySizeMB;
		my $vmNic = $vm->{'summary.config'}->numEthernetCards;
		my $vmDisk = $vm->{'summary.config'}->numVirtualDisks;
		# MHZ
		my $vmCPUUsage = $vm->{'summary.quickStats'}->overallCpuUsage;
		# MB
		my $vmMemUsage = $vm->{'summary.quickStats'}->guestMemoryUsage;
		# MHZ
		my $vmCPUResv = $vm->{'summary.config'}->cpuReservation;
		# MB
		my $vmMemResv = $vm->{'summary.config'}->memoryReservation;
		# BYTES
		my $vmStorageTot = $vm->{'summary.storage'}->committed + $vm->{'summary.storage'}->uncommitted;
		my $vmStorageUsed = $vm->{'summary.storage'}->committed;
		my $vmUptime = ($vm->{'summary.quickStats'}->uptimeSeconds ? $vm->{'summary.quickStats'}->uptimeSeconds : "N/A");
		my $vmFT = $vm->{'summary.runtime.faultToleranceState'}->val;
		my $vmVHW = $vm->{'config.version'};
		$vmCount++;
	
		$vmString .= "vm,$uniqueID,$vmUuid,$vmState,$vmOS,$vmCPU,$vmMem,$vmNic,$vmDisk,$vmCPUUsage,$vmMemUsage,$vmCPUResv,$vmMemResv,$vmStorageTot,$vmStorageUsed,$vmUptime,$vmFT,$vmVHW" . "\n";
		
		my $devices = $vm->{'config.hardware.device'};
		foreach my $device (@$devices) {
			my $vmdkKey = $vmUuid . "-" . $device->key;
			my $vmdkType = "";
			if($device->isa('VirtualDisk')) {
				if($device->backing->isa('VirtualDiskFlatVer2BackingInfo')) {
					if($device->backing->thinProvisioned) {
						$vmdkType = "thin";
					} elsif($device->backing->eagerlyScrub) {
						$vmdkType = "eagerzeroedthick"
					} else { 
						$vmdkType = "zeroedthick";
					}
				} elsif($device->backing->isa('VirtualDiskRawDiskVer2BackingInfo') || $device->backing->isa('VirtualDiskRawDiskMappingVer1BackingInfo')) {
					if($device->backing->compatibilityMode eq "physicalMode") {
						$vmdkType = "prdm";
					} else {
						$vmdkType = "vrdm";
					}
				}
				my $vmdkCapacity = $device->capacityInKB;
				$vmdkCount++;

				$vmdkString .= "vmdk,$uniqueID,$vmdkKey,$vmdkType,$vmdkCapacity" . "\n";
			}
		}
	}
        open(CSV_REPORT_OUTPUT, ">$vmOutput");
        print CSV_REPORT_OUTPUT $vmString;
        close(CSV_REPORT_OUTPUT);

        open(CSV_REPORT_OUTPUT, ">$vmdkOutput");
        print CSV_REPORT_OUTPUT $vmdkString;
        close(CSV_REPORT_OUTPUT);
	$endTime = time();
	print "VM Info took " . ($endTime - $startTime) . " seconds\n\n";
}

sub getDatastoreInfo {
	print "Retrieving Datastore Info ...\n";
	$startTime = time();
        my $datastoreString = "s_datastore,vcInstanceUUID,dsUuid,dsType,dsSSD,dsVMFSVersion,dsCapacity,dsFree,dsVMs" . "\n";
	my $datastoreOutput = "$dirName/datastore-stats.csv";

	my $datastores = Vim::find_entity_views(view_type => 'Datastore', properties => ['summary','vm','info'], filter => {'summary.accessible' => 'true'});
	
	foreach my $datastore (@$datastores) {
		my $dsUuid = $uniqueID . "-" . $datastore->{'mo_ref'}->value;
		my $dsType = $datastore->{'summary'}->type;
		my $dsSSD = "false";
		my $dsVMFSVersion = "N/A";
		if($dsType eq "VMFS") {
			$dsSSD = ($datastore->{'info'}->vmfs->ssd ? "true" : "false");
			$dsVMFSVersion = $datastore->{'info'}->vmfs->version;
		}
		# BYTES
		my $dsCapacity = $datastore->{'summary'}->capacity;
		# BYTES
		my $dsFree = $datastore->{'summary'}->freeSpace;
		my $dsVMs = scalar(@{Vim::get_views(mo_ref_array => $datastore->vm, properties => ['name'])});
		$datastoreCount++;

		$datastoreString .= "datastore,$uniqueID,$dsUuid,$dsType,$dsSSD,$dsVMFSVersion,$dsCapacity,$dsFree,$dsVMs" . "\n";
	}
        open(CSV_REPORT_OUTPUT, ">$datastoreOutput");
        print CSV_REPORT_OUTPUT $datastoreString;
        close(CSV_REPORT_OUTPUT);
	$endTime = time();
	print "Datastore Info took " . ($endTime - $startTime) . " seconds\n\n";
}

sub getClusterInfo {
	print "Retrieving Cluster Info ...\n";
	$startTime = time();
	my $clusterString = "s_cluster,vcInstanceUUID,clusterUuid,clusterTotCpu,clusterTotMem,clusterAvailCpu,clusterAvailMem,clusterHA,clusterDRS,clusterHost,clusterDatastore,clusterVM" . "\n";	
	my $clusterOutput = "$dirName/cluster-stats.csv";

	my $clusters = Vim::find_entity_views(view_type => 'ClusterComputeResource', properties => ['summary','datastore','resourcePool','configurationEx']);
	
	foreach my $cluster (@$clusters) {
		my $clusterUuid = $uniqueID . "-" . $cluster->{'mo_ref'}->value;
		my $clusterTotCpu = $cluster->{'summary'}->totalCpu;
		my $clusterTotMem = $cluster->{'summary'}->totalMemory;
		my $clusterAvailCpu = $cluster->{'summary'}->effectiveCpu;
		my $clusterAvailMem = $cluster->{'summary'}->effectiveMemory;
	
		my ($clusterHA,$clusterDRS) = ("N/A","N/A");	
		if($cluster->{'configurationEx'}->isa('ClusterConfigInfoEx')) {
			$clusterHA = ($cluster->{'configurationEx'}->dasConfig->enabled ? "true" : "false");
			$clusterDRS = ($cluster->{'configurationEx'}->drsConfig->enabled ? "true" : "false");
		}
		my $clusterHost = $cluster->{'summary'}->numHosts;
		my $clusterDatastore = scalar(@{Vim::get_views(mo_ref_array => $cluster->{'datastore'}, properties => ['name'])});
		my $clusterVM = scalar(@{Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $cluster, properties => ['name'])});
		$clusterCount++;

		$clusterString .= "cluster,$uniqueID,$clusterUuid,$clusterTotCpu,$clusterTotMem,$clusterAvailCpu,$clusterAvailMem,$clusterHA,$clusterDRS,$clusterHost,$clusterDatastore,$clusterVM" . "\n";
	}
	open(CSV_REPORT_OUTPUT, ">$clusterOutput");
	print CSV_REPORT_OUTPUT $clusterString;
	close(CSV_REPORT_OUTPUT);
	$endTime = time();
	print "Cluster Info took " . ($endTime - $startTime) . " seconds\n\n";
}

sub generateZip {
	print "Generating zip file ...\n";
	$startTime = time();
	my $zipObj = Archive::Zip->new();
	$zipObj->addTree($dirName);
	unless ($zipObj->writeToFileNamed($reportName) == AZ_OK) {
		print "Error: Unable to write " . $reportName . "\n";
	}
	rmtree($dirName);
	$endTime = time();
	print "Zip generation took " . ($endTime - $startTime) . " seconds\n\n";
	print "Succesfully created " . $reportName . "\n\n";
}

# prompt user taken from http://devdaily.com/perl/edu/articles/pl010005#comment-159
sub promptUser {
        my($prompt) = @_;
        print "\n$prompt: \n";
        chomp(my $input = <STDIN>);
        return $input;
}

=head1 NAME

getvOpenData.pl - This script connects to VMware vCenter and creates the dataset which can manually be uploaded to the http://www.vopendata.org site.

=head1 SYNOPSIS

Author: 
	William Lam (www.virtuallyghetto.com)
	Version 1.0

=head1 DESCRIPTION

This script will only retrieve data as listed on the http://www.vopendata.org site from the specified vCenter 
and store the data in CSV format in the vopendata-stats.zip file in your desktop folder.

=head1 EXAMPLES

List all of the connected cdrom devices on host abc.

      getvOpenData.pl --server "[vCENTER_SERVER]" --username "[vCenter_USERNAME]" --password "[vCENTER_PASSWORD]"

=head1 SUPPORTED PLATFORMS

All operations are supported on ESXi 5.x and vCenter Server 5.x and better.
