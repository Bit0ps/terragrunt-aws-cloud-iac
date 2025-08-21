## 07. Post-deploy checks

- Karpenter controller running:
```bash
kubectl -n kube-system get deploy karpenter
```
- NodePools and EC2NodeClasses applied:
```bash
kubectl get nodepools -A
kubectl get ec2nodeclasses -A
```
- Schedule a test workload and observe dynamic node provisioning.
