## Private EKS connectivity

Symptoms: "Kubernetes cluster unreachable" or helm/kubectl providers cannot connect.

Checklist:
- Use VPN: connect via the OpenVPN EC2 instance (see Getting Started 04)
- Alternatively, run Terragrunt inside the VPC (SSM Session Manager, runner in VPC)
- Temporarily allow your public IP on the EKS endpoint (if you enabled public access with CIDR allowlist)
- Ensure helm/kubernetes providers are configured with EKS token exec as generated
