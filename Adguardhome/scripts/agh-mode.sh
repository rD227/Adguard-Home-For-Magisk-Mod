#!/system/bin/sh
# 运行模式标记：在 AdGuard Home Web UI 的 “DNS 设置 -> 不允许的域名” 中维护。
# 默认配置已加入 “dns-only” 标记 => DNS-only 模式（不启动 iptables.sh 等）。
# 如需恢复完整模式（启用 iptables.sh / NoAdsService.sh / ModuleMOD.sh），
# 请在该页面移除 “dns-only” 这一行，然后重启设备。

agh_mode_yaml() {
  if [ -n "$AGH_YAML" ]; then
    echo "$AGH_YAML"
  elif [ -n "$BIN_DIR" ]; then
    echo "$BIN_DIR/AdGuardHome.yaml"
  else
    echo "/data/adb/agh/bin/AdGuardHome.yaml"
  fi
}

is_dns_only() {
  yaml="$(agh_mode_yaml)"
  [ -f "$yaml" ] || return 0
  sed -n '/^dns:/,/^[^[:space:]]/p' "$yaml" | grep -qE '^[[:space:]]*-[[:space:]]*"?dns-only"?[[:space:]]*$'
}
