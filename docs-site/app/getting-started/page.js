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
        and deploys the buyerchat workload. The root ArgoCD Application is the
        only thing applied directly; ArgoCD syncs everything else from the git
        repo.
      </p>

      <h2>Map the hostnames</h2>
      <p>
        Add these entries to your hosts file (<code>/etc/hosts</code>, or{' '}
        <code>C:\Windows\System32\drivers\etc\hosts</code> on Windows):
      </p>
      <pre>
        <code>{`127.0.0.1 buyerchat.local.stackup.dev
127.0.0.1 grafana.local.stackup.dev
127.0.0.1 argocd.local.stackup.dev
127.0.0.1 prometheus.local.stackup.dev`}</code>
      </pre>

      <h2>Open the surfaces</h2>
      <ul>
        <li>
          <strong>buyerchat.local.stackup.dev</strong> — the workload. It
          returns 503 degraded because there is no database wired in. That
          response is expected.
        </li>
        <li>
          <strong>grafana.local.stackup.dev</strong> — RED metrics, Loki logs,
          and Tempo traces in one place.
        </li>
        <li>
          <strong>argocd.local.stackup.dev</strong> — the GitOps tree of six
          child apps.
        </li>
      </ul>

      <h2>Makefile targets</h2>
      <pre>
        <code>{`make help            # Show all targets
make up              # Create cluster + install platform + buyerchat
make down            # Tear down the kind cluster
make smoke           # Run smoke tests (requires cluster up)
make lint            # Lint all YAML + Helm charts
make rollout-status  # Watch the buyerchat canary progress`}</code>
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
          The buyerchat workload runs degraded with no database, on purpose. The
          cluster is the demo, not the app.
        </li>
      </ul>
    </>
  );
}
