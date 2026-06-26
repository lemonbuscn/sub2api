#!/bin/bash
# =============================================================================
# LemonFly 上游同步脚本
# =============================================================================
# Usage:
#   bash scripts/sync-upstream.sh                    # 同步代码 + 恢复品牌补丁
#   bash scripts/sync-upstream.sh --build            # 同步 + 构建镜像
#   bash scripts/sync-upstream.sh --deploy           # 同步 + 构建 + 重启（服务器）
#   bash scripts/sync-upstream.sh --deploy --local   # 同步 + 构建 + 重启（本地）
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DEPLOY_DIR="$ROOT_DIR/deploy"

DO_BUILD=false
DO_DEPLOY=false
LOCAL_MODE=false

for arg in "$@"; do
    case $arg in
        --build)  DO_BUILD=true ;;
        --deploy) DO_BUILD=true; DO_DEPLOY=true ;;
        --local)  LOCAL_MODE=true ;;
        --help|-h)
            echo "Usage: bash scripts/sync-upstream.sh [--build] [--deploy] [--local]"
            echo ""
            echo "  (无参数)       同步代码 + 恢复品牌补丁"
            echo "  --build        同步 + 构建 Docker 镜像"
            echo "  --deploy       同步 + 构建 + 重启（服务器模式）"
            echo "  --deploy --local  同步 + 构建 + 重启（本地模式，含 nginx）"
            exit 0
            ;;
    esac
done

if [ "$LOCAL_MODE" = true ]; then
    COMPOSE_FILE="$DEPLOY_DIR/docker-compose.lemonfly.yml"
else
    COMPOSE_FILE="$DEPLOY_DIR/docker-compose.yml"
fi

echo "🍋 LemonFly 上游同步脚本"
echo "================================"

# --- Step 1: 暂存品牌补丁 ---
echo ""
echo "📦 Step 1: 暂存品牌补丁 ..."

BRAND_FILES=(
    "Dockerfile"
    "backend/internal/web/embed_on.go"
    "frontend/pnpm-workspace.yaml"
    "frontend/tailwind.config.js"
    "frontend/src/components/layout/AuthLayout.vue"
    "frontend/src/views/HomeView.vue"
)

HAS_CHANGES=false
for f in "${BRAND_FILES[@]}"; do
    if ! git diff --quiet HEAD -- "$f" 2>/dev/null; then
        HAS_CHANGES=true
        break
    fi
done

if [ "$HAS_CHANGES" = true ]; then
    git stash push -m "lemonfly-brand-$(date +%Y%m%d%H%M%S)" -- "${BRAND_FILES[@]}"
    echo "   ✅ 品牌补丁已暂存"
else
    echo "   ℹ️  无需暂存"
fi

# --- Step 2: 拉取并合并上游 ---
echo ""
echo "🔄 Step 2: 拉取上游最新代码 ..."

git fetch upstream --tags

CURRENT_VER=$(cat backend/cmd/server/VERSION 2>/dev/null || echo "0.0.0")
LATEST_TAG=$(git tag -l 'v*' --sort=-v:refname | head -1)
LATEST_VER=${LATEST_TAG#v}

echo "   当前版本: v${CURRENT_VER}"
echo "   最新版本: v${LATEST_VER}"

if [ "$CURRENT_VER" = "$LATEST_VER" ]; then
    echo "   ℹ️  已是最新版本，无需更新"
    if [ "$HAS_CHANGES" = true ]; then
        git stash pop 2>/dev/null || true
    fi
    echo ""
    echo "================================"
    echo "✅ 已是最新版本 v${CURRENT_VER}"
    exit 0
fi

echo "   正在合并 v${LATEST_VER} ..."

if git merge upstream/main --no-edit 2>&1; then
    echo "   ✅ 合并成功"
else
    echo "   ⚠️  合并有冲突，请手动解决后执行："
    echo "      git stash pop && bash scripts/apply-brand.sh"
    exit 1
fi

# --- Step 3: 恢复品牌补丁 ---
echo ""
echo "🎨 Step 3: 恢复品牌补丁 ..."

if [ "$HAS_CHANGES" = true ]; then
    if git stash pop 2>&1; then
        echo "   ✅ 品牌补丁已恢复（无冲突）"
    else
        echo "   ⚠️  stash pop 有冲突，用 apply-brand.sh 重新应用 ..."
        bash "$SCRIPT_DIR/apply-brand.sh"
    fi
else
    bash "$SCRIPT_DIR/apply-brand.sh"
fi

# --- Step 4: 构建镜像 ---
if [ "$DO_BUILD" = true ]; then
    echo ""
    echo "🔨 Step 4: 构建 Docker 镜像 ..."
    bash "$ROOT_DIR/deploy/build_image.sh"
    echo "   ✅ 镜像构建完成: sub2api:latest"
else
    echo ""
    echo "⏭️  Step 4: 跳过构建（加 --build 可自动构建）"
fi

# --- Step 5: 部署 ---
if [ "$DO_DEPLOY" = true ]; then
    echo ""
    echo "🚀 Step 5: 重启服务 ..."

    # 服务器模式需要切换镜像
    if [ "$LOCAL_MODE" = false ]; then
        if grep -q "image: weishaw/sub2api:latest" "$COMPOSE_FILE"; then
            cp "$COMPOSE_FILE" "$COMPOSE_FILE.bak"
            sed -i.tmp 's|image: weishaw/sub2api:latest|image: sub2api:latest|' "$COMPOSE_FILE"
            rm -f "$COMPOSE_FILE.tmp"
        fi
    fi

    docker compose -f "$COMPOSE_FILE" up -d
    echo "   ✅ 服务已重启"
else
    echo ""
    echo "⏭️  Step 5: 跳过部署（加 --deploy 可自动部署）"
fi

# --- 完成 ---
echo ""
echo "================================"
echo "✅ 同步完成！"
echo "   版本: v${CURRENT_VER} → v${LATEST_VER}"
echo "   品牌补丁: 已恢复"
