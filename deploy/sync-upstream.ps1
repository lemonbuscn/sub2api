# =============================================================================
# LemonFly Windows 上游同步脚本
# =============================================================================
# 使用方式:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\sync-upstream.ps1
# =============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$PatchDir = Join-Path $RootDir "patch"
$PublicDir = Join-Path $RootDir "data\public"

Write-Host ""
Write-Host "================================" -ForegroundColor Yellow
Write-Host " LemonFly Upstream Sync" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Yellow
Write-Host ""

# --- Step 1: Stash brand changes ---
Write-Host "[1/5] Stashing brand changes ..." -ForegroundColor Cyan

$brandFiles = @(
    "backend/internal/web/embed_on.go"
    "frontend/tailwind.config.js"
    "frontend/src/components/layout/AuthLayout.vue"
    "frontend/src/views/HomeView.vue"
)

$hasChanges = $false
foreach ($f in $brandFiles) {
    $result = git diff --quiet HEAD -- $f 2>&1
    if ($LASTEXITCODE -ne 0) { $hasChanges = $true; break }
}

if ($hasChanges) {
    git stash push -m "lemonfly-brand-$(Get-Date -Format 'yyyyMMddHHmmss')" -- $brandFiles
    Write-Host "   Stashed" -ForegroundColor Green
} else {
    Write-Host "   No changes to stash" -ForegroundColor Gray
}
Write-Host ""

# --- Step 2: Fetch and merge upstream ---
Write-Host "[2/5] Fetching upstream ..." -ForegroundColor Cyan
git fetch upstream --tags

$currentVer = Get-Content (Join-Path $RootDir "backend\cmd\server\VERSION") -ErrorAction SilentlyContinue
if (-not $currentVer) { $currentVer = "0.0.0" }

$latestTag = git tag -l 'v*' --sort=-v:refname | Select-Object -First 1
$latestVer = $latestTag -replace '^v', ''

Write-Host "   Current: v$currentVer" -ForegroundColor Gray
Write-Host "   Latest:  v$latestVer" -ForegroundColor Gray

if ($currentVer -eq $latestVer) {
    Write-Host "   Already up to date!" -ForegroundColor Green
    if ($hasChanges) { git stash pop 2>&1 }
    Write-Host ""
    Write-Host "================================" -ForegroundColor Green
    Write-Host " Done! v$currentVer" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green
    exit 0
}

Write-Host "   Merging v$latestVer ..." -ForegroundColor Cyan
git merge upstream/main --no-edit

if ($LASTEXITCODE -ne 0) {
    Write-Host "   Merge conflict! Resolve manually:" -ForegroundColor Red
    Write-Host "     git stash pop" -ForegroundColor Red
    Write-Host "     Then re-run this script." -ForegroundColor Red
    exit 1
}

Write-Host "   Merged!" -ForegroundColor Green
Write-Host ""

# --- Step 3: Restore brand changes ---
Write-Host "[3/5] Restoring brand changes ..." -ForegroundColor Cyan

if ($hasChanges) {
    git stash pop 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Restored (no conflicts)" -ForegroundColor Green
    } else {
        Write-Host "   Conflict detected, changes will be applied during build" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "   No stash to restore" -ForegroundColor Gray
}
Write-Host ""

# --- Step 4: Copy brand assets ---
Write-Host "[4/5] Copying brand assets ..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $PublicDir | Out-Null

Copy-Item (Join-Path $PatchDir "lemonfly_logo_80x80.png") (Join-Path $PublicDir "logo.png") -Force
Copy-Item (Join-Path $PatchDir "Lfly.png") (Join-Path $PublicDir "Lfly.png") -Force
Copy-Item (Join-Path $PatchDir "lemonfly-home.css") (Join-Path $PublicDir "lemonfly-home.css") -Force
Copy-Item (Join-Path $PatchDir "lemonfly-home.js") (Join-Path $PublicDir "lemonfly-home.js") -Force
Copy-Item (Join-Path $PatchDir "index.html") (Join-Path $PublicDir "index.html") -Force
Copy-Item (Join-Path $PatchDir "lemonfly_logo_80x80.png") (Join-Path $PublicDir "favicon.png") -Force

if (Test-Path (Join-Path $PatchDir "docs")) {
    Copy-Item (Join-Path $PatchDir "docs") (Join-Path $PublicDir "docs") -Recurse -Force
}

Write-Host "   Done!" -ForegroundColor Green
Write-Host ""

# --- Step 5: Build and restart ---
Write-Host "[5/5] Building and restarting ..." -ForegroundColor Cyan
Write-Host ""

docker build -t sub2api:latest `
    --build-arg GOPROXY=https://goproxy.cn,direct `
    --build-arg GOSUMDB=sum.golang.google.cn `
    --build-arg NPM_REGISTRY=https://registry.npmmirror.com `
    -f (Join-Path $RootDir "Dockerfile") `
    $RootDir

if ($LASTEXITCODE -ne 0) {
    Write-Host "   Build failed!" -ForegroundColor Red
    exit 1
}

docker compose -f (Join-Path $ScriptDir "docker-compose.yml") up -d

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host " Sync Complete! v$currentVer -> v$latestVer" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
