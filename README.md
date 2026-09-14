# Playterry — Production Infrastructure (Terraform)

Terraform for the **Playterry** production environment on Azure.

## What it builds

| Component | Resource | Notes |
|---|---|---|
| Hub network | 1 VNet, 6 subnets, NSGs, route table | `modules/network` |
| P2S VPN | Virtual Network Gateway (`Vpn` / `RouteBased`) + OpenVPN + Entra ID auth | `modules/vpn-p2s` |
| Backoffice cluster | Private AKS, system + workload node pools, autoscaling, zones 1‑3 | `modules/aks` |
| Web cluster | Private AKS (user‑facing apps), same shape | `modules/aks` |
| Cluster ingress | 1 Standard Azure Load Balancer per cluster (internal by default) | `modules/loadbalancer` |
| Database | Azure SQL Managed Instance, General Purpose, private only + per-database provisioning | `modules/sql-managed-instance` |
| Cache | Azure Cache for Redis, Standard C3 (6 GB), private endpoint only | `modules/redis` |
| Web tier | 2 Windows Server 2022 VMs, IIS role auto‑installed, availability set | `modules/iis` |
| Web ingress | Application Gateway v2 (WAF by default), public frontend → IIS pool | `modules/application-gateway` |
| Observability | Log Analytics workspace wired to both clusters | root `main.tf` |

### Topology

```
                Internet
                   │
          ┌────────┴─────────┐
          │ Application GW v2 │  (public IP, WAF_v2)
          │   snet-appgw      │
          └────────┬─────────┘
                   │ 80
        ┌──────────┴───────────┐
        │  IIS-01     IIS-02    │  Windows/IIS, availability set
        │       snet-iis        │
        └──────────────────────┘

  Operators ── P2S VPN (Entra ID) ──► VpnGw ──► VNet 10.10.0.0/16
                                                 │
   ┌───────────────┬─────────────────┬───────────┴───┬────────────────┐
   │ snet-aks-      │ snet-aks-web    │ snet-sqlmi    │ snet-redis     │
   │ backoffice     │                 │ (delegated,   │ (private       │
   │  AKS + LB      │  AKS + LB       │  SQL MI)      │  endpoint →    │
   │               │                 │               │  Redis)        │
   └───────────────┴─────────────────┴───────────────┴────────────────┘
```

### Default address plan (`10.10.0.0/16`)

| Subnet | CIDR | Purpose |
|---|---|---|
| `snet-aks-backoffice` | `10.10.0.0/20`  | Backoffice AKS nodes (Azure CNI **overlay**) |
| `snet-aks-web`        | `10.10.16.0/20` | Web AKS nodes |
| `snet-appgw`          | `10.10.32.0/24` | Application Gateway |
| `snet-iis`            | `10.10.33.0/24` | IIS VMs |
| `snet-sqlmi`          | `10.10.34.0/24` | SQL Managed Instance (delegated) |
| `GatewaySubnet`       | `10.10.35.0/27` | VPN gateway |
| `snet-redis`          | `10.10.36.0/24` | Redis private endpoint |
| VPN client pool       | `172.16.0.0/24` | Handed to connected clients (no overlap) |
| K8s service CIDR      | `10.0.0.0/16`   | Cluster-internal, not routed |
| K8s pod CIDR (overlay)| `10.244.0.0/16` | Cluster-internal, not routed |

## Layout

```
.
├── main.tf / variables.tf / outputs.tf   # root – wires the modules together
├── providers.tf / versions.tf / backend.tf
├── terraform.tfvars.example
└── modules/
    ├── network/
    ├── vpn-p2s/
    ├── aks/
    ├── loadbalancer/
    ├── sql-managed-instance/
    ├── redis/
    ├── iis/
    └── application-gateway/
```

## Prerequisites

1. **Terraform >= 1.6** and the **azurerm ~> 4.0** provider.
2. Azure CLI authenticated (`az login`) with **Owner** / **Contributor + User Access Administrator** on the target subscription.
3. Providers registered: `Microsoft.ContainerService`, `Microsoft.Sql`, `Microsoft.Network`, `Microsoft.OperationalInsights`, `Microsoft.Cache`.
4. For the VPN: the **Azure VPN** enterprise application must be consented in your tenant
   (`https://learn.microsoft.com/azure/vpn-gateway/openvpn-azure-ad-tenant` — grant admin consent once).
