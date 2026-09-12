#!/system/bin/sh
AGH_DIR="/data/adb/agh"
BIN_DIR="$AGH_DIR/bin"
YAML_FILE="$BIN_DIR/AdGuardHome.yaml"

echo "等待 1 秒..."
echo "刷新页面以查看更改。"
sleep 1

# 获取管理端口（DNS-only 默认固定为 31423）
PORT=$(sed -n 's/^[[:space:]]*address: 127\.0\.0\.1:\([0-9]*\).*/\1/p' "$YAML_FILE")

# 自动跳转到浏览器并打开 Web UI
echo "正在打开浏览器 (端口 $PORT)..."
am start -a android.intent.action.VIEW -d "http://127.0.0.1:$PORT"