// Static unit tests for the demo workload's /metrics endpoint and request
// counter. Uses Node's built-in test runner + a real in-process listen on
// an ephemeral port, so no external infra is needed.

const { test, before, after } = require("node:test");
const assert = require("node:assert");
const { app, register } = require("../server");

let server;
let base;

before(async () => {
  register.resetMetrics();
  await new Promise((resolve) => {
    server = app.listen(0, () => {
      base = `http://127.0.0.1:${server.address().port}`;
      resolve();
    });
  });
});

after(() => {
  server.close();
});

test("/metrics exposes http_requests_total in Prometheus format", async () => {
  // Drive one request so the counter has a sample.
  await fetch(`${base}/`);

  const res = await fetch(`${base}/metrics`);
  assert.strictEqual(res.status, 200);
  assert.match(
    res.headers.get("content-type"),
    /text\/plain/,
    "metrics must be served as Prometheus text exposition"
  );

  const body = await res.text();
  assert.match(body, /# TYPE http_requests_total counter/);
  // The counter must carry the labels the AnalysisTemplate PromQL selects on.
  assert.match(body, /http_requests_total\{[^}]*service="demo"/);
  assert.match(body, /http_requests_total\{[^}]*code="200"/);
});

test("counter increments with the response status code", async () => {
  register.resetMetrics();
  await fetch(`${base}/healthz`); // 200
  await fetch(`${base}/does-not-exist`); // 404

  const body = await (await fetch(`${base}/metrics`)).text();
  assert.match(body, /http_requests_total\{[^}]*code="200"[^}]*\} 1/);
  assert.match(body, /http_requests_total\{[^}]*code="404"[^}]*\} 1/);
});
