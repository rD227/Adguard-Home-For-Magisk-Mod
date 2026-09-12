#!/system/bin/sh
SCRIPT_DIR="/data/adb/agh/scripts"
ADGPATH="/data/adb/modules/AdGuardHome"
AGH_DIR="/data/adb/agh"
BIN_DIR="$AGH_DIR/bin"
AGH_YAML="$BIN_DIR/AdGuardHome.yaml"
MAIN_LOG="$AGH_DIR/agh.log"
MODULES_DIR="/data/adb/modules"
AGH_MODULE_PROP="/data/adb/modules/AdGuardHome/module.prop"

. "$SCRIPT_DIR/agh-mode.sh"

# 解锁脚本防篡改保护
find "$ADGPATH" -type f -name "*.sh" -exec chattr -i {} \;

# 系统语言检测
locale=$(getprop persist.sys.locale)
[ -z "$locale" ] && locale="zh"
case $locale in zh*) lang=zh ;; *) lang=en ;; esac

# 检查hosts模块并中止启动
found_hosts=false
for module in "$MODULES_DIR"/*; do 
  [ -d "$module" ] && [ -f "$module/system/etc/hosts" ] && {
    found_hosts=true
    touch "$module/remove"
  }
done
if [ "$found_hosts" = true ]; then
    if [ "$lang" = "zh" ]; then
        MSG="检测到hosts模块，AdGuardHome启动已中止"
        DESC="⚠️ AdGuardHome已禁用 - 检测到hosts模块（已标记移除，请重启设备）"
    else
        MSG="Hosts module detected, AdGuardHome startup aborted"
        DESC="⚠️ AdGuardHome disabled - Hosts module detected (marked for removal, Please restart the device)"
    fi
    [ -f "$AGH_MODULE_PROP" ] && sed -i "s/description=.*/description=$DESC/" "$AGH_MODULE_PROP"
    echo "$(date '+%F %T') [ERROR] $MSG" >> "$MAIN_LOG"
    exit 1
fi

# DNS 端口随机化（管理端口固定为 http://127.0.0.1:31423）
if ! pgrep "AdGuardHome"; then
R1=$((30000+RANDOM%35536))
sed -i "/^dns:/,/^[^[:space:]]/ s/^\([[:space:]]*port:\) [0-9]*/\1 $R1/" "$AGH_YAML"
sed -i "s/^redir_port=.*/redir_port=$R1/" "$SCRIPT_DIR/config.prop"

# 启动AdGuardHome
export SSL_CERT_DIR="/system/etc/security/cacerts/"
"$BIN_DIR/AdGuardHome" --no-check-update &

# 验证AdGuardHome是否启动成功
    sleep 1
    if pgrep "AdGuardHome"; then
        [ "$lang" = "zh" ] && echo "$(date '+%F %T') AdGuardHome 启动成功。" >> "$MAIN_LOG" || echo "$(date '+%F %T') AdGuardHome started successfully." >> "$MAIN_LOG"
    else
        [ "$lang" = "zh" ] && echo "$(date '+%F %T') AdGuardHome启动失败，尝试重启..." >> "$MAIN_LOG" || echo "$(date '+%F %T') AdGuardHome failed to start, attempting restart..." >> "$MAIN_LOG"
        exec "$0"
    fi
fi

# 启动模块附加脚本
if is_dns_only; then
    # DNS-only 模式：仅保留 AdGuardHome 进程与 ProxyConfig.sh 本地 DNS 注入，
    # 不启动/不维护 iptables.sh，确保 YumeBox 等 TUN 类代理继续使用自身路由。
    for s in iptables.sh ModuleMOD.sh NoAdsService.sh; do
        for pid in $(pgrep -f "$SCRIPT_DIR/$s"); do
            [ "$pid" = "$$" ] || kill -9 "$pid" 2>/dev/null
        done
    done
    rm -f "$AGH_DIR/iptables.enabled"
    [ "$lang" = "zh" ] && echo "$(date '+%F %T') DNS-only 模式：已跳过 iptables.sh / NoAdsService.sh / ModuleMOD.sh。" >> "$MAIN_LOG" || echo "$(date '+%F %T') DNS-only mode: iptables.sh / NoAdsService.sh / ModuleMOD.sh skipped." >> "$MAIN_LOG"
    pgrep -f "$SCRIPT_DIR/ProxyConfig.sh" || "$SCRIPT_DIR/ProxyConfig.sh" &
else
    pgrep -f "$SCRIPT_DIR/iptables.sh" || "$SCRIPT_DIR/iptables.sh" &
    pgrep -f "$SCRIPT_DIR/ModuleMOD.sh" || "$SCRIPT_DIR/ModuleMOD.sh" &
    pgrep -f "$SCRIPT_DIR/NoAdsService.sh" || "$SCRIPT_DIR/NoAdsService.sh" &
    pgrep -f "$SCRIPT_DIR/ProxyConfig.sh" || "$SCRIPT_DIR/ProxyConfig.sh" &
fi

# 执行脚本防篡改保护
find "$ADGPATH" -type f -name "*.sh" -exec chattr +i {} \;

# 日志超限时清空
[ "$(wc -c < "$MAIN_LOG")" -ge 102400 ] && : > "$MAIN_LOG"