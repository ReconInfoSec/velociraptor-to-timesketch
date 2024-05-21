# Timesketch Instance 
variable "instance_type_linux1" {
  description = "The AWS instance type to use for servers."
  # Adding 16GB memory for better Timesketch performance
  default     = "t3a.xlarge"
}

variable "velociraptor_kapefile" {
  default = "Custom.Server.Utils.KAPEtoS3"
}

variable "timesketch_deploy_script" {
  default = "deploy_timesketch.sh"
}

variable "watch_s3_to_timesketch_python_script" {
  default = "watch-s3-to-timesketch.py"
}

variable "watch_plaso_to_s3_sh_script" {
  default = "watch-plaso-to-s3.sh"
}

variable "watch_to_timesketch_sh_script" {
  default = "watch-to-timesketch.sh"
}

variable "data_to_timesketch_service" {
  default = "data-to-timesketch.service"
}

variable "watch_plaso_to_s3_service" {
  default = "watch-plaso-to-s3.service"
}

variable "watch_s3_to_timesketch_service" {
  default = "watch-s3-to-timesketch.service"
}


variable "timesketch_user" {
  default = "admin"
}

variable "timesketch_pass" {
  default = "Timesketch2024"
}

variable "root_block_device_size_linux1" {
  description = "The volume size of the root block device."
  default     =  60 
}

data "aws_ami" "linux1" {
  most_recent      = true
  owners           = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "linux1" {
  ami                    = data.aws_ami.linux1.id
  instance_type          = var.instance_type_linux1
  subnet_id              = aws_subnet.user_subnet.id
  key_name               = module.key_pair.key_pair_name 
  vpc_security_group_ids = [aws_security_group.linux_ingress.id, aws_security_group.linux_ssh_ingress.id, aws_security_group.linux_allow_all_internal.id]

  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.private_key.private_key_pem
    host        = self.public_ip
  }

  tags = {
    "Name" = "timesketch1"
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size_linux1
    delete_on_termination = "true"
  }

  user_data = data.template_file.linux1.rendered 

}

data "template_file" "linux1" {
  template = file("${path.module}/files/timesketch/bootstrap.sh.tpl")

  vars = {
    s3_bucket         = aws_s3_bucket.staging.id
    region            = var.region
    linux_os          = "ubuntu"
    timesketch_deploy = var.timesketch_deploy_script
    timesketch_user   = var.timesketch_user
    timesketch_pass   = var.timesketch_pass
    python_watch_s3   = var.watch_s3_to_timesketch_python_script
    sh_watch_plaso    = var.watch_plaso_to_s3_sh_script
    sh_watch_to_time  = var.watch_to_timesketch_sh_script
    svc_data_to_time  = var.data_to_timesketch_service
    svc_watch_plaso   = var.watch_plaso_to_s3_service
    svc_watch_s3      = var.watch_s3_to_timesketch_service
  }
}

resource "local_file" "linux1" {
  # For inspecting the rendered bash script as it is loaded onto linux system 
  content = data.template_file.linux1.rendered
  filename = "${path.module}/output/linux/ubuntu-linux1.sh"
}

output "details_linux1" {
  value = <<CONFIGURATION
----------------
Timesketch 
----------------
OS:          ubuntu
Public IP:   ${aws_instance.linux1.public_ip} 
Private IP:  ${aws_instance.linux1.private_ip} 
EC2 Inst ID: ${aws_instance.linux1.id}

SSH to Timesketch 
---------------
ssh -i ssh_key.pem ubuntu@${aws_instance.linux1.public_ip}  

Timesketch server
-----------------
http://${aws_instance.linux1.public_dns}  
user: ${var.timesketch_user}
pass: ${var.timesketch_pass}

CONFIGURATION
}

resource "aws_s3_object" "deploy_timesketch_sh" {
  bucket = aws_s3_bucket.staging.id
  key    = var.timesketch_deploy_script
  source = "${path.module}/files/timesketch/${var.timesketch_deploy_script}"
  content_type = "text/plain"
}

resource "aws_s3_object" "data_to_timesketch_service" {
  bucket = aws_s3_bucket.staging.id
  key    = var.data_to_timesketch_service
  source = "${path.module}/files/timesketch/${var.data_to_timesketch_service}"
  content_type = "text/plain"
}

resource "aws_s3_object" "watch_s3_to_timesketch_service" {
  bucket = aws_s3_bucket.staging.id
  key    = var.watch_s3_to_timesketch_service
  source = "${path.module}/files/timesketch/${var.watch_s3_to_timesketch_service}"
  content_type = "text/plain"
}

