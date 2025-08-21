# Innovate Inc. — AWS Architecture Design

**Purpose:** A secure, cost-aware, multi-account AWS platform for containerized workloads with clear separation of duties, GitOps delivery, and managed data services.

---

## Cloud Environment Structure

**Goal:** Strong isolation, clear ownership, simple billing, and central platforms for shared assets.

- **Management (root):** AWS Organizations, billing, SCP governance (restricted).
- **Infrastructure OU**
  - **Identity Account:** IAM Identity Center (SSO); cross-account access via assume-role only.
  - **Shared Services Account:** Central ECR (images & Helm charts), shared S3 (artifacts/assets), CI/CD keys, AMI pipelines, cross-account image replication.
- **Security OU**
  - **Log Archive:** Immutable CloudTrail/Config.
  - **Security Tools:** Delegated admin for GuardDuty, Security Hub, Detective.
- **Workloads OU**
  - **Sandbox, Dev, Staging, Production** in separate accounts for isolation, budgets, and scoped policies.
  - **Production isolation:** Most restricted; no shared registries or VPN with lower environments.

---

## Network Design

### VPC Architecture
- **Custom VPCs (no default)** per account/environment, spanning **3 AZs**.
- **Subnet tiers:**  
  - **Public:** ALB/NAT  
  - **Private:** EKS nodes/apps  
  - **Isolated:** Aurora/ElastiCache (no internet)
- **NAT strategy:** Dev/Staging → single NAT (cost). Production → NAT per AZ (resilience; avoids cross-AZ egress).
- **EKS API:** **Private-only** (no public endpoint).
- **VPC Endpoints:** S3 (gateway) and interface endpoints (STS/ECR/CloudWatch/Secrets Manager) to keep service traffic internal.
- **DNS:** Private Route 53 + cross-account Resolver rules for service discovery.

### Secure Access & Edge
- **VPN access (organizational options):** **AWS Client VPN**, **OpenVPN**, **WireGuard**, or **PritunlVPN**.  
  - **Production:** **Dedicated VPN** endpoint and auth groups (not shared) for maximum isolation.
- **Edge protection:**  
  - Default: **CloudFront → AWS WAF → ALB (per app/cluster)**  
  - Alternative: **Cloudflare WAF/CDN → ALB** with origin locked (mTLS/Tunnel)
- **Ingress to Kubernetes:** AWS Load Balancer Controller provisions public/internal ALBs as needed.
- **East–west:** Security Groups baseline; **Kubernetes NetworkPolicies** for pod-level segmentation.
- **Ops access:** No bastions; break-glass via **SSM Session Manager**.

---

## Compute Platform (Kubernetes on EKS)

### Cluster & Capacity
- **Topology:**  
  - **Recommended:** One EKS cluster **per environment** (Dev, Staging, Prod).  
  - **Cost option:** **Dev & Staging may share a cluster** with strict isolation; **Production always dedicated**.
- **Managed add-ons:** EKS Pod Identity, VPC CNI, CoreDNS, kube-proxy, EBS CSI.
- **Nodes:** On-Demand baseline for critical workloads; Spot for burst/stateless. **Karpenter** for just-in-time capacity; separate pools for **amd64/arm64**, zonal spread.

### Scaling, Allocation & Guardrails
- **Autoscaling:** HPA for CPU/memory; **KEDA** for event-driven scaling (e.g., SQS/Prometheus).
- **Resource policies:** **Namespace quotas, LimitRanges, PriorityClasses**, and **image pull by digest**.
- **Kyverno & NetworkPolicies:**  
  - **Kyverno** enforces platform rules (e.g., require CPU/memory requests/limits, forbid privileged pods, require signed images/digests) and **governs explicit cross-namespace communication** via approved labels/policies.  
  - **NetworkPolicies** define **allowed traffic paths between namespaces** (service-to-service flows only) to prevent lateral movement and uphold least-privilege networking.

### Containerization & Delivery
- **Build & push:** **GitHub Actions** builds **Docker/Podman** images → pushes to **private ECR** (Shared Services).
- **Security pipelines in CI:**  
  - **SCA:** choose one — **Trivy**, **Snyk**, or **Docker Scout** (vulnerabilities + SBOM).  
  - **SAST:** **SonarQube** for quality/security gating (optionally **CodeQL** or **Semgrep**).  
  - **DAST:** **OWASP ZAP** or **Burp Suite** against **Staging** to catch runtime/config issues.
- **GitOps deploy:** **Argo CD** (pull-based) with **ApplicationSets** for multi-env rollouts and **AppProjects** to **isolate apps per project** (RBAC, allowed repos/clusters, quotas).
- **Charts:** Helm charts published as **OCI** artifacts in ECR.

