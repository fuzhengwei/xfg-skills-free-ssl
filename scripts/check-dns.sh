#!/usr/bin/env bash
# check-dns.sh — 检查域名 DNS 解析是否指向当前服务器
#
# 用法:
#   bash scripts/check-dns.sh --domain your-domain.com
#   bash scripts/check-dns.sh --domain your-domain.com --verbose
#
# 退出码:
#   0 - DNS 解析指向当前服务器
#   1 - DNS 未解析或解析到错误 IP
#   2 - 参数错误

set -euo pipefail

DOMAIN=""
VERBOSE=0
SERVER_IP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)  DOMAIN="$2"; shift 2 ;;
        --verbose) VERBOSE=1; shift ;;
        --help|-h)
            echo "用法: bash scripts/check-dns.sh --domain <domain> [--verbose]"
            echo ""
            echo "检查域名 DNS 解析是否指向当前服务器"
            echo ""
            echo "选项:"
            echo "  --domain DOMAIN  要检查的域名 (必填)"
            echo "  --verbose        输出详细信息"
            echo "  --help           显示帮助信息"
            echo ""
            echo "示例:"
            echo "  bash scripts/check-dns.sh --domain portainer.your-domain.com"
            exit 0
            ;;
        *)
            echo "Error: 未知参数: $1" >&2
            exit 2
            ;;
    esac
done

if [[ -z "$DOMAIN" ]]; then
    echo "Error: --domain 是必填参数" >&2
    echo "用法: bash scripts/check-dns.sh --domain <domain>" >&2
    exit 2
fi

if [[ $VERBOSE -eq 1 ]]; then
    echo "[INFO] 正在获取当前服务器公网 IP..." >&2
fi

# 尝试几种常见方式获取当前公网 IP
if command -v curl &>/dev/null; then
    SERVER_IP=$(curl -s -4 --connect-timeout 5 ifconfig.me 2>/dev/null || curl -s -4 --connect-timeout 5 ip.sb 2>/dev/null || true)
fi

if [[ -z "$SERVER_IP" ]]; then
    echo "Error: 无法自动获取当前服务器公网 IP，请手动确认。" >&2
    exit 1
fi

if [[ $VERBOSE -eq 1 ]]; then
    echo "[INFO] 当前服务器公网 IP: $SERVER_IP" >&2
fi

if [[ $VERBOSE -eq 1 ]]; then
    echo "[INFO] 正在查询域名 $DOMAIN 的 DNS 解析..." >&2
fi

# 查询域名解析到的 IP（使用多种工具）
RESOLVED_IPS=""
if command -v getent &>/dev/null; then
    RESOLVED_IPS=$(getent hosts "$DOMAIN" 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)
fi

if [[ -z "$RESOLVED_IPS" ]] && command -v nslookup &>/dev/null; then
    RESOLVED_IPS=$(nslookup "$DOMAIN" 2>/dev/null | grep -A 10 'Name:' | grep 'Address:' | awk '{print $2}' | grep -v '#53' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)
fi

if [[ -z "$RESOLVED_IPS" ]]; then
    echo '{"status": "error", "reason": "dns_not_resolved", "domain": "'"$DOMAIN"'", "expected_ip": "'"$SERVER_IP"'"}'
    exit 1
fi

# 去重并统计解析到的 IP
UNIQUE_IPS=$(echo "$RESOLVED_IPS" | sort | uniq)
IP_COUNT=$(echo "$UNIQUE_IPS" | wc -l | xargs)

if [[ $VERBOSE -eq 1 ]]; then
    echo "[INFO] 域名解析到 $IP_COUNT 个 IP: $UNIQUE_IPS" >&2
fi

# 检查是否包含当前服务器 IP
if echo "$UNIQUE_IPS" | grep -q "^$SERVER_IP$"; then
    if [[ "$IP_COUNT" -eq 1 ]]; then
        echo '{"status": "ok", "domain": "'"$DOMAIN"'", "resolved_ip": "'"$SERVER_IP"'"}'
        exit 0
    else
        echo '{"status": "warning", "reason": "multiple_ips", "domain": "'"$DOMAIN"'", "expected_ip": "'"$SERVER_IP"'", "all_ips": "'"$(echo "$UNIQUE_IPS" | tr '\n' ' ' | sed 's/ $//')"'"}'
        exit 1
    fi
else
    echo '{"status": "error", "reason": "wrong_ip", "domain": "'"$DOMAIN"'", "expected_ip": "'"$SERVER_IP"'", "resolved_ips": "'"$(echo "$UNIQUE_IPS" | tr '\n' ' ' | sed 's/ $//')"'"}'
    exit 1
fi
