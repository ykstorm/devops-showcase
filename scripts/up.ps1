#requires -Version 5.1
<#
.SYNOPSIS
  Day-2 lifecycle: bring up a single-node kind cluster with Calico CNI,
  pre-load the buyerchat image, and apply the buyerchat namespace +
  Deployment + Service + NetworkPolicies in dependency order.

.DESCRIPTION
  Idempotent. Re-running on an existing `devops-showcase` cluster is
  a no-op for cluster creation; manifest re-apply is harmless.

  Prereqs (verified by the precheck step):
    - Docker Desktop running
    - kind v0.23+
    - kubectl v1.28+
    - Internet egress for the tigera-operator manifest pull and the
      buyerchat image pull

.NOTES
  Pinned versions:
    Calico:           v3.28.2
    Buyerchat image:  ghcr.io/ykstorm/buyerchat:sha-8560cb3
    Cluster name:     devops-showcase
#>

# PS5.1 turns native-command stderr into ErrorRecord objects in the error
# stream; `$ErrorActionPreference = 'Stop'` would then terminate the script
# on benign progress messages from kind / kubectl / docker. We instead use
# 'Continue' at script scope and rely on explicit $LASTEXITCODE checks
# after every native call. PSNativeCommandUseErrorActionPreference (PS7+)
# would handle this cleanly but is unavailable on Windows PowerShell 5.1.
$ErrorActionPreference = 'Continue'

function Invoke-NativeCapture {
  # PS5.1-safe native-command capture. Temporarily toggles ErrorActionPreference
  # to Continue so native stderr (which PS5.1 wraps in ErrorRecord objects)
  # doesn't terminate the script. Returns stdout lines as a string array;
  # the caller is responsible for inspecting $LASTEXITCODE.
  param([scriptblock]$ScriptBlock)
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $out = & $ScriptBlock 2>&1
    # Filter to stdout-shaped lines (drop ErrorRecord wrappers)
    return @($out | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" })
  } finally {
    $ErrorActionPreference = $prev
  }
}

$ClusterName       = 'devops-showcase'
$CalicoVersion     = 'v3.28.2'
$TigeraOperatorUrl = "https://raw.githubusercontent.com/projectcalico/calico/$CalicoVersion/manifests/tigera-operator.yaml"
$BuyerchatImage    = 'ghcr.io/ykstorm/buyerchat:sha-8560cb3'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ClusterConfig    = Join-Path $RepoRoot 'kind\cluster.yaml'
$CalicoInstallCR  = Join-Path $RepoRoot 'kind\calico\installation.yaml'
$ManifestsDir     = Join-Path $RepoRoot 'manifests\buyerchat'

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-OK {
  param([string]$Message)
  Write-Host "    [OK] $Message" -ForegroundColor Green
}

function Assert-OnPath {
  param([string]$Tool, [string]$InstallHint)
  $cmd = Get-Command $Tool -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Host "[FAIL] $Tool not found on PATH." -ForegroundColor Red
    Write-Host "       $InstallHint" -ForegroundColor Yellow
    exit 1
  }
  Write-OK "$Tool -> $($cmd.Source)"
}

# ---------------------------------------------------------------------
# Precheck
# ---------------------------------------------------------------------
Write-Step 'Precheck - required tools on PATH'
Assert-OnPath 'docker'  'Install Docker Desktop: https://www.docker.com/products/docker-desktop/'
Assert-OnPath 'kind'    'winget install Kubernetes.kind   (then re-open the shell to pick up PATH)'
Assert-OnPath 'kubectl' 'winget install Kubernetes.kubectl'

Write-Step 'Precheck - Docker daemon'
$dockerLines = Invoke-NativeCapture { docker info --format '{{.ServerVersion}}' }
$dockerInfo = ($dockerLines | Select-Object -First 1)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($dockerInfo)) {
  Write-Host "[FAIL] Docker daemon is not responding." -ForegroundColor Red
  Write-Host "       Open Docker Desktop, wait for the whale icon to settle, then re-run." -ForegroundColor Yellow
  exit 1
}
Write-OK "Docker engine v$dockerInfo"

# ---------------------------------------------------------------------
# Cluster bring-up (idempotent)
# ---------------------------------------------------------------------
Write-Step "Cluster - kind cluster '$ClusterName'"
$existing = Invoke-NativeCapture { kind get clusters }
$clusterExists = $false
foreach ($line in $existing) {
  if ($line.Trim() -eq $ClusterName) { $clusterExists = $true; break }
}
if ($clusterExists) {
  Write-OK "Cluster '$ClusterName' already exists - skipping create"
} else {
  & kind create cluster --config $ClusterConfig
  if ($LASTEXITCODE -ne 0) { throw "kind create cluster failed (exit $LASTEXITCODE)" }
  Write-OK "Cluster '$ClusterName' created"
}

& kubectl config use-context "kind-$ClusterName" | Out-Null
Write-OK "kubectl context = kind-$ClusterName"

# ---------------------------------------------------------------------
# Calico CNI
# ---------------------------------------------------------------------
Write-Step "Calico - tigera-operator $CalicoVersion"
# `kubectl create` on the operator manifest is intentional: server-side
# `apply` with a 200K manifest can hit the annotation-size limit; create
# is the upstream-recommended pattern. Re-running on an existing install
# returns AlreadyExists, which we swallow.
$opLines = Invoke-NativeCapture { kubectl create -f $TigeraOperatorUrl }
# kubectl create exits non-zero on AlreadyExists; that's OK on idempotent re-run.
foreach ($line in $opLines) {
  if ($line -match 'AlreadyExists') { Write-OK "operator resources already present" }
  elseif ($line -match '^(namespace|customresourcedefinition|serviceaccount|clusterrole|clusterrolebinding|role|rolebinding|configmap|deployment|service|podsecuritypolicy)') {
    Write-Host "    $line"
  } else { Write-Host "    $line" }
}