---

## Database

**Service:** **Amazon Aurora PostgreSQL Serverless v2** with **RDS Proxy**

**Why RDS Proxy:** Smooths failovers and protects Aurora from connection storms by pooling/reusing connections. This keeps the DB stable under spiky load and reduces failover impact as traffic scales.

### Environment Strategy

- **Development**
  - **PostgreSQL via Helm in Kubernetes** (not Aurora): packaged as a chart with a **PersistentVolumeClaim (PVC)** for storage.
  - Rationale: lowest cost, easy reset/seed; no HA/RPO/RTO requirements.

- **Staging**
  - **Aurora PostgreSQL Serverless v2** with **automated backups enabled**.
  - **Restore model:** rely on **snapshots/PITR** to recreate the cluster when needed (no strict RPO/RTO).
  - No cross-region replication by default (cost saving).

- **Production**
  - **Aurora PostgreSQL Serverless v2** (Multi-AZ) + **RDS Proxy**.
  - **Read scaling & HA:**
    - **Start with 1 reader** instance in a **different AZ** (serverless v2) and **add more readers as load grows**.
    - Use the **cluster reader endpoint** for read traffic; keep the app’s writes on the writer endpoint.
    - Set **promotion tiers** so at least one reader is eligible for **immediate promotion** (fast failover).
    - Keep a **small ACU floor** on the primary reader so it can take over quickly, and let it **scale up on demand**.
    - (Optional) If you expect very high read connection counts, run a **second RDS Proxy** targeting **READ-ONLY** to pool reader connections.
  - **High availability:** Multi-AZ with automatic failover; RDS Proxy helps keep connections stable during failover.
  - **Backups (PITR):**
    - Automated backups with **Point-in-Time Recovery**; retention **14 days** (tunable).
    - **AWS Backup** daily snapshot + **pre-deploy on-demand snapshots** before schema changes.
  - **Disaster Recovery (cost-optimized primary: Backup & Restore)**
    - **Cross-account** snapshot copy: **daily** (protects against account compromise).
    - **Cross-region** snapshot copy: **weekly** by default (tighten to daily/4-hourly if risk justifies cost).
    - **Targets:**  
      - **Intra-region failures (AZ/instance):** **RPO ≈ 0**, **RTO ≤ ~2 min** via Multi-AZ failover.  
      - **Regional disaster (restore from snapshot):** **RPO ≤ 24h** (improves with more frequent copies), **RTO ~1–3h** to restore and cut over.
  - **Upgrade path (higher resilience, higher cost):**
    - **Aurora Global Database (pilot-light or warm-standby):** near-zero RPO (seconds) and **sub-minute RTO**. Keep minimal capacity in DR region (serverless low floor), scale on failover.

**Notes**
- Encrypt everything at rest (KMS per environment) and in transit.
- Quarterly **restore tests** (staging of prod backups) to validate RTO and playbooks.
- Secrets for DB access are delivered via the platform’s **Secrets Management** choice (Vault+ESO or AWS Secrets Manager via ASCP) and **Pod Identity**; no static credentials in pods.

---

## Secrets Management

- **Primary:** **HashiCorp Vault** + **External Secrets Operator (ESO)** with **Pod Identity** for centralized, secure, K8s-native injection and cross-platform rotation/audit.
- **Alternative:** **AWS Secrets Manager** or **SSM Parameter Store** via **Secrets Store CSI (ASCP)** + **Pod Identity** for AWS-native simplicity.
- **Decision rule:** Choose **Vault** when cross-platform rotation/audit is required; choose **ASCP** for minimal AWS-native ops with lower operational overhead.

---

## Async Processing & Microservices

**Pattern:** API services and workers are decoupled for responsiveness and resilience.

- **Services:** Python/Flask (API) and **Celery workers** as separate Deployments for independent scaling.
- **Broker/queue:** **Amazon SQS** (durable, serverless); access via **Pod Identity** (no static creds).
- **Scaling:** **KEDA** scales workers on SQS metrics; HPA for CPU/memory on APIs.

---

## Caching — ElastiCache (Valkey Serverless)

**Use cases:** Sessions, token caches, rate limiting, hot reads.  
**Why:** Microsecond latency, automatic scaling, low operational overhead/cost floor.

- **Placement:** **Isolated subnets**; TLS in-transit; apps fetch endpoints/creds via Pod Identity + secrets integration.
- **Ops:** Key namespaces and sensible TTLs; monitor hit ratio and latency with basic SLOs.

---
## Diagrams
- [Production infrastructure (HLD)](diagrams/prod-infra-hld.md)
- [AWS organization (HLD)](diagrams/aws-org-hld.md)