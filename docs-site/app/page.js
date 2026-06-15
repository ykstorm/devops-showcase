export default function Home() {
  return (
    <>
      <span className="tag">kind · ArgoCD · Argo Rollouts · Prometheus</span>
      <h1>Stackup</h1>
      <p className="lede">
        A production-shaped Kubernetes stack that runs on your laptop. One{' '}
        <code>make up</code> brings up a kind cluster with GitOps, canary
        delivery, and full observability — for free.
      </p>

      <p>
        Managed Kubernetes starts around $200/month on cloud providers. Stackup
        runs the same control-plane patterns on kind, in Docker, on a single
        machine. The buyerchat workload deliberately runs degraded with no
        database. That is intentional: the cluster is the demo, not the app.
      </p>

      <h2>What it is</h2>
      <p>
        A kind-based cluster wired with a real ArgoCD app-of-apps over six child
        applications, Argo Rollouts canary progressive delivery, the
        kube-prometheus-stack for metrics, Loki for logs, Tempo for traces,
        cert-manager TLS, Sealed Secrets encrypted in git, and Calico
        NetworkPolicy enforcement. Pod Security Standards <code>restricted</code>{' '}
        applies on every workload namespace.
      </p>

      <h2>The components</h2>
      <table>
        <thead>
          <tr>
            <th>Layer</th>
            <th>Component</th>
            <th>Role</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Cluster</td>
            <td>kind on Docker</td>
            <td>Kubernetes nodes running in containers</td>
          </tr>
          <tr>
            <td>CNI</td>
            <td>Calico</td>
            <td>NetworkPolicy enforcement (ingress + egress)</td>
          </tr>
          <tr>
            <td>GitOps</td>
            <td>ArgoCD app-of-apps</td>
            <td>One root app manages six children; sync, prune, self-heal</td>
          </tr>
          <tr>
            <td>Progressive delivery</td>
            <td>Argo Rollouts</td>
            <td>Canary 25 to 100% with an analysis gate and auto-rollback</td>
          </tr>
          <tr>
            <td>Ingress</td>
            <td>ingress-nginx</td>
            <td>TLS termination over hostPort 80/443</td>
          </tr>
          <tr>
            <td>TLS</td>
            <td>cert-manager</td>
            <td>Self-signed ClusterIssuer, swap to ACME for production</td>
          </tr>
          <tr>
            <td>Secrets</td>
            <td>Sealed Secrets</td>
            <td>Encrypted in git, decrypted in-cluster</td>
          </tr>
          <tr>
            <td>Metrics</td>
            <td>kube-prometheus-stack</td>
            <td>Prometheus, Alertmanager, Grafana with RED dashboards</td>
          </tr>
          <tr>
            <td>Logs</td>
            <td>Loki + Promtail</td>
            <td>Pod stdout into Loki, viewed in Grafana</td>
          </tr>
          <tr>
            <td>Traces</td>
            <td>Tempo</td>
            <td>OTLP traces from workloads</td>
          </tr>
          <tr>
            <td>Workload</td>
            <td>buyerchat Helm chart</td>
            <td>Next.js demo app that exercises the cluster</td>
          </tr>
        </tbody>
      </table>

      <h2>Start here</h2>
      <div className="cards">
        <div className="card">
          <h3>
            <a href="/getting-started/">Getting Started</a>
          </h3>
          <p>Clone, run make up, and reach the cluster in about ten minutes.</p>
        </div>
        <div className="card">
          <h3>
            <a href="/architecture/">Architecture</a>
          </h3>
          <p>Cluster topology, the GitOps tree, and the observability flow.</p>
        </div>
        <div className="card">
          <h3>
            <a href="/gitops-canary/">GitOps &amp; Canary</a>
          </h3>
          <p>How a commit becomes a canary rollout with a Prometheus gate.</p>
        </div>
      </div>
    </>
  );
}
