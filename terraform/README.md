# Terraform Instructions for velociraptor-to-timesketch 

## Overview

This is a simple terraform template creating an automated deployment of the awesome "Breaches Be Crazy" velociraptor-to-timesketch automation for DFIR triage.  It automically builds the following resources hosted in AWS:

* One Linux EC2 instance deploying Timesketch server 
* One Linux EC2 instance deploying Velociraptor server 
* One Windows Client (Windows Server 2022) deploying Velociraptor client and registering to the server 
* One S3 bucket for staging of scripts and storing collected zip/plaso files for analysis
* One IAM user with programmatic access keys for reading/writing to S3 bucket
* An IAM instance profile with a role attached on the Timesketch EC2 instance allowing reading/writing to S3 bucket

See the **Features and Capabilities** section for more details.

## Requirements and Setup

**Tested with:**

* Mac OS 13.4
* terraform 1.5.7

**Clone this repository:**

**Credentials Setup:**

Generate an IAM programmatic access key that has permissions to build resources in your AWS account.  Setup your .env to load these environment variables.  You can also use the direnv tool to hook into your shell and populate the .envrc.  Should look something like this in your .env or .envrc:

```
export AWS_ACCESS_KEY_ID="VALUE"
export AWS_SECRET_ACCESS_KEY="VALUE"
```

## Build and Destroy Resources

### Run terraform init
Change into the AutomatedEmulation working directory and type:

```
terraform init
```

### Run terraform plan or apply
```
terraform apply -auto-approve
```
or
```
terraform plan -out=run.plan
terraform apply run.plan
```

### Destroy resources
```
terraform destroy -auto-approve
```

### View terraform created resources
The lab has been created with important terraform outputs showing services, endpoints, IP addresses, and credentials.  To view them:
```
terraform output
```

## Features and Capabilities

### Important Firewall and White Listing
The sg.tf has been changed to allow 0.0.0.0/0.  You can easily make a change to this so that only your source IPv4 is allowed access by modifying the lines shown below.  Uncomment the line using the call to ifconfig.so.

By default when you run terraform apply, your public IPv4 address is determined via a query to ifconfig.so and the ```terraform.tfstate``` is updated automatically.  If your location changes, simply run ```terraform apply``` to update the security groups with your new public IPv4 address.  If ifconfig.me returns a public IPv6 address,  your terraform will break.  In that case you'll have to customize the white list.  To change the white list for custom rules, update this variable in ```sg.tf```:
```
locals {
  src_ip = "${chomp(data.http.firewall_allowed.response_body)}/32"
  #src_ip = "0.0.0.0/0"
}
```

### Resource Details 

**Timesketch Linux Server**

The following local project files are important for customization:

* timesketch.tf:  The terraform file that builds the Linux server and all terraform variables for Timesketch.
* files/timesketch/bootstrap.sh.tpl:  The bootstrap script for Timesketch and other services.

Note:  All important files for building the Timesketch server are located in ```files/timesketch```.  This includes all systemd service installation, scripts, and a customized deploy_timesketch.sh script necessary for building Timesketch without an interactive user input.  The timesketch main bootstrap script pulls down all files from the S3 bucket that are used in the deployment.

**Troubleshooting Timesketch:**

SSH into the Timesketch server by looking in ```terraform output``` for this line:  
```
SSH to Timesketch
---------------
ssh -i ssh_key.pem ubuntu@18.217.18.67
```

Once in the system, tail the user-data logfile.  You will see the steps from the ```bootstrap.sh.tpl``` script running:
```
tail -f /var/log/user-data.log
```

**Teraform Output:**

View the terraform outputs for important Timesketch access information:
```
Timesketch server
-----------------
http://ec2-18-217-18-67.us-east-2.compute.amazonaws.com
user: admin
pass: Timesketch2024
```
**Velociraptor Linux Server**

The following local project files are important for customization:

* velociraptor.tf:  The terraform file that builds the Linux server and all terraform variables for Velociraptor.
* files/velociraptor/bootstrap.sh.tpl:  The bootstrap script for Velocirpator server.
* files/velociraptor/config.yml.tpl: The configuration template file. 
* files/velociraptor/Custom.Server.Utils.KAPEtoS3.tpl: The artifact template file.

Velociraptor is built with automation using an internal PKI that is built with terraform.  All certificates are generated using terraform and deployed to the Linux server configuration and Windows client system.

After the lab builds, get the rendered artifact file that automatically builds the parameters with S3 bucket and IAM credentials, which can then be uploaded using Velociraptor GUI console:
```
cat output/velociraptor/Custom.Server.Utils.KAPEtoS3
```

The output from this file can be copy and pasted in the add artifact section of Velociraptor and launching the server monitoring tables with it.

View the terraform outputs for important Velociraptor GUI console and SSH access information:
```
-------
Velociraptor Console
-------------------
https://ec2-3-135-20-149.us-east-2.compute.amazonaws.com:8889

Velociraptor Credentials
------------------------
admin:shining-firefly-SepA

SSH to Velociraptor
-------------------
ssh -i ssh_key.pem ubuntu@3.135.20.149
```

### Windows Client

This system will install the velociraptor client service on Windows.  Monitor the Velociraptor GUI console and you will eventually see the client register.

The Windows Client system is built from ```win1.tf```.  Windows Server 2022 Datacenter edition is currently used.  You can upload your own AMI image and change the data reference in win1.tf.  The local bootstrap script is located in ```files/windows/bootstrap-win.ps1.tpl```.  RDP into the Windows system and follow this logfile to see how the system is bootstrapping:

```
C:\Terraform\bootstrap_log.log
```

The additional bootstrap scripts that will run on the system and can be configured locally include:

files/windows/red.ps1.tpl:  Installs Atomic Red Team
files/windows/velociraptor.ps1.tpl:  Install Velociraptor client on Windows.

You can monitor the execution of these files by RDP into the Windows system and monitoring the logfiles in C:\terraform.

**Terraform Outputs**

See the output from ```terraform output``` to get the IP address and credentials for RDP:
```
-------------------------
Virtual Machine win1
-------------------------
Instance ID: i-02fc369e90a604a71
Computer Name:  win1
Private IP: 10.100.20.10
Public IP:  18.217.76.164
local Admin:  OpsAdmin
local password: Frank-lilith-930978
```

