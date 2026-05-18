#!/usr/bin/env bash
# setup-free-ssl.sh — 为 Nginx 站点申请并配置 Let's Encrypt 免费 SSL
#
# 用法:
#   bash scripts/setup-free-ssl.sh --domain your-domain.com --email admin@your-domain.com
#   bash scripts/setup-free-ssl.sh --domain your-domain.com --email admin@your-domain.com --dry-run
#   bash scripts/setup-free-ssl.sh --help
#
# 退出码:
#   0 - 证书申请并配置成功
#   1 - 环境检查失败或命令执行失败
#   2 - 参数错误

set -euo pipefail

DOMAIN=""
EMAIL=""
DRY_RUN=0
VERBOSE=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)  DOMAIN="$2"; shift 2 ;;
        --email)   EMAIL="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --verbose) VERBOSE=1; shift ;;
        --help|-h)
            echo "用法: bash scripts/setup-free-ssl.sh --domain <domain> --email <email> [--dry-run] [--verbose]"
            echo ""
            echo "为 Nginx 站点申请并配置 Let's Encrypt 免费 HTTPS 证书"
            echo ""
            echo "选项:"
            echo "  --domain DOMAIN  要配置证书的域名 (必填)"
            echo "  --email EMAIL    用于证书通知的邮箱地址 (必填)"
            echo "  --dry-run        仅测试不实际申请证书"
            echo "  --verbose        输出详细信息"
            echo "  --help           显示帮助信息"
            echo ""
            echo "示例:"
            echo "  bash scripts/setup-free-ssl.sh --domain portainer.your-domain.com --email admin@your-domain.com"
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
    echo "用法: bash scripts/setup-free-ssl.sh --domain <domain> --email <email>" >&2
    exit 2
fi

if [[ -z "$EMAIL" ]]; then
    echo "Error: --email 是必填参数" >&2
    echo "用法: bash scripts/setup-free-ssl.sh --domain <domain> --email <email>" >&2
    exit 2
fi

if [[ $VERBOSE -eq 1 ]]; then
    echo "[INFO] 域名: $DOMAIN" >&2
    echo "[INFO] 邮箱: $EMAIL" >&2
fi

# 检查是否有 sudo 权限
if ! sudo true &>/dev/null; then
    echo "Error: 需要 sudo 权限执行此脚本，请以可使用 sudo 的用户运行" >&2
    exit 1
fi

# 检查 Nginx 是否已安装（优先使用用户已安装的）
NGINX_INSTALLED=0
if command -v nginx &>/dev/null; then
    NGINX_INSTALLED=1
    if [[ $VERBOSE -eq 1 ]]; then
        NGINX_VERSION=$(nginx -v 2>&1)
        echo "[INFO] 检测到用户已安装 Nginx: $NGINX_VERSION" >&2
    fi
fi

if [[ "$NGINX_INSTALLED" -eq 0 ]]; then
    if [[ $VERBOSE -eq 1 ]]; then
        echo "[INFO] 未检测到 Nginx，正在安装..." >&2
    fi
    # 尝试根据发行版安装 Nginx
    if command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y nginx
        sudo systemctl start nginx
        sudo systemctl enable nginx
    elif command -v yum &>/dev/null; then
        sudo yum install -y nginx
        sudo systemctl start nginx
        sudo systemctl enable nginx
    else
        echo "Error: 无法自动检测包管理器，请先手动安装 Nginx" >&2
        exit 1
    fi
fi

# 检查 Nginx 是否正在监听 80（无论是否刚安装的）
if ! sudo ss -lntp | grep -q ':80'; then
    echo "Error: 未检测到 Nginx 监听 80 端口，请先启动 Nginx" >&2
    exit 1
fi

if [[ $VERBOSE -eq 1 ]]; then
    echo "[INFO] Nginx 已就绪，正在检查 certbot..." >&2
fi

# 检查 certbot 是否安装
CERTBOT_INSTALLED=0
if command -v certbot &>/dev/null; then
    CERTBOT_INSTALLED=1
    if [[ $VERBOSE -eq 1 ]]; then
        CERTBOT_VERSION=$(certbot --version 2>&1)
        echo "[INFO] 检测到 certbot 已安装: $CERTBOT_VERSION" >&2
    fi
fi

if [[ "$CERTBOT_INSTALLED" -eq 0 ]]; then
    if [[ $VERBOSE -eq 1 ]]; then
        echo "[INFO] certbot 未安装，正在安装..." >&2
    fi
    if command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y certbot python3-certbot-nginx || true
    elif command -v yum &>/dev/null; then
        sudo yum install -y certbot python3-certbot-nginx || true
    fi
fi

# 如果包管理器安装失败，尝试 snap
if ! command -v certbot &>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
        echo "[INFO] 尝试通过 snap 安装 certbot..." >&2
    fi
    if command -v snap &>/dev/null; then
        sudo snap install --classic certbot
        sudo ln -sf /snap/bin/certbot /usr/bin/certbot || true
    fi
fi

if ! command -v certbot &>/dev/null; then
    echo "Error: certbot 安装失败，请手动安装 certbot 与 python3-certbot-nginx" >&2
    exit 1
fi

if [[ $VERBOSE -eq 1 ]]; then
    echo "[INFO] certbot 已就绪，开始申请证书..." >&2
fi

if [[ $DRY_RUN -eq 1 ]]; then
    if [[ $VERBOSE -eq 1 ]]; then
        echo "[INFO] 执行 dry-run 仅测试..." >&2
    fi
    sudo certbot certonly --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --dry-run
else
    sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect
fi

if [[ $VERBOSE -eq 1 ]]; then
    echo "[INFO] 验证 Nginx 配置..." >&2
fi

if sudo nginx -t &>/dev/null; then
    sudo systemctl reload nginx
    echo '{"status": "ok", "domain": "'"$DOMAIN"'"}'
    exit 0
else
    echo "Error: Nginx 配置验证失败，请检查" >&2
    exit 1
fi
