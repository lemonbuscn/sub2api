#!/bin/bash
# =============================================================================
# LemonFly 一键部署脚本
# =============================================================================
# Usage:
#   bash scripts/deploy-brand.sh              # 服务器模式（外部 nginx）
#   bash scripts/deploy-brand.sh --local      # 本地模式（自带 nginx）
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DEPLOY_DIR="$ROOT_DIR/deploy"
PATCH_DIR="$ROOT_DIR/patch"

# 解析参数
LOCAL_MODE=false
for arg in "$@"; do
    case $arg in
        --local) LOCAL_MODE=true ;;
        --help|-h)
            echo "Usage: bash scripts/deploy-brand.sh [--local]"
            echo ""
            echo "  (无参数)    服务器模式：构建镜像 + 注入品牌资源，用外部 nginx"
            echo "  --local     本地模式：构建镜像 + 启动完整服务（含 nginx）"
            exit 0
            ;;
    esac
done

if [ "$LOCAL_MODE" = true ]; then
    COMPOSE_FILE="$DEPLOY_DIR/docker-compose.lemonfly.yml"
    echo "🍋 LemonFly 部署（本地模式，含 nginx）"
else
    COMPOSE_FILE="$DEPLOY_DIR/docker-compose.yml"
    echo "🍋 LemonFly 部署（服务器模式，外部 nginx）"
fi
echo "================================"

# --- Step 1: 应用品牌补丁 ---
echo ""
bash "$SCRIPT_DIR/apply-brand.sh"

# --- Step 2: 构建镜像 ---
echo ""
echo "🔨 构建 Docker 镜像 ..."
echo "   (首次约需 5-10 分钟)"
bash "$ROOT_DIR/deploy/build_image.sh"
echo "   ✅ 镜像构建完成: sub2api:latest"

# --- Step 3: 服务器模式需要切换镜像 ---
if [ "$LOCAL_MODE" = false ]; then
    echo ""
    echo "🔄 切换 docker-compose 镜像 ..."
    if grep -q "image: weishaw/sub2api:latest" "$COMPOSE_FILE"; then
        cp "$COMPOSE_FILE" "$COMPOSE_FILE.bak"
        sed -i.tmp 's|image: weishaw/sub2api:latest|image: sub2api:latest|' "$COMPOSE_FILE"
        rm -f "$COMPOSE_FILE.tmp"
        echo "   ✅ 镜像已切换为 sub2api:latest"
        echo "   💾 备份: docker-compose.yml.bak"
    else
        echo "   ℹ️  镜像已是 sub2api:latest"
    fi
fi

# --- Step 4: 启动服务 ---
echo ""
echo "🚀 启动服务 ..."

if [ "$LOCAL_MODE" = true ]; then
    mkdir -p "$ROOT_DIR/data" "$DEPLOY_DIR/postgres_data" "$DEPLOY_DIR/redis_data"
    docker compose -f "$COMPOSE_FILE" up -d
else
    docker compose -f "$COMPOSE_FILE" up -d
fi

echo ""
echo "================================"
echo "✅ LemonFly 部署完成！"
echo ""

if [ "$LOCAL_MODE" = true ]; then
    PORT="${LEMONFLY_PORT:-80}"
    echo "  🏠 首页:    http://localhost:${PORT}"
    echo "  📚 文档:    http://localhost:${PORT}/docs"
    echo "  🔑 登录:    http://localhost:${PORT}/login"
    echo "  📊 控制台:  http://localhost:${PORT}/dashboard"
else
    echo "  🏠 首页:    https://你的域名/"
    echo "  📚 文档:    https://你的域名/docs  （需在 nginx 加配置）"
    echo "  🔑 登录:    https://你的域名/login"
    echo "  📊 控制台:  https://你的域名/dashboard"
fi
echo ""
