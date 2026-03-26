module "gp3_storage_class" {
  source = "../../../modules/storage-class"

  name                   = "gp3"
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  is_default_class       = false # true

  parameters = {
    type       = "gp3"
    fsType     = "ext4"
    iops       = "3000"
    throughput = "125"
    # encrypted  = "true"
  }

  #   depends_on = [
  #     module.ebs_csi_driver
  #   ]
}
