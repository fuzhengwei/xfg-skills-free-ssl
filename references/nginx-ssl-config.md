# 推荐的 Nginx SSL 安全配置

本文档用于在需要时增强 Nginx SSL 配置的安全性。

---

## 标准安全配置（推荐）

你可以在 `assets/nginx-ssl-example.conf` 中找到完整示例。

### 核心安全选项
```nginx
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name your-domain.com;

    # 证书路径（certbot 生成，保持原样即可）
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # 安全推荐配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS（可选但推荐）
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # 其他安全头
    add_header X-Frame-Options SAMEORIGIN always;
    add_header X-Content-Type-Options nosniff always;

    # 反向代理（如适用）
    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

## HTTP → HTTPS 跳转

certbot `--redirect` 参数会自动为你添加跳转配置。
如果你需要手动配置，可以参考：
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name your-domain.com;

    # 强制跳转
    return 301 https://$host$request_uri;
}
```

---

## 证书自动续期验证

certbot 安装后默认已配置自动续期（cron 或 systemd timer）。

你可以手动测试续期逻辑是否正常：
```bash
sudo certbot renew --dry-run
```

如果返回“Dry run completed successfully”，说明续期逻辑正常。
