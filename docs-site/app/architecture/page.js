export const metadata = {
  title: 'Architecture — Stackup',
};

export default function Architecture() {
  return (
    <>
      <h1>Architecture</h1>
      <p className="lede">
        Cluster topology, the GitOps tree, the observability flow, and the
        security posture — all of it reproducible from <code>make up</code>.
      </p>

      <h2>Cluster topology</h2>
      <p>
        kind launches the cluster as Docker containers, each node running
        containerd and kubelet. Pods run inside the worker nodes as
        containers-within-containers. The cluster declares{' '}
        <code>disableDefaultCNI: true</code> and installs Calico, which enforces
        ingress and egress NetworkPolicy rules in full. The whole thing fits in
        roughly 3 GB of RAM.
      </p>

      <h2>GitOps tree (app-of-apps)</h2>
      <p>
        A single root ArgoCD Application is the only thing <code>make up</code>{' '}
        applies. It manages six child applications, and ArgoCD syncs each of
        them from the git repo:
      </p>
      <ul>
        <li>cert-manager — TLS issuance</li>
        <li>ingress-nginx — ingress and TLS termination</li>
        <li>sealed-secrets — in-cluster secret decryption</li>
        <li>kube-prometheus-stack — Prometheus, Alertmanager, Grafana</li>
        <li>Loki + Promtail / Tempo — logs and traces</li>
        <li>argo-rollouts — the canary controller</li>
        <li>buyerchat — the demo workload</li>
      </ul>
      <p>
        The discipline is that state lives in git, not in ad-hoc{' '}
        <code>kubectl apply</code> commands. ArgoCD runs automated sync, prune,
        and self-heal against what the repo declares.
      </p>

      <h2>Observability flow</h2>
      <p>
        Each workload pod feeds three signals into the stack, and Grafana ties
        them together:
      </p>
      <table>
        <thead>
          <tr>
            <th>Signal</th>
            <th>Path</th>
            <th>Store</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Metrics</td>
            <td>/api/metrics scraped every 30s</td>
            <td>Prometheus</td>
          </tr>
          <tr>
            <td>Logs</td>
            <td>Pod stdout (JSON), tailed by Promtail</td>
            <td>Loki</td>
          </tr>
          <tr>
            <td>Traces</td>
            <td>OTLP gRPC on :4317</td>
            <td>Tempo</td>
          </tr>
        </tbody>
      </table>
      <p>
        From a Grafana panel you can drill into the matching logs, and from a
        log line you can jump to the trace by its trace_id.
      </p>

      <h2>Security posture</h2>
      <table>
        <thead>
          <tr>
            <th>Layer</th>
            <th>Control</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Pod admission</td>
            <td>
              Pod Security Standards <code>restricted</code> on workload
              namespaces
            </td>
          </tr>
          <tr>
            <td>Network</td>
            <td>
              NetworkPolicy <code>default-deny</code>, explicit allow rules per
              service
            </td>
          </tr>
          <tr>
            <td>Secrets</td>
            <td>Sealed Secrets — encrypted in git, decrypted in-cluster</td>
          </tr>
          <tr>
            <td>TLS</td>
            <td>cert-manager self-signed CA (swap to ACME for production)</td>
          </tr>
          <tr>
            <td>RBAC</td>
            <td>No cluster-admin bindings on workload namespaces</td>
          </tr>
        </tbody>
      </table>

      <h2>What changes for production</h2>
      <p>
        Taking the stack to EKS, GKE, or AKS means swapping kind for a managed
        control plane, the self-signed issuer for ACME via DNS-01, hostPort
        ingress for a real LoadBalancer, local volumes for a CSI driver,
        single-replica components for HA, and loosening nothing on the RBAC
        side.
      </p>
    </>
  );
}
