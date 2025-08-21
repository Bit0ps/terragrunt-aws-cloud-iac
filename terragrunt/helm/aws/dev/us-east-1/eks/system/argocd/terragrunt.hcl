terraform {
  source = "${get_path_to_repo_root()}/terragrunt/vendor/modules/tf-aws-helm-release//."
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  release_name  = "argo-cd"
  chart         = "argo-cd"
  chart_version = "6.9.2"
  repository    = "https://argoproj.github.io/argo-helm"

  create_namespace_with_kubernetes = true
  kubernetes_namespace             = "argocd"

  values = [
    file("${get_path_to_repo_root()}/terragrunt/_inputs/dev/helm/values/argocd.yaml")
  ]
}