Write-Step 'Calico - wait for tigera-operator Deployment Available'
& kubectl wait --for=condition=Available deployment/tigera-operator -n tigera-operator --timeout=180s
if ($LASTEXITCODE -ne 0) { throw "tigera-operator did not become Available within 180s" }
Write-OK 'tigera-operator Available'

Write-Step 'Calico - apply Installation CR'
& kubectl apply -f $CalicoInstallCR
if ($LASTEXITCODE -ne 0) { throw "kubectl apply Calico Installation CR failed" }
Write-OK 'Installation CR applied'

Write-Step 'Calico - wait for nodes Ready (Calico data-plane up)'
# Nodes are NotReady until Calico's CNI binary lands on the node and
# pod networking comes up. Allow up to 5 minutes on first cluster
# bring-up (image pulls).
& kubectl wait --for=condition=Ready node --all --timeout=300s
if ($LASTEXITCODE -ne 0) { throw "nodes did not reach Ready within 300s" }
Write-OK 'all nodes Ready'

# ---------------------------------------------------------------------
# Image preload (avoids in-cluster pulls during pod start)
# ---------------------------------------------------------------------
Write-Step "Image - pull $BuyerchatImage"
& docker pull $BuyerchatImage
if ($LASTEXITCODE -ne 0) { throw "docker pull $BuyerchatImage failed" }
Write-OK "Image pulled to local Docker"

Write-Step "Image - kind load into cluster '$ClusterName'"
& kind load docker-image $BuyerchatImage --name $ClusterName
if ($LASTEXITCODE -ne 0) { throw "kind load docker-image failed" }
Write-OK "Image side-loaded; ImagePullPolicy=IfNotPresent will not hit the registry"

# ---------------------------------------------------------------------
# Apply buyerchat manifests
# ---------------------------------------------------------------------
Write-Step "Manifests - kubectl apply -f $ManifestsDir"
& kubectl apply -f $ManifestsDir
if ($LASTEXITCODE -ne 0) { throw "kubectl apply on buyerchat manifests failed" }
Write-OK 'buyerchat manifests applied'

# ---------------------------------------------------------------------
# Wait for Deployment Ready (degraded-mode tolerant)
# ---------------------------------------------------------------------
Write-Step 'Workload - wait for buyerchat Deployment Available'
# Degraded mode: /api/healthcheck returns 503, BUT the TCP socket
# probes (livenessProbe.tcpSocket / readinessProbe.tcpSocket) only
# care that port 3000 accepts connections. Once Next.js is listening,
# the pod flips Ready, Deployment becomes Available, and we exit
# successfully even though the HTTP healthcheck is 503.
$timeoutSec = 300
$deadline = (Get-Date).AddSeconds($timeoutSec)
$ready = $false
while ((Get-Date) -lt $deadline) {
  $null = Invoke-NativeCapture { kubectl rollout status deployment/buyerchat -n buyerchat --timeout=10s }
  if ($LASTEXITCODE -eq 0) { $ready = $true; break }
  Start-Sleep -Seconds 5
}
if (-not $ready) {
  Write-Host '[WARN] Deployment did not reach Available within 300s.' -ForegroundColor Yellow
  Write-Host '       Inspect: kubectl describe pod -n buyerchat -l app.kubernetes.io/name=buyerchat' -ForegroundColor Yellow
  Write-Host '       and:     kubectl logs   -n buyerchat -l app.kubernetes.io/name=buyerchat --tail=50' -ForegroundColor Yellow
  Write-Host '       Common Day-2 cause: image USER 0 vs runAsNonRoot=true (see task_plan Day-2 risk row).' -ForegroundColor Yellow
  exit 2
}
Write-OK 'buyerchat Deployment Available'

# ---------------------------------------------------------------------
# Smoke-test instructions
# ---------------------------------------------------------------------
Write-Step 'Smoke test'
Write-Host ''
Write-Host '  Run these in a separate terminal to verify:' -ForegroundColor White
Write-Host ''
Write-Host '    kubectl port-forward -n buyerchat svc/buyerchat 3000:3000' -ForegroundColor White
Write-Host '    # then in a third terminal:'
Write-Host '    curl.exe -i http://localhost:3000/api/healthcheck' -ForegroundColor White
Write-Host ''
Write-Host '  Acceptance: ANY HTTP response (200 or 503) - degraded mode' -ForegroundColor White
Write-Host '              returns 503 because DATABASE_URL is stubbed.' -ForegroundColor White
Write-Host ''
Write-Host '  Verify the Day-2 acceptance criteria:' -ForegroundColor White
Write-Host ''
Write-Host '    kind get clusters'
Write-Host '    kubectl get pods -A'
Write-Host '    kubectl get ns buyerchat -o jsonpath=''{.metadata.labels}'''
Write-Host '    kubectl get pods -n buyerchat'
Write-Host '    kubectl get networkpolicies -n buyerchat'
Write-Host ''
Write-Host '  Tear down:' -ForegroundColor White
Write-Host ''
Write-Host '    .\scripts\down.ps1'
Write-Host ''
