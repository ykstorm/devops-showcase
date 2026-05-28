#requires -Version 5.1
<#
.SYNOPSIS
  Tear down the kind `stackup` cluster.

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

# See up.ps1 header comment re: EAP and PS5.1 native-command semantics.
$ErrorActionPreference = 'Continue'

$ClusterName = 'stackup'

Write-Host ""
Write-Host "==> Tear down kind cluster '$ClusterName'" -ForegroundColor Cyan

$prevEAP = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$existing = @(& kind get clusters 2>&1 | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_".Trim() })
$ErrorActionPreference = $prevEAP
$clusterExists = $false
foreach ($line in $existing) {
  if ($line -eq $ClusterName) { $clusterExists = $true; break }
}
if (-not $clusterExists) {
  Write-Host "    [OK] cluster '$ClusterName' is not present - nothing to do" -ForegroundColor Green
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
