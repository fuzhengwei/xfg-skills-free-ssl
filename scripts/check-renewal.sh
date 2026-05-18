#!/usr/bin/env bash
# check-renewal.sh — 检查证书是否即将过期，并按需执行续期
#
# 用法:
#   bash scripts/check-renewal.sh [--verbose] [--dry-run]
#   bash scripts/check-renewal.sh --help
#
# 退出码:
#   0 - 无需续期或续期成功
#   1 - 检查或续期失败
#   2 - 参数错误

set -euo pipefail

VERBOSE=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=1; shift ;;
        --verbose) VERBOSE=1; shift ;;
        --help|-h)
            echo "用法: bash scripts/check-renewal.sh [--verbose] [--dry-run]"
            echo ""
            echo "检查 Let's Encrypt 证书是否即将过期，并按需执行续期（临近 30 天以内会触发）"
            echo ""
            echo "选项:"
            echo "  --dry-run        仅测试不实际续期"
            echo "  --verbose        输出详细信息"
            echo "  --help           显示帮助信息"
            echo ""
            echo "示例:"
            echo "  bash scripts/check-renewal.sh --verbose"
            echo "  bash scripts/check-renewal.sh --dry-run"
            echo ""
            echo "提示: 你可以将此脚本配置到 crontab 或 systemd timer 中定期运行，例如:"
            echo "  0 2 * * 0 bash /path/to/scripts/check-renewal.sh"
            exit 0
            ;;
        *)
            echo "Error: 未知参数: $1" >&2
            exit 2
            ;;
    esac
done

# 检查是否有 sudo 权限
if ! sudo true &>/dev/null; then
    echo "Error: 需要 sudo 权限执行此脚本，请以可使用 sudo 的用户运行" >&2
    exit 1
fi

# 检查 certbot 是否安装
if ! command -v certbot &>/dev/null; then
    echo "Error: 未检测到 certbot，请先运行 setup-free-ssl.sh 申请证书" >&2
    exit 1
fi

if [[ $VERBOSE -eq 1 ]]; then
    echo "[INFO] 检查证书状态..." >&2
fi

if [[ $DRY_RUN -eq 1 ]]; then
    sudo certbot renew --dry-run
else
    sudo certbot renew --quiet --no-random-sleep-on-renewal --deploy-hook "systemctl reload nginx"
fi

if [[ $VERBOSE -eq 1 ]]; then
    echo "[INFO] 检查 Nginx 配置是否仍然有效..." >&2
fi

if sudo nginx -t &>/dev/null; then
    echo '{"status": "ok"}'
    exit 0
else
    echo "Error: Nginx 配置验证失败，请检查" >&2
    exit 1
fi
