export const metadata = {
  title: 'GitOps & Canary — Stackup',
};

export default function GitopsCanary() {
  return (
    <>
      <h1>GitOps &amp; Canary</h1>
      <p className="lede">
        How a single commit turns into a canary rollout gated on Prometheus,
        with automatic rollback when the analysis fails.
      </p>

      <h2>The trigger</h2>
      <p>
        Push a commit that bumps <code>helm/buyerchat/values.yaml</code>{' '}
        <code>image.tag</code>. ArgoCD notices the change and syncs. Argo
        Rollouts applies the new Rollout revision. Watch it advance:
      </p>
      <pre>
        <code>{`make rollout-status
# same as: kubectl argo rollouts get rollout buyerchat -n app --watch`}</code>
      </pre>

      <h2>The canary steps</h2>
      <p>
        Argo Rollouts shifts 25% of traffic to the new version and pauses, then
        runs an analysis step. An <code>AnalysisTemplate</code> queries
        Prometheus three times over 90 seconds. If the success condition holds,
        the rollout advances to 50%, then 75%, then 100%. If the analysis fails,
        Argo Rollouts aborts and rolls back to the previous revision. This is the
        canary pattern teams run in production, reproduced on a laptop.
      </p>

      <ol>
        <li>Scale the canary to 25% of traffic and pause.</li>
        <li>Run the Prometheus analysis query three times over 90 seconds.</li>
        <li>If the gate passes, advance to 50%, then 75%, then 100%.</li>
        <li>If the gate fails, abort and revert to the previous revision.</li>
      </ol>

      <h2>The analysis query</h2>
      <p>
        The current analysis query is a conservative liveness check: is the
        canary up and being scraped. Once the buyerchat image exports request
        counters on <code>/api/metrics</code>, swap it for a real success-rate
        ratio. The template carries a <code>TODO</code> marking the one line to
        change.
      </p>

      <h2>Why GitOps for this</h2>
      <p>
        Because the image tag lives in git and ArgoCD reconciles against it, the
        rollout has a single source of truth. There is no out-of-band{' '}
        <code>kubectl set image</code>. A reviewer can read the diff that
        triggered a deploy, and a revert is a git revert. The canary gate then
        decides whether that change reaches all traffic, with Prometheus as the
        judge.
      </p>
    </>
  );
}