5. A remote state backend (see `backend.tf`) — an Azure Storage account + container.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: subscription_id + vpn.aad_tenant_id are mandatory

terraform init      # after filling in backend.tf
terraform plan  -out tf.plan
terraform apply tf.plan
```

Expect the first apply to take **3–6 hours** — the SQL Managed Instance and the
VPN gateway are the long poles. Everything else finishes in ~15–25 min.

### Connecting

* **kubectl** – clusters are **private**. Connect the VPN first, then:
  ```bash
  az aks get-credentials -g playterry-prod-rg -n playterry-prod-web-aks
  ```
  P2S clients must resolve the cluster's private FQDN. Either use Azure‑provided
  DNS on the client, or add the AKS private DNS zone
  (`*.privatelink.<region>.azmk8s.io`) to your resolver. Set
  `aks_defaults.private_cluster_enabled = false` if you need a public API endpoint instead.
* **IIS** – RDP over the VPN to the private IPs (`terraform output iis_private_ips`),
  or browse the app through `terraform output application_gateway_public_ip`.
* **SQL MI** – reachable on port 1433 at `terraform output sql_managed_instance_fqdn`
  from inside the VNet / over the VPN only.
* **Redis** – TLS only (`terraform output redis_hostname` : `terraform output redis_ssl_port`,
  6380). Resolves to the private endpoint via the `privatelink.redis.cache.windows.net`
  private DNS zone, so it works from AKS pods and from P2S clients that use Azure DNS.
  `terraform output -raw redis_primary_connection_string` for the app config value.

### Wiring app traffic to the per‑cluster load balancer

Each cluster gets a dedicated **internal Standard Load Balancer**
(`playterry-prod-<cluster>-lb`). AKS attaches node endpoints to it when you create
a Kubernetes `Service` that targets it:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-frontend
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    # pin the Service to this module's subnet
    service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "snet-aks-web"
spec:
  type: LoadBalancer
  loadBalancerIP: <lb_web.frontend_ip>   # from `terraform output lb_web`
  ports:
    - port: 80
      targetPort: 8080
```

Set `load_balancer.type = "public"` if a given cluster should be reachable
directly from the internet instead of only over the VPN.

## SQL Managed Instance databases

Databases are declared in the `sql_databases` map (variable) and created with
`azurerm_mssql_managed_database`. It is empty by default — add entries once the
application databases are decided:

```hcl
sql_databases = {
  DailyActionsDB        = {}
  DBA                   = {}
  ProgressPlayDBArchive = { short_term_retention_days = 14 }
  SystemParametersDB    = {}
  WiseSpinDB = {
    long_term_retention_policy = {
      weekly_retention  = "P4W"
      monthly_retention = "P12M"
      yearly_retention  = "P5Y"
      week_of_year      = 1
    }
  }
}
```

Per database you can set `collation` (ForceNew), `short_term_retention_days`
(1–35, point-in-time-restore window) and a `long_term_retention_policy`.
`terraform output sql_databases` lists what was created. Removing a key from the
map **deletes** that database on the next apply.

## Managed Redis

`modules/redis` provisions **Azure Cache for Redis** and exposes it through a
**private endpoint** in `snet-redis` — `public_network_access_enabled = false`,
non-TLS port disabled, TLS floor 1.2. The module also creates the
`privatelink.redis.cache.windows.net` private DNS zone and links it to the hub
VNet, so `redis_hostname` resolves to the private IP everywhere in the VNet.

Sizing is the `redis` object variable. It defaults to **Standard C3 (6 GB)**,
covering the ~4 GB working-set estimate:

```hcl
redis = {
  sku_name = "Standard"  # "Standard" | "Basic" | "Premium"
  family   = "C"         # "C" for Basic/Standard, "P" for Premium
  capacity = 3           # C1=1GB C2=2.5GB C3=6GB C4=13GB
  # maxmemory_policy = "allkeys-lru"
}
```

Premium adds zone redundancy, data persistence and VNet injection. To move up:
`redis = { sku_name = "Premium", family = "P", capacity = 1, zones = ["1","2","3"] }`
(P1 is also 6 GB).

## Secrets

`sql_managed_instance.administrator_login_password` and `iis.admin_password` are
**auto‑generated** (`random_password`) when left unset and surfaced as sensitive
outputs:

