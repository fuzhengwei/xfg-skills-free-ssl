# DNS 检查清单

在申请 Let's Encrypt 免费 SSL 证书前，请先完成以下检查：

## 1. 域名 DNS 解析检查

### 目标
确保：
- 域名只解析到**当前服务器公网 IP**，不要同时解析到多个 IP
- 解析生效时间在 2 - 10 分钟（建议等待生效后再继续）

### 验证方法

**服务器本地验证：**
```bash
# 方法 1：getent
getent hosts your-domain.com

# 方法 2：nslookup
nslookup your-domain.com

# 方法 3：dig
dig your-domain.com +short

# 方法 4：使用技能自带脚本
bash scripts/check-dns.sh --domain your-domain.com --verbose
```

**本地电脑验证：**
```bash
# macOS / Linux
ping your-domain.com
nslookup your-domain.com

# Windows
ping your-domain.com
nslookup your-domain.com
```

## 2. 如果 DNS 未生效或解析错误

### 常见场景
1. **解析到多个 IP**
   - 去域名控制台删除多余的 A / AAAA 记录
   - 只保留指向当前服务器的 IP

2. **解析到旧 IP**
   - 去域名控制台修改为新 IP
   - 等待 DNS 生效后再继续

3. **域名解析到 Cloudflare 代理模式**
   - 若使用 CF 代理，建议先改为“DNS Only”
   - 或者使用 CF SSL / DNS-01 验证（此技能默认采用 HTTP-01，不包含 DNS-01）

## 3. 建议等待的 DNS 生效时间
- 新增或修改：通常 2 - 10 分钟
- 删除记录：立即生效，但本地缓存可能保留更久

## 4. 本地电脑强制刷新 DNS 缓存
```bash
# macOS
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# Windows
ipconfig /flushdns

# Linux (systemd-resolved)
sudo systemd-resolve --flush-caches
```
