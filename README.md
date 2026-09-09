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
| Database | Azure SQL Managed Instance, General Purpose, private only | `modules/sql-managed-instance` |
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
   ┌───────────────┬─────────────────┬───────────┴────────────┐
   │ snet-aks-      │ snet-aks-web    │ snet-sqlmi             │
   │ backoffice     │                 │ (delegated,           │
   │  AKS + LB      │  AKS + LB       │  SQL Managed Instance) │
   └───────────────┴─────────────────┴────────────────────────┘
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
    ├── iis/
    └── application-gateway/
```

## Prerequisites

1. **Terraform >= 1.6** and the **azurerm ~> 4.0** provider.
2. Azure CLI authenticated (`az login`) with **Owner** / **Contributor + User Access Administrator** on the target subscription.
3. Providers registered: `Microsoft.ContainerService`, `Microsoft.Sql`, `Microsoft.Network`, `Microsoft.OperationalInsights`.
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

## Secrets

`sql_managed_instance.administrator_login_password` and `iis.admin_password` are
**auto‑generated** (`random_password`) when left unset and surfaced as sensitive
outputs:

```bash
terraform output -raw sql_admin_password
terraform output -raw iis_admin_password
```

For production, move these to Azure Key Vault and reference them instead of
storing generated values in state.

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
