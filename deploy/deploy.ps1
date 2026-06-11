# =============================================================================
# LemonFly Windows 部署脚本
# =============================================================================
# 使用方式: 在 PowerShell 中执行
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\deploy.ps1
# =============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$PatchDir = Join-Path $RootDir "patch"
$PublicDir = Join-Path $RootDir "data\public"

Write-Host ""
Write-Host "================================" -ForegroundColor Yellow
Write-Host " LemonFly Deployment Script" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Yellow
Write-Host ""

# --- Step 1: Copy brand assets ---
Write-Host "[1/3] Copying brand assets ..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $PublicDir | Out-Null

$files = @{
    "lemonfly_logo_80x80.png" = "logo.png"
    "Lfly.png"                = "Lfly.png"
    "lemonfly-home.css"       = "lemonfly-home.css"
    "lemonfly-home.js"        = "lemonfly-home.js"
    "index.html"              = "index.html"
    "lemonfly_logo_80x80.png" = "favicon.png"
}

foreach ($src in $files.Keys) {
    $srcPath = Join-Path $PatchDir $src
    $dstPath = Join-Path $PublicDir $files[$src]
    if (Test-Path $srcPath) {
        Copy-Item $srcPath $dstPath -Force
        Write-Host "   OK $src -> $($files[$src])" -ForegroundColor Gray
    } else {
        Write-Host "   SKIP $src (not found)" -ForegroundColor DarkYellow
    }
}

# Copy docs directory
$docsSrc = Join-Path $PatchDir "docs"
$docsDst = Join-Path $PublicDir "docs"
if (Test-Path $docsSrc) {
    Copy-Item $docsSrc $docsDst -Recurse -Force
    Write-Host "   OK docs/" -ForegroundColor Gray
}

Write-Host "   Done!" -ForegroundColor Green
Write-Host ""

# --- Step 2: Build Docker image ---
Write-Host "[2/3] Building Docker image (may take 5-10 min) ..." -ForegroundColor Cyan
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

Write-Host ""
Write-Host "   Image built: sub2api:latest" -ForegroundColor Green
Write-Host ""

# --- Step 3: Start services ---
Write-Host "[3/3] Starting services ..." -ForegroundColor Cyan

$DeployDir = Join-Path $RootDir "deploy"

# Ensure data directories exist
New-Item -ItemType Directory -Force -Path (Join-Path $RootDir "data") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $DeployDir "postgres_data") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $DeployDir "redis_data") | Out-Null

docker compose -f (Join-Path $DeployDir "docker-compose.yml") up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "   Start failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host " Deployment Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Homepage:   http://localhost:8080/" -ForegroundColor White
Write-Host "  Login:      http://localhost:8080/login" -ForegroundColor White
Write-Host "  Dashboard:  http://localhost:8080/dashboard" -ForegroundColor White
Write-Host "  Docs:       (configure in nginx)" -ForegroundColor White
Write-Host ""
Write-Host "  Admin:      admin@lemonfly.local / <your-password>" -ForegroundColor White
Write-Host ""
