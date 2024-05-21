## Terraform for scripts to bootstrap
locals {

  # Windows systems 
  templatefiles_win = [
    
    {
      name = "${path.module}/files/windows/red.ps1.tpl"
      variables = {
        s3_bucket = "${aws_s3_bucket.staging.id}"
      }
    },
    {
      name = "${path.module}/files/windows/velociraptor.ps1.tpl"
      variables = {
        s3_bucket        = "${aws_s3_bucket.staging.id}"
        region           = var.region
        client_config    = var.vserver_config
        client_uri       = local.vdownload_client
        windows_msi      = local.msi_file
      }
    },
    
  ]

  script_contents_win = [
    for t in local.templatefiles_win : templatefile(t.name, t.variables)
  ]

  script_output_generated_win = [
    for t in local.templatefiles_win : "${path.module}/output/windows/${replace(basename(t.name), ".tpl", "")}"
  ]

  # reference in the main user_data for each windows system
  script_files_win = [
    for tf in local.templatefiles_win :
    replace(basename(tf.name), ".tpl", "")
  ]
}

resource "local_file" "generated_scripts_win" {
  count = length(local.templatefiles_win)
  filename = local.script_output_generated_win[count.index]
  content  = local.script_contents_win[count.index]
}