resource "aws_s3_object" "watch_plaso_to_s3_service" {
  bucket = aws_s3_bucket.staging.id
  key    = var.watch_plaso_to_s3_service
  source = "${path.module}/files/timesketch/${var.watch_plaso_to_s3_service}"
  content_type = "text/plain"
}

resource "local_file" "watch_s3_to_timesketch_py" {
  content  = data.template_file.watch_s3_to_timesketch_py.rendered
  filename = "${path.module}/output/timesketch/${var.watch_s3_to_timesketch_python_script}"
}

data "template_file" "watch_s3_to_timesketch_py" {
  template = file("${path.module}/files/timesketch/${var.watch_s3_to_timesketch_python_script}.tpl")

  vars = {
    s3_bucket         = aws_s3_bucket.staging.id
    region            = var.region
  }
}

resource "aws_s3_object" "watch_s3_to_timesketch_py" {
  bucket = aws_s3_bucket.staging.id
  key    = var.watch_s3_to_timesketch_python_script 
  source = local_file.watch_s3_to_timesketch_py.filename
  content_type = "text/plain"

  depends_on = [local_file.watch_s3_to_timesketch_py]
}

resource "local_file" "watch_plaso_to_s3_sh" {
  content  = data.template_file.watch_plaso_to_s3_sh.rendered
  filename = "${path.module}/output/timesketch/${var.watch_plaso_to_s3_sh_script}"
}

data "template_file" "watch_plaso_to_s3_sh" {
  template = file("${path.module}/files/timesketch/${var.watch_plaso_to_s3_sh_script}.tpl")

  vars = {
    s3_bucket         = aws_s3_bucket.staging.id
    region            = var.region
  }
}

resource "aws_s3_object" "watch_plaso_to_s3_sh" {
  bucket = aws_s3_bucket.staging.id
  key    = var.watch_plaso_to_s3_sh_script
  source = local_file.watch_plaso_to_s3_sh.filename
  content_type = "text/plain"

  depends_on = [local_file.watch_plaso_to_s3_sh]
}


resource "local_file" "watch_to_timesketch_sh" {
  content  = data.template_file.watch_to_timesketch_sh.rendered
  filename = "${path.module}/output/timesketch/${var.watch_to_timesketch_sh_script}"
}

data "template_file" "watch_to_timesketch_sh" {
  template = file("${path.module}/files/timesketch/${var.watch_to_timesketch_sh_script}.tpl")

  vars = {
    s3_bucket         = aws_s3_bucket.staging.id
    region            = var.region
    timesketch_user   = var.timesketch_user
    timesketch_pass   = var.timesketch_pass
  }
}

resource "aws_s3_object" "watch_to_timesketch_sh" {
  bucket = aws_s3_bucket.staging.id
  key    = var.watch_to_timesketch_sh_script
  source = local_file.watch_to_timesketch_sh.filename
  content_type = "text/plain"

  depends_on = [local_file.watch_to_timesketch_sh]
}

resource "local_file" "velociraptor_kapefile" {
  content  = data.template_file.velociraptor_kapefile.rendered
  filename = "${path.module}/output/velociraptor/${var.velociraptor_kapefile}"
}

data "template_file" "velociraptor_kapefile" {
  template = file("${path.module}/files/velociraptor/${var.velociraptor_kapefile}.tpl")

  vars = {
    s3_bucket         = aws_s3_bucket.staging.id
    region            = var.region
    credkey           = aws_iam_access_key.velociraptor.id
    credsecret        = aws_iam_access_key.velociraptor.secret
  }
}

resource "aws_s3_object" "velociraptor_kapefile" {
  bucket = aws_s3_bucket.staging.id
  key    = var.velociraptor_kapefile
  source = local_file.velociraptor_kapefile.filename
  content_type = "text/plain"

  depends_on = [local_file.velociraptor_kapefile]
}

resource "aws_iam_policy" "s3_unrestricted_policy" {
  name        = "s3_unrestricted_policy"
  description = "A policy that allows unrestricted S3 actions"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "s3:*",
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_role" "ec2_role" {
  name = "ec2_s3_unrestricted_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_unrestricted_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}

# IAM User for Velociraptor
resource "aws_iam_user" "velociraptor" {
  name = "velociraptor_s3_access"
}

# Attach the S3 unrestricted policy to the user
resource "aws_iam_user_policy_attachment" "s3_user_policy_attachment" {
  user       = aws_iam_user.velociraptor.name
  policy_arn = aws_iam_policy.s3_unrestricted_policy.arn
}

# Create access key and secret for the user
resource "aws_iam_access_key" "velociraptor" {
  user = aws_iam_user.velociraptor.name
}

output "s3_access_key_id" {
  value = aws_iam_access_key.velociraptor.id
}

output "s3_secret_access_key" {
  value     = aws_iam_access_key.velociraptor.secret
  sensitive = true
}
