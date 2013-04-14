# vOpenData Scripts
These scripts are for generating the output to submit data to www.vopendata.org.

## vSphere SDK for Perl

Download getvOpenData.pl and you will need to have either the vCLI installed or use VMware vMA appliance

Usage:

	./getvOpenData.pl --server <VCENTER-SERVER> --username <USERNAME>

## PowerCLI

Download getvOpenData.ps1 and you will need to have PowerCLI installed

Interactive Usage:

	./getvOpenData.ps1
	Though the data that is collected is already anonymized and non-identifying, please ensure that you are abiding 
	by the privacy policies of your organization when uploading this data. If you are concerned about the data, 
	it is recommended that you audit the zip contents before uploading which are just CSV files. We only ask that you
	do not modify the schema at all. 
	By typing yes and accepting this agreement, your anonymized data can be used for public data repositories [yes|no]: <yes>
	Please Enter Your vCenter Server : <VCENTER-SERVER>

Command line options available:

	./getvOpenData.ps1 -vcname "myvcenter.cor.local"
	or
	./getvOpenData.ps1 -vcname "myvcenter.cor.local" -port 443

If you want to write a script in a different language, make sure it follows the same schema and fork this repository and then submit a pull request.
