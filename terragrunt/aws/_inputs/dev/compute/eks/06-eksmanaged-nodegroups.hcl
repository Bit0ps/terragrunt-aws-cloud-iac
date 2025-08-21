locals {
  common_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")

  account_id = local.common_env_vars.locals.dev_account_id
  env        = local.common_env_vars.locals.dev_env
  org_name   = local.common_env_vars.locals.org_name

  ### EKS-MANAGED NODE GROUPS ###
  ### Ref: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/eks-managed-node-group
  eks_managed_node_groups = {
    "defaults" = {
      create                             = true
      ami_id                             = ""    # if not supplied, EKS will use its own default image
      ami_release_version                = null  # Defaults to latest AMI release version for the given Kubernetes version and AMI type
      use_latest_ami_release_version     = true  # Note: ami_type and cluster_version must be supplied in order to enable this feature
      use_name_prefix                    = false # Determines whether to use name as is or create a unique name beginning with the name as the prefix
      ami_type                           = "BOTTLEROCKET_x86_64"
      instance_types                     = ["c5.large"]
      max_size                           = 3
      min_size                           = 1
      desired_size                       = 0 # This value is ignored after the initial creation
      capacity_type                      = "ON_DEMAND"
      disk_size                          = 30 # Only valid when use_custom_launch_template = false
      disable_api_termination            = false
      ebs_optimized                      = true
      enable_efa_support                 = false # Determines whether to enable Elastic Fabric Adapter (EFA) support
      enable_efa_only                    = true  # v21 defaults to true; determines whether to enable EFA-only network interfaces
      efa_indices                        = [0]   # Only valid when enable_efa_support = true
      enable_monitoring                  = false
      force_update_version               = true # Force version update if existing pods are unable to be drained due to a pod disruption budget issue
      capacity_reservation_specification = {}
      cpu_options                        = {}
      credit_specification               = {}
      enclave_options                    = {} # Enable Nitro Enclaves on launched instances
      instance_market_options            = {}
      kernel_id                          = null
      license_specifications             = {}
      maintenance_options                = {}
      private_dns_name_options           = {} # The options for the instance hostname. The default values are inherited from the subnet
      ram_disk_id                        = ""
      taints                             = {} # Maximum of 50 taints per node group
      labels = {
        Environment                                  = "${local.env}"
        NodeGroup                                    = "EKSManaged"
        Karpenter                                    = "false"
        Bottlerocket                                 = "true"
        "bottlerocket.aws/updater-interface-version" = "2.0.0"
      }
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
        instance_metadata_tags      = "disabled"
      }
      timeouts = {
        create = "80m"
        update = "80m"
        delete = "80m"
      }
      update_config = {
        "max_unavailable_percentage" = 33
      }

      # IAM
      create_iam_role               = true
      create_iam_role_policy        = true
      iam_role_attach_cni_policy    = true
      iam_role_use_name_prefix      = false
      iam_role_path                 = "/"
      iam_role_permissions_boundary = null
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
      iam_role_policy_statements = []

      # SECURITY
      key_name               = "default-ssh-key-${local.env}"
      network_interfaces     = []
      remote_access          = {} # Configuration block with remote access settings. Only valid when use_custom_launch_template = false
      vpc_security_group_ids = []

      # BLOCK STORAGE
      block_device_mappings = []

      # LAUNCH TEMPLATE
      create_launch_template                 = true
      use_custom_launch_template             = true
      launch_template_use_name_prefix        = true
      update_launch_template_default_version = true
      launch_template_default_version        = null
      launch_template_description            = null
      launch_template_id                     = "" # The ID of an existing launch template to use. Required when create_launch_template = false and use_custom_launch_template = true
      launch_template_name                   = null
      launch_template_version                = null

      # PLACEMENT
      create_placement_group = false
      placement              = {}

      # BOOTSTRAP USERDATA
      enable_bootstrap_user_data = false # Only valid when using a custom AMI via ami_id
      user_data_template_path    = ""    # Path to a local, custom user data template file to use when rendering user data

      # Additional arguments passed to the bootstrap script. When ami_type = BOTTLEROCKET_*; these are additional settings that are provided to the Bottlerocket user data
      # https://bottlerocket.dev/en/os/1.26.x/api/settings/
      bootstrap_extra_args = <<-EOT
          # The admin host container provides SSH access and runs with "superpowers".
          # It is disabled by default, but can be disabled explicitly.
          [settings.host-containers.admin]
          enabled = true

          # The control host container provides out-of-band access via SSM.
          # It is enabled by default, and can be disabled if you do not expect to use SSM.
          # This could leave you with no way to access the API and change settings on an existing node!
          [settings.host-containers.control]
          enabled = true

          # extra args added
          [settings.kernel]
          lockdown = "integrity"
        EOT

      post_bootstrap_user_data = "" # User data that is appended to the user data script after of the EKS bootstrap script. Not used when ami_type = BOTTLEROCKET_*
      pre_bootstrap_user_data  = "" # User data that is injected into the user data script ahead of the EKS bootstrap script. Not used when ami_type = BOTTLEROCKET_*

      # CLOUDINIT
      # Initializes a node in an EKS cluster
      # Ref: https://awslabs.github.io/amazon-eks-ami/nodeadm/doc/api/
      ### Example:
      ### list(object({
      ###    content      = string
      ###    content_type = optional(string)
      ###    filename     = optional(string)
      ###    merge_type   = optional(string)
      ###  }))
      cloudinit_post_nodeadm = []
      cloudinit_pre_nodeadm  = []


      # TAGS
      tag_specifications = [
        "instance",
        "volume",
        "network-interface"
      ]
      iam_role_tags = {
        Environment = local.env
        NodeGroup   = "EKSManaged"
      }
      launch_template_tags = {
        Environment = local.env
        OS          = "Bottlerocket"
        NodeGroup   = "EKSManaged"
      }
      tags = {
        OS          = "Bottlerocket"
        NodeGroup   = "EKSManaged"
        Terraform   = "true"
        Environment = local.env
      }
    }

    #################################################
    ### EKS-MANAGED BOTTLEROCKETS NODE GROUPS №1
    #################################################
    "eksmanaged_bottlerocket_critical" = {
      create                     = true
      name                       = "ASG-${local.org_name}-eksmanaged-br-critical" # br stands for bottlerocket
      use_name_prefix            = true
      iam_role_name              = "EKSManagedCriticalNodeGroupRole"
      iam_role_description       = "EKS-managed bottlerocket node group IAM role. It should be used to run critical workload that is not allowed to be running on karpenter spot ec2 instances."
      instance_types             = ["t3.medium"]
      max_size                   = 5
      min_size                   = 2
      desired_size               = 2 # This value is ignored after the initial creation
      enable_bootstrap_user_data = true

      taints = {
        critical = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      labels = {
        Environment                   = "${local.env}"
        node-role                     = "critical"
        "karpenter.sh/controller"     = "true"
        "scheduler.karpenter.enabled" = "false"
        Bottlerocket                  = "true"
        PricingModel                  = "on-demand"
      }

      # Encrypted EBS volumes
      root_device_name                  = "/dev/xvda"
      root_volume_size                  = 20
      root_volume_type                  = "gp3"
      root_volume_iops                  = 3000
      root_volume_throughput            = 125
      root_volume_encrypted             = true
      root_volume_delete_on_termination = true

      container_device_name                  = "/dev/xvdb"
      container_volume_size                  = 30
      container_volume_type                  = "gp3"
      container_volume_iops                  = 3000
      container_volume_throughput            = 125
      container_volume_encrypted             = true
      container_volume_delete_on_termination = true

      # Tags
      iam_role_tags = {
        Environment = local.env
        Name        = "EKSManagedCriticalNodeGroupRole"
        NodeGroup   = "EKSManaged"
        UsedBy      = "EKS"
      }
      tags = {
        Environment = local.env
        Name        = "ASG-${local.org_name}-eksmanaged-br-critical"
      }
    }
  }
}