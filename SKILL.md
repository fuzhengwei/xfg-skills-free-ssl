---
name: xfg-skills-free-ssl
description: 为 Nginx 站点一键式申请并配置 Let's Encrypt 免费 HTTPS 证书，包含 DNS 检查、安全组提示、证书自动续期，并提供完整友好引导与故障排查。
license: Apache-2.0
compatibility: 支持 Linux（Debian/Ubuntu 优先）、Nginx、可联网环境、已完成 DNS 解析的域名
metadata:
  author: xfg-studio
  version: "1.1.0"
  category: devops
allowed-tools: Bash(bash:*) Read Write
---

# 免费 SSL 申请技能

本技能专注于：把一个 HTTP 站点快速升级到 HTTPS，使用 Let's Encrypt 免费证书，推荐配合 Nginx 反向代理使用。

## 功能概述

你需要在用户说“申请免费 ssl”、“配置 https”、“certbot 配置证书”等需求时，提供完整友好的执行流程：
- 先确认域名与环境
- 再检查 DNS 解析
- 安装 certbot、签发证书、配置跳转与自动续期
- 优先使用用户已安装的 Nginx

过程中要主动给出提示，不要只贴命令/错误信息，要说明当前做什么以及下一步指引。

## 使用方法

### 触发条件
- 用户明确说“申请免费 ssl”、“配置 https”
- 用户问“certbot 怎么用”、“Let's Encrypt 免费证书”
- 用户说“把这个站点改成 https”
- 用户说“证书快过期了，帮我续期”
- 用户遇到“网站不安全”提示

### 标准工作流
1. **确认必要信息**
   - 如果未提供域名，先询问：“请告诉我您要配置证书的域名是什么？”
   - 如果未提供邮箱，可默认使用 `admin@your-domain.com`，并告知用户后续可在 certbot 配置中替换

2. **检查并准备环境**
   - 优先检查域名解析是否只指向当前服务器公网 IP（不要同时解析到多个 IP）
   - 检查 Nginx 是否已安装（优先使用用户已安装的，不重复安装）
   - 如果确实未安装 Nginx，再自动安装并启动：
     ```bash
     sudo apt-get update
     sudo apt-get install -y nginx
     sudo systemctl start nginx
     sudo systemctl enable nginx
     ```

3. **使用脚本自动化**
   - 推荐运行 `scripts/setup-free-ssl.sh`（提供域名和邮箱参数）
   - 如果不想用脚本，直接执行 certbot 命令也可以

4. **验证与收尾**
   - 检查 Nginx 语法：`sudo nginx -t`
   - 检查 443 端口监听：`sudo ss -lntp`
   - 本机 curl 验证，同时提醒用户从浏览器验证
   - 如果本机通但公网不通，提示检查“云服务器安全组/防火墙是否放行 TCP 80/443”

5. **证书续期（重要）**
   - certbot 默认已配置自动续期（cron/systemd timer）
   - 可运行一次 `sudo certbot renew --dry-run` 验证
   - 如果需要额外的定时续期，可以推荐使用 `scripts/check-renewal.sh`，并给出 crontab 配置建议

## 可用脚本

- **`scripts/check-dns.sh`** — 快速检查域名 DNS 解析是否已指向当前服务器
- **`scripts/setup-free-ssl.sh`** — 一键式免费证书申请（域名和邮箱作为参数传入），优先使用用户已安装的 Nginx
- **`scripts/check-renewal.sh`** — 检查证书是否即将过期，并按需执行续期（临近 30 天以内会触发）

## 可用资源

- **`references/dns-checklist.md`** — DNS 检查与生效指引（遇到 DNS 问题时读取）
- **`references/troubleshooting.md`** — 证书申请常见问题排查（遇到失败时读取）
- **`references/nginx-ssl-config.md`** — 建议的 Nginx SSL 安全配置（需要增强配置时读取）
- **`assets/nginx-ssl-example.conf`** — 示例 SSL 配置模板（需要生成配置文件时使用）
- **`assets/crontab-renewal.txt`** — 证书自动续期定时任务配置示例（需要设置定时续期时使用）

## 友好提示规范

执行过程中每做一步都给用户一句简短说明，例如：

- “我先帮您检查一下域名 DNS 解析是否已指向当前服务器。”
- “检测到您已安装 Nginx，直接使用现有环境。”
- “DNS 解析正常，现在开始安装 certbot。”
- “证书申请成功！我来帮您验证一下 Nginx 配置是否正确。”
- “本机验证通过！但公网可能还需要检查云安全组是否已放行 443。”
- “您可以配置一个定时任务自动续期，避免证书过期。”

错误时不要只贴错误堆栈，要翻译成大白话并给出下一步建议。

## Gotchas

- Let's Encrypt 不会为未正确解析到当前服务器的域名签发证书
- 如果一个域名同时解析到多个 IP，ACME 校验可能落到错误服务器上导致失败
- 本机 `curl` 成功不代表公网一定能访问，云安全组/防火墙经常是问题根源
- 证书默认有效期 3 个月，certbot 会在到期前自动续期（无需人工干预）
- 如果用户已安装 Nginx，优先使用现有环境，不要重复安装
- 建议后端业务服务只监听 `127.0.0.1`，对外只暴露 Nginx 80/443
- DNS 修改后可能有缓存，不要短时间内反复重试 certbot，避免触发频率限制