```bash
terraform output -raw sql_admin_password
terraform output -raw iis_admin_password
```

Redis access keys are managed by Azure, not generated here; read them with
`terraform output -raw redis_primary_access_key` /
`terraform output -raw redis_primary_connection_string`.

For production, move these to Azure Key Vault and reference them instead of
storing generated values in state.

## Cost estimate

Order-of-magnitude only — **USD list prices, not a live quote**. Assumes West
Europe, pay-as-you-go (no reservations, no Azure Hybrid Benefit), 730 h/month,
autoscalers at their **minimum** node counts, bandwidth/egress excluded.

| Component | Config (repo defaults) | ~USD/mo |
|---|---|---:|
| AKS control plane | 2 clusters x Standard tier | 145 |
| AKS nodes - backoffice | 2x D4s_v5 (system) + 2x D8s_v5 (workload) | 840 |
| AKS nodes - web | 2x D4s_v5 + 2x D8s_v5 | 840 |
| AKS node OS disks | ~8x managed disks | 150 |
| AKS egress LBs + public IPs | 1 Standard LB + IP per cluster | 50 |
| Internal load balancers | `lb_backoffice` + `lb_web` (Standard) | 40 |
| P2S VPN gateway | VpnGw1 / Generation1 + public IP | 145 |
| **SQL Managed Instance** | GP_Gen5, 4 vCore, `LicenseIncluded` | **1,470** |
| SQL MI storage + backups | 256 GB + PITR | 40 |
| Redis | Standard C3 (6 GB) + private endpoint + DNS zone | 250 |
| IIS | 2x D2s_v5 Windows + StandardSSD disks | 300 |
| Application Gateway | WAF_v2, min 2 capacity units + public IP | 350 |
| Log Analytics | Container Insights ingest (2 clusters) - **highly variable** | 150-600 |
| Misc public IPs / private DNS | | 15 |
| **Baseline total** | | **~$5,000/mo** (+/- $500, mostly Log Analytics) |

**Ceiling (max autoscale):** workload pools 2->6 D8s_v5 per cluster, system
pools 2->4, App Gateway to 10 CU, heavier log ingest -> **~$8,000-9,500/mo**.

**Biggest levers:**

| Change | Saving |
|---|---:|
| `sql_managed_instance.license_type = "BasePrice"` + Azure Hybrid Benefit | ~$700/mo |
| 1-yr reserved capacity / savings plan on SQL MI + AKS D-series nodes | ~30-40% of compute |
| Spot or `aks_defaults.workload_node_min_count = 1` on the web pool | ~$280-560/mo |
| Log Analytics daily cap / Basic Logs / trim Container Insights | up to ~$300/mo |
| Burstable B-series for IIS if the web tier is light | ~$180/mo |
| Redis Basic C3 (no replica, no SLA) | ~$120/mo |

**Not included:** outbound/cross-zone bandwidth, Microsoft Defender for Cloud
(~$50-100/mo here if enabled), TF remote-state storage, Azure Monitor alerts,
extra snapshots/backups, any DDoS Protection plan.

For an authoritative figure run [`infracost breakdown --path .`](https://www.infracost.io/)
(it reads `terraform.tfvars`), or price the table above in the Azure Pricing
Calculator for your region and discount agreement.

## Notable choices / assumptions

* **Private AKS** by default — access is over the P2S VPN, matching the brief.
* **Azure CNI Overlay + Calico** — pod IPs don't consume subnet space.
* **VPN auth = Microsoft Entra ID / OpenVPN**. Certificate auth is not wired;
  swap the `vpn_client_configuration` block in `modules/vpn-p2s` if you need it.
* **App Gateway listener is HTTP:80** only. Add a `frontend_port`/`http_listener`
  for 443 plus an `ssl_certificate` (Key Vault reference) before going live.
* **VPN SKU `VpnGw1` / `Generation1`**. Bump to `VpnGw2`+ / `Generation2` for
  higher throughput and more P2S connections.
* Both clusters share the (non‑routed) service and pod CIDRs — this is safe and
  keeps the address plan simple.

## Terraform was not available in the authoring environment

`terraform validate` / `fmt` were not run here. Run both after `terraform init`:

```bash
terraform fmt -recursive
terraform validate
```
