export const metadata = {
  title: 'Getting Started — Stackup',
};

export default function GettingStarted() {
  return (
    <>
      <h1>Getting Started</h1>
      <p className="lede">
        Clone the repo, run one command, and reach a working cluster in about
        ten minutes. You need Docker and kubectl on the machine.
      </p>

      <h2>Bring it up</h2>
      <pre>
        <code>{`git clone https://github.com/ykstorm/stackup && cd stackup
make up`}</code>
      </pre>
      <p>
        <code>make up</code> creates the kind cluster, installs the platform,
        and deploys the <code>demo</code> workload (the canary subject). The
        root ArgoCD Application is the only thing applied directly; ArgoCD syncs
        everything else from the git repo.
      </p>

      <h2>Hostnames</h2>
      <p>
        The ingress hosts use <code>localtest.me</code>, which resolves to{' '}
        <code>127.0.0.1</code> automatically — no hosts file editing needed.
      </p>

      <h2>Open the surfaces</h2>
      <ul>
        <li>
          <strong>grafana.localtest.me</strong> — RED metrics from
          Prometheus. Logs and traces (Loki, Tempo) are on the roadmap, not
          installed yet.
        </li>
        <li>
          <strong>argocd.localtest.me</strong> — the GitOps tree of six
          child apps.
        </li>
        <li>
          The <code>demo</code> workload has no ingress. Reach it with{' '}
          <code>kubectl -n app port-forward svc/demo 3000:3000</code>, then{' '}
          <code>curl localhost:3000/metrics</code> to see{' '}
          <code>http_requests_total</code>.
        </li>
      </ul>

      <h2>Makefile targets</h2>
      <pre>
        <code>{`make help            # Show all targets
make up              # Create cluster + install platform + demo
make down            # Tear down the kind cluster
make smoke           # Run smoke tests (requires cluster up)
make lint            # Lint all YAML + Helm charts
make rollout-status  # Watch the demo canary progress`}</code>
      </pre>

      <h2>Known limits</h2>
      <ul>
        <li>
          No real LoadBalancer service type — kind does not ship one, so the
          stack uses hostPort. Deploy to a cloud cluster for a real load
          balancer.
        </li>
        <li>
          Storage is local-path PVs by default. Re-creating the cluster wipes
          them. Add Longhorn or OpenEBS for persistence across teardowns.
        </li>
        <li>
          Single-tenant workload namespace. Multi-tenant needs more
          NetworkPolicy and RBAC work.
        </li>
        <li>
          The <code>demo</code> workload is a stand-in for your real service —
          it exists to drive the canary, not to be a product. The cluster is the
          point, not the app.
        </li>
      </ul>
    </>
  );
}
