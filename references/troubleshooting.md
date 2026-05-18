# SSL 申请常见问题排查

本文档用于排查 Let's Encrypt 免费 SSL 申请过程中遇到的常见问题。

---

## 问题分类速查

### 1. certbot 失败：“unauthorized” / “404” / “503”

**原因：**
- 公网请求无法到达 Nginx 80 端口
- 安全组/防火墙未放行 80
- DNS 解析到错误 IP
- Nginx 未运行或未正确监听 80

**排查顺序：**
1. 检查云服务器安全组是否放行 TCP 80 入站
2. 检查服务器本地 iptables / ufw 是否放行
3. 检查 Nginx 状态：`sudo systemctl status nginx`
4. 检查 80 端口监听：`sudo ss -lntp | grep :80`
5. 检查域名解析是否只指向当前服务器 IP
6. 从服务器本地 curl 测试：`curl -v -L http://your-domain.com`

---

### 2. 本机成功但浏览器访问超时/连接被重置

**原因：**
- 公网访问被安全组/防火墙拦截
- 公网 IP 与端口映射关系不对
- 云服务商底层网络限制

**快速定位：**
```bash
# 服务器上运行 tcpdump，然后在浏览器访问
sudo tcpdump -i any -n -c 20 "port 80 or port 443"
```
- 抓不到包 → 流量未到服务器 → 检查安全组
- 抓到包但返回 RST / 无响应 → 检查 Nginx / iptables

---

### 3. certbot 安装失败：“package not found”

**解决：**
```bash
# 尝试 apt / yum 安装
# Debian / Ubuntu
sudo apt-get update
sudo apt-get install -y certbot python3-certbot-nginx

# 如果包不可用，尝试 snap
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# 确认安装成功
certbot --version
```

---

### 4. Nginx 重启/重载失败

**排查：**
```bash
# 先检查语法
sudo nginx -t

# 常见原因：
# - 配置文件缩进或格式错误
# - 引用的证书文件不存在或权限不正确
# - 端口被占用

# 查看详细日志
sudo tail -n 50 /var/log/nginx/error.log
```

---

### 5. 申请过多触发频率限制

Let's Encrypt 有频率限制（例如每小时相同域名次数限制）。
如果触发了，可以：
- 先用测试参数避免继续触发（`--dry-run`）
- 等待一小时后再重试
- 或换用一个新域名变体（如果是测试环境）
