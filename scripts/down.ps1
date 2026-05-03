#requires -Version 5.1
<#
.SYNOPSIS
  Tear down the kind `devops-showcase` cluster.

.PARAMETER Force
  Skip the confirmation prompt. CI / scripted use.

.NOTES
  Destructive. Removes the cluster, its Docker volumes, and the
  cluster-network. Other Docker containers / images on the host are
  untouched. The buyerchat image stays in the host Docker cache (can
  be re-loaded into a new cluster without a registry roundtrip).
#>

[CmdletBinding()]
param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$ClusterName = 'devops-showcase'

Write-Host ""
Write-Host "==> Tear down kind cluster '$ClusterName'" -ForegroundColor Cyan

$existing = (& kind get clusters 2>$null)
if (-not ($existing -contains $ClusterName)) {
  Write-Host "    [OK] cluster '$ClusterName' is not present — nothing to do" -ForegroundColor Green
  exit 0
}

if (-not $Force) {
  Write-Host ""
  Write-Host "  This will DELETE the kind cluster '$ClusterName' and all its workloads." -ForegroundColor Yellow
  Write-Host "  Buyerchat image stays in the local Docker cache." -ForegroundColor Yellow
  $resp = Read-Host "  Type 'yes' to proceed"
  if ($resp -ne 'yes') {
    Write-Host "    aborted" -ForegroundColor Yellow
    exit 1
  }
}

& kind delete cluster --name $ClusterName
if ($LASTEXITCODE -ne 0) {
  Write-Host "[FAIL] kind delete cluster failed (exit $LASTEXITCODE)" -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "    [OK] cluster '$ClusterName' deleted" -ForegroundColor Green
