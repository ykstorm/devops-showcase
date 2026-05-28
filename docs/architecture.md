# Stackup — Architecture

## 1. Cluster topology

```mermaid
graph TD
    Dev[Developer machine] -->|kind create cluster| Kind[kind cluster<br/>3 nodes Docker containers]
    Kind --> CP[Control plane node]
    Kind --> W1[Worker node 1]
    Kind --> W2[Worker node 2]

    CP --> ETCD[etcd]
    CP --> API[API server]
    CP --> Sched[scheduler]
    CP --> CM[controller-manager]

    W1 --> Calico1[Calico CNI agent]
    W2 --> Calico2[Calico CNI agent]

    W1 --> Pods1[Workload pods]
    W2 --> Pods2[Workload pods]

    Dev -->|kubectl| API
    Dev -->|HTTPS hostPort 80/443| W1
```

kind launches 3 Docker containers — one control-plane + two workers. Each node is itself a Docker container running containerd + kubelet. Pods run inside the workers as containers-within-containers. The whole thing fits in ~3 GB of RAM.

## 2. GitOps tree (app-of-apps)

```mermaid
graph LR
    Git[Git repo] -->|ArgoCD watches| Root[root application]
    Root --> A1[cert-manager]
    Root --> A2[ingress-nginx]
    Root --> A3[sealed-secrets]
    Root --> A4[kube-prometheus-stack]
    Root --> A5[loki + promtail]
    Root --> A6[tempo]
    Root --> A7[argo-rollouts]
    Root --> A8[buyerchat workload]

    A8 -->|Rollout CRD| Argo[Argo Rollouts controller]
    Argo -->|progressive| Pods[canary replicas]

    classDef gitops fill:#dbeafe,stroke:#2563eb
    class Root,A1,A2,A3,A4,A5,A6,A7,A8 gitops
```

The root Application is the only thing applied by `make up`. Everything else is sync'd by ArgoCD from the git repo. That's the discipline: state lives in git, not in `kubectl apply` commands.

## 3. Progressive delivery flow

```mermaid
sequenceDiagram
    autonumber
    participant Dev as Developer
    participant Git as Git
    participant ArgoCD as ArgoCD
    participant AR as Argo Rollouts
    participant Prom as Prometheus
    participant Pods as Pods

    Dev->>Git: commit (bump image.tag)
    Git-->>ArgoCD: webhook / poll
    ArgoCD->>AR: apply Rollout resource
    AR->>Pods: scale canary 25%
    AR->>Prom: query error_rate over 60s
    alt error_rate < 0.5%
        Prom-->>AR: ok
        AR->>Pods: scale 50% → 75% → 100%
        AR-->>Dev: Rollout succeeded
    else error_rate spike
        Prom-->>AR: > threshold
        AR->>Pods: scale back to old version
        AR-->>Dev: Rollout aborted, reverted
    end
```

## 4. Observability triangle

```mermaid
graph TB
    Pod[buyerchat Pod] --> M["/api/metrics<br/>Prometheus scrape 30s"]
    Pod --> L["stdout (JSON)<br/>Promtail tail"]
    Pod --> T["OTLP gRPC :4317<br/>Tempo ingest"]

    M --> P[Prometheus]
    L --> LK[Loki]
    T --> TM[Tempo]

    P --> G[Grafana]
    LK --> G
    TM --> G

    G -->|drill: panel → logs| LK
    G -->|drill: log → trace_id| TM

    classDef tel fill:#fef3c7,stroke:#ca8a04
    classDef store fill:#dcfce7,stroke:#16a34a
    classDef view fill:#dbeafe,stroke:#2563eb
    class M,L,T tel
    class P,LK,TM store
    class G view
```

The triangle is the standard you'll find in any production-grade shop. Stackup ships it pre-wired.

## 5. Security posture

| Layer | Control |
|---|---|
| Pod admission | PSS (Pod Security Standards) `restricted` profile on workload namespaces |
| Network | NetworkPolicy `default-deny` on workload namespaces, explicit allow rules per service |
| Secrets | Sealed Secrets — secrets encrypted in git, decrypted only in-cluster |
| TLS | cert-manager self-signed CA (swap to ACME for production) |
| RBAC | Workload namespaces have no cluster-admin bindings |
| Image policy | (out of scope v1.0) — recommended: Cosign + admission webhook |

## 6. What's intentionally simplified

- **Single-cluster.** No multi-cluster, no Fleet, no cross-cluster GitOps. Add when you need it.
- **Single-tenant.** Workload namespace is a single tenant. Multi-tenant adds Network/RBAC policy noise.
- **No LoadBalancer.** kind doesn't have one. We use `hostPort` for ingress.
- **No persistent storage for the demo.** buyerchat's helm chart points to a non-existent DB on purpose — it runs degraded. The point isn't to be a working app; it's to be a working *cluster*.

## 7. What changes for production

When you take this to AWS EKS / GCP GKE / Azure AKS, change:
1. kind → managed K8s control plane (EKS / GKE / AKS)
2. self-signed ClusterIssuer → ACME (Let's Encrypt) via DNS-01
3. `hostPort` ingress → real LoadBalancer service type
4. Local volumes → CSI driver for cloud block storage
5. Single replica components → HA (Prometheus with Thanos, Loki with Boltdb-shipper)
6. RBAC bindings tightened (no full cluster-admin tokens)

See [docs/production-guide.md] (v1.3 roadmap) for the line-by-line diff.
