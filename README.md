# vOpenData Scripts
These scripts are for generating the output to submit data to www.vopendata.org.

## vSphere SDK for Perl

Download getvOpenData.pl and you will need to have either the vCLI installed or use VMware vMA appliance

Usage:

	./getvOpenData.pl --server <VCENTER-SERVER> --username <USERNAME> --zipname <NAME.zip>

Example(s):

	./getvOpenData.pl
	Though the data that is collected is already anonymized and non-identifying, please ensure that you are abiding by the privacy policies of your organization when uploading this data. If you are concerned about the data, it is recommended that you audit the zip contents before uploading which are just CSV files. We only ask that you do not modify the schema at all.

	By typing yes and accepting this agreement, your anonymized data can be used for public data repositories [yes|no]:

	./getvOpenData.pl --server myvcenter.cor.local --username root --zipname myvc1.zip


## PowerCLI

Download getvOpenData.ps1 and you will need to have PowerCLI installed

Usage:

	.\getvOpenData.ps1 -vcname <VCENTER-SERVER> -port <VCENTER-PORT> -zipname <NAME.zip>

Example(s): 

	.\getvOpenData.ps1
	Though the data that is collected is already anonymized and non-identifying, ple ase ensure that you are abiding by the privacy policies of your organization when uploading this data. If you are concerned about the data, it is recommended that you audit the zip contents before uploading which are just CSV files. We only ask that you do not modify the schema at all.By typing yes and accepting this agreement, your anonymized data can be used for public data repositories [yes|no]:
	Please Enter Your vCenter Server : [VCENTER-SERVER]

	.\getvOpenData.ps1 -vcname "myvcenter.cor.local" 

	.\getvOpenData.ps1 -vcname "myvcenter.cor.local" -port 443 -zipname myvc1.zip 

If you want to write a script in a different language, make sure it follows the same schema and fork this repository and then submit a pull request.
