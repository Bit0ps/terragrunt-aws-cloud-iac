## 04. OpenVPN (private access)

EKS API is private; connect via VPN to deploy cluster add-ons (e.g., Karpenter).

### Deploy OpenVPN EC2 instance
```bash
cd terragrunt/aws/dev/us-east-1/compute/ec2
terragrunt init
terragrunt plan
terragrunt apply -auto-approve
```

### Security group and private EKS access
- The EC2 instance is attached to a dedicated OpenVPN security group created via a reusable security group module in `terragrunt/aws/dev/us-east-1/security/security-groups/openvpn/`.
- The SG allows inbound OpenVPN (default UDP 1194) and SSH (for EC2 Instance Connect), and egress needed to reach the private EKS endpoint (TCP 443) inside the VPC.
- With this SG in place, once your OpenVPN client is connected, Helm/kubectl providers can reach the EKS API over the VPN.

### OpenVPN installation under the hood
- The instance `userdata/openvpn.sh` downloads and runs the widely-used installer:
  - angristan/openvpn-install [GitHub repository](https://github.com/angristan/openvpn-install)
- The script bootstraps the server and lets you generate client `.ovpn` files that you’ll import into your local OpenVPN client. See its README for advanced options and headless mode.

### Use the installer (EC2 Instance Connect)
1) From the AWS Console, open the EC2 instance and click “Connect” → “EC2 Instance Connect” → “Connect”.
2) Run the installer as root and follow prompts (or set `AUTO_INSTALL=y`):
```bash
sudo /openvpn-install.sh
```
3) When prompted, create a client profile. The installer outputs a `.ovpn` file (typically under `/ec2-user/`).
4) Download the `.ovpn` file (EC2 Instance Connect “Download” or `scp`) to your workstation.

### Install OpenVPN client
- macOS: Tunnelblick, Viscosity or OpenVPN Connect
- Linux: openvpn package
- Windows: OpenVPN GUI

### Connect to AWS VPC
- Import the `.ovpn` config and connect.
- Verify EKS API access later with `kubectl`.

Notes:
- Consider restricting the OpenVPN SG inbound CIDRs in production.
- If you prefer not to expose UDP 1194, use an EC2 Instance Connect Endpoint or a private runner to execute Terragrunt inside the VPC.
