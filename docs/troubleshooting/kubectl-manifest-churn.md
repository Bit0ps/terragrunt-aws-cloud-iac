## kubectl_manifest churn (updates on every plan)

Cause:
- for_each keys derived from full document content or non-deterministic ordering.

Fix (use stable keys):
```hcl
# ensure deterministic order
# in generators: ls -1 ... | sort

# key by filename index
locals {
  nodepool_filenames = ["amd64-general.yaml", "arm64-general.yaml"] # generated
}
resource "kubectl_manifest" "karpenter_nodepools" {
  for_each  = { for i, d in data.kubectl_file_documents.nodepools.documents : local.nodepool_filenames[i] => d }
  yaml_body = sensitive(each.value)
}
```
Alternative:
- Key by metadata kind/name if unique: `${yamldecode(d).kind}/${yamldecode(d).metadata.name}`
- Avoid `force_new = true`; it increases churn.
