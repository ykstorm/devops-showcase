#requires -Version 5.1
<#
.SYNOPSIS
  Day-2 lifecycle: bring up a single-node kind cluster with Calico CNI,
  pre-load the buyerchat image, and apply the buyerchat namespace +
  Deployment + Service + NetworkPolicies in dependency order.

.DESCRIPTION
  Idempotent. Re-running on an existing `stackup` cluster is
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
    Cluster name:     stackup
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

$ClusterName       = 'stackup'
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
# Apply buyerchat namespace
# ---------------------------------------------------------------------
# Day-3 note: the raw Deployment / Service / Secret / NetworkPolicies
# under manifests/buyerchat/ are now owned by the Helm chart at
# helm/buyerchat/. Only 00-namespace.yaml remains here, because the
# chart doesn't manage the Namespace (PSS labels are an
# infrastructure-level concern, not a workload concern, and the chart
# may eventually be installed into multiple-tenant namespaces). The
# helm install steps for the buyerchat workload are operator-driven
# until Day 6 wires ArgoCD to take over.
Write-Step "Namespace - kubectl apply -f $ManifestsDir"
& kubectl apply -f $ManifestsDir
if ($LASTEXITCODE -ne 0) { throw "kubectl apply on buyerchat manifests failed" }
Write-OK 'buyerchat namespace applied (with restricted-PSS labels)'

# ---------------------------------------------------------------------
# Day-3 follow-up instructions (helm installs are operator-driven
# until Day 6 GitOps takeover)
# ---------------------------------------------------------------------
Write-Step 'Day-3 follow-ups (run after this script completes)'
Write-Host ''
Write-Host '  Foundation infra (~3 min total):' -ForegroundColor White
Write-Host ''
Write-Host '    # See infra/ingress-nginx/README.md, infra/cert-manager/README.md,'
Write-Host '    # infra/sealed-secrets/README.md for full one-line install commands.'
Write-Host '    helm repo add ingress-nginx  https://kubernetes.github.io/ingress-nginx'
Write-Host '    helm repo add jetstack       https://charts.jetstack.io'
Write-Host '    helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets'
Write-Host '    helm repo update'
Write-Host '    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \'
Write-Host '      -n ingress-nginx --create-namespace -f infra/ingress-nginx/values.yaml --wait'
Write-Host '    helm upgrade --install cert-manager jetstack/cert-manager \'
Write-Host '      -n cert-manager --create-namespace --set installCRDs=true --wait'
Write-Host '    kubectl apply -f infra/cert-manager/clusterissuer-selfsigned.yaml'
Write-Host '    helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \'
Write-Host '      -n kube-system --wait'
Write-Host ''
Write-Host '  Re-seal buyerchat-env (controller key is per-cluster — see' -ForegroundColor White
Write-Host '  infra/sealed-secrets/README.md):' -ForegroundColor White
Write-Host ''
Write-Host '    # Recipe in helm/buyerchat/templates/sealed-secret.yaml leading comment.'
Write-Host ''
Write-Host '  Workload:' -ForegroundColor White
Write-Host ''
Write-Host '    helm upgrade --install buyerchat ./helm/buyerchat \'
Write-Host '      -f helm/buyerchat/values.dev.yaml -n buyerchat --wait'
Write-Host ''
Write-Host '  Smoke test:' -ForegroundColor White
Write-Host ''
Write-Host '    curl -k -i https://buyerchat.localtest.me/api/healthcheck'
Write-Host '    # Expect: HTTP 503 with body {"status":"degraded","reason":"db_unreachable"}'
Write-Host ''
Write-Host '  Tear down:' -ForegroundColor White
Write-Host ''
Write-Host '    .\scripts\down.ps1'
Write-Host ''
