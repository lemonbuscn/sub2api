#!/bin/bash
# =============================================================================
# LemonFly Brand Apply Script
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PATCH_DIR="$ROOT_DIR/patch"
PUBLIC_DIR="$ROOT_DIR/data/public"
EMBED_FILE="$ROOT_DIR/backend/internal/web/embed_on.go"

echo "🍋 LemonFly Brand Apply Script"
echo "================================"

# --- Step 1: Copy brand assets ---
echo ""
echo "📦 Step 1: Copying brand assets to data/public/ ..."
mkdir -p "$PUBLIC_DIR"

cp "$PATCH_DIR/lemonfly_logo_80x80.png" "$PUBLIC_DIR/logo.png"
cp "$PATCH_DIR/Lfly.png"                "$PUBLIC_DIR/Lfly.png"
cp "$PATCH_DIR/lemonfly-home.css"       "$PUBLIC_DIR/lemonfly-home.css"
cp "$PATCH_DIR/lemonfly-home.js"        "$PUBLIC_DIR/lemonfly-home.js"
cp "$PATCH_DIR/index.html"              "$PUBLIC_DIR/index.html"
cp "$PATCH_DIR/lemonfly_logo_80x80.png" "$PUBLIC_DIR/favicon.png"

echo "   ✅ logo.png, Lfly.png, lemonfly-home.css/js, index.html, favicon.png"

# --- Step 2: Patch embed_on.go ---
echo ""
echo "🔧 Step 2: Patching embed_on.go ..."

if [ ! -f "$EMBED_FILE" ]; then
    echo "   ⚠️  embed_on.go not found, skipping."
else
    if grep -q "Check for custom landing page override" "$EMBED_FILE"; then
        echo "   ℹ️  embed_on.go already patched, skipping."
    else
        cp "$EMBED_FILE" "$EMBED_FILE.brand-backup"
        awk '
        /^func \(s \*FrontendServer\) serveIndexHTML\(c \*gin\.Context\) \{/ {
            print
            print "\t// Check for custom landing page override in data/public/"
            print "\tif s.overrideDir != \"\" {"
            print "\t\toverrideIndex := filepath.Join(s.overrideDir, \"index.html\")"
            print "\t\tif _, err := os.Stat(overrideIndex); err == nil {"
            print "\t\t\tc.File(overrideIndex)"
            print "\t\t\tc.Abort()"
            print "\t\t\treturn"
            print "\t\t}"
            print "\t}"
            print ""
            next
        }
        { print }
        ' "$EMBED_FILE.brand-backup" > "$EMBED_FILE"
        echo "   ✅ embed_on.go patched"
        echo "   💾 Backup: embed_on.go.brand-backup"
    fi
fi

# --- Step 3: Apply frontend theme ---
echo ""
echo "🎨 Step 3: Applying LemonFly lemon-yellow theme to frontend ..."

FRONTEND_DIR="$ROOT_DIR/frontend"

# tailwind.config.js
TAILWIND="$FRONTEND_DIR/tailwind.config.js"
if [ -f "$TAILWIND" ]; then
    if grep -q "LemonFly" "$TAILWIND"; then
        echo "   ℹ️  tailwind.config.js already themed, skipping."
    else
        sed -i.bak '/\/\/ 主色调/,/950: '\''#042f2e'\''/{
            s|// 主色调.*|// 主色调 - LemonFly 柠檬黄色系|
            s|50: '\''#f0fdfa'\''|50: '\''#fffef5'\''|
            s|100: '\''#ccfbf1'\''|100: '\''#fffbeb'\''|
            s|200: '\''#99f6e4'\''|200: '\''#fef3c7'\''|
            s|300: '\''#5eead4'\''|300: '\''#fde68a'\''|
            s|400: '\''#2dd4bf'\''|400: '\''#fcd34d'\''|
            s|500: '\''#14b8a6'\''|500: '\''#fbbf24'\''|
            s|600: '\''#0d9488'\''|600: '\''#f59e0b'\''|
            s|700: '\''#0f766e'\''|700: '\''#d97706'\''|
            s|800: '\''#115e59'\''|800: '\''#b45309'\''|
            s|900: '\''#134e4a'\''|900: '\''#92400e'\''|
            s|950: '\''#042f2e'\''|950: '\''#78350f'\''|
        }' "$TAILWIND"
        # Update glow colors: orange → lemon yellow
        sed -i.bak "s|rgba(255, 107, 18,|rgba(251, 191, 36,|g" "$TAILWIND"
        # Update gradient-primary
        sed -i.bak "s|linear-gradient(135deg, #14b8a6 0%, #0d9488 100%)|linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%)|" "$TAILWIND"
        # Update mesh-gradient
        sed -i.bak "s|rgba(20, 184, 166, 0.12)|rgba(251, 191, 36, 0.12)|" "$TAILWIND"
        sed -i.bak "s|rgba(6, 182, 212, 0.08)|rgba(245, 158, 11, 0.08)|" "$TAILWIND"
        sed -i.bak "s|rgba(20, 184, 166, 0.08)|rgba(253, 224, 71, 0.08)|" "$TAILWIND"
        rm -f "$TAILWIND.bak"
        echo "   ✅ tailwind.config.js themed"
    fi
fi

# AuthLayout.vue & HomeView.vue - grid pattern color
for VUE_FILE in "$FRONTEND_DIR/src/components/layout/AuthLayout.vue" "$FRONTEND_DIR/src/views/HomeView.vue"; do
    if [ -f "$VUE_FILE" ]; then
        if grep -q "rgba(251,191,36" "$VUE_FILE"; then
            echo "   ℹ️  $(basename "$VUE_FILE") already themed, skipping."
        else
            sed -i.bak 's/rgba(20,184,166/rgba(251,191,36/g; s/rgba(255,107,18/rgba(251,191,36/g' "$VUE_FILE"
            rm -f "$VUE_FILE.bak"
            echo "   ✅ $(basename "$VUE_FILE") themed"
        fi
    fi
done

echo ""
echo "================================"
echo "✅ Brand apply complete!"
echo ""
echo "Next steps:"
echo "  - Build:    cd backend && go build -tags embed -o ../sub2api ./cmd/server"
echo "  - Or Docker: docker compose build"
echo ""
