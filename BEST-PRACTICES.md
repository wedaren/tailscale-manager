# Tailscale 最佳实践指南

本文档提供 Tailscale 的最佳配置和使用建议，帮助你安全、高效地使用 Tailscale。

## 🔐 安全配置

### 1. ACL (访问控制列表) 配置

在 Tailscale 管理面板中配置 ACL，控制设备间的访问权限：

```json
{
  "tagOwners": {
    "tag:server": ["user@example.com"],
    "tag:client": ["user@example.com"]
  },
  "acls": [
    // 只允许客户端设备访问服务器的特定端口
    {
      "action": "accept",
      "src": ["tag:client"],
      "dst": ["tag:server:22", "tag:server:80", "tag:server:443"]
    },
    // 禁止服务器主动连接客户端
    {
      "action": "drop",
      "src": ["tag:server"],
      "dst": ["tag:client:*"]
    }
  ]
}
```

### 2. 设备标签管理

为不同类型的设备分配标签：

```bash
# 为服务器添加标签
sudo tailscale up --advertise-tags=tag:server

# 为客户端设备添加标签
sudo tailscale up --advertise-tags=tag:client

# 为开发环境添加标签
sudo tailscale up --advertise-tags=tag:dev
```

### 3. SSH 密钥管理

使用 Tailscale SSH 功能：

```bash
# 启用 Tailscale SSH
sudo tailscale up --ssh

# 在 ACL 中配置 SSH 权限
{
  "ssh": [
    {
      "action": "accept",
      "src": ["tag:admin"],
      "dst": ["tag:server"],
      "users": ["root", "admin"]
    }
  ]
}
```

## 🌐 网络配置最佳实践

### 1. 云服务器配置

**阿里云/腾讯云等推荐配置：**
```bash
# 避免网络冲突的安全启动
sudo tailscale up --netfilter-mode=off --accept-dns=false --accept-routes=false --advertise-tags=tag:server
```

**标准配置：**
```bash
# 一般环境的标准配置
sudo tailscale up --accept-routes=false --advertise-tags=tag:client
```

### 2. 子网路由配置

如果需要通过 Tailscale 访问本地网络：

```bash
# 在网关设备上启用子网路由
sudo tailscale up --advertise-routes=192.168.1.0/24 --advertise-tags=tag:gateway

# 在其他设备上接受路由
sudo tailscale up --accept-routes
```

### 3. 出口节点配置

设置出口节点用于统一的外网访问：

```bash
# 配置为出口节点
sudo tailscale up --advertise-exit-node --advertise-tags=tag:exit-node

# 使用出口节点
sudo tailscale up --exit-node=exit-node-device-name
```

## 🔧 维护和监控

### 1. 定期健康检查

创建定期检查脚本：

```bash
#!/bin/bash
# 保存为 /etc/cron.daily/tailscale-health-check

# 检查服务状态
if ! systemctl is-active --quiet tailscaled; then
    logger "Tailscale: tailscaled service is down, restarting..."
    systemctl restart tailscaled
fi

# 检查网络连通性
if ! tailscale status &>/dev/null; then
    logger "Tailscale: network issue detected, attempting reconnection..."
    tailscale down
    sleep 5
    tailscale up --netfilter-mode=off --accept-dns=false
fi

# 检查外网连通性
if ! ping -c 3 8.8.8.8 &>/dev/null; then
    logger "Tailscale: external connectivity lost"
    # 发送告警邮件或通知
fi
```

### 2. 日志监控

配置日志轮转和监控：

```bash
# 创建 logrotate 配置
cat > /etc/logrotate.d/tailscale << EOF
/var/log/tailscale/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    postrotate
        systemctl reload tailscaled
    endscript
}
EOF
```

### 3. 性能监控

监控关键指标：

```bash
#!/bin/bash
# Tailscale 性能监控脚本

# 检查 DERP 延迟
DERP_LATENCY=$(tailscale netcheck 2>/dev/null | grep "DERP latency" | awk '{print $3}')
if [[ ! -z "$DERP_LATENCY" ]] && [[ "${DERP_LATENCY%ms}" -gt 200 ]]; then
    logger "Tailscale: High DERP latency: $DERP_LATENCY"
fi

# 检查设备连接数
CONNECTED_DEVICES=$(tailscale status | grep -c "100\.")
logger "Tailscale: $CONNECTED_DEVICES devices connected"

# 检查流量统计（如果支持）
tailscale netcheck | grep -E "(tx|rx)" | logger
```

## 🚀 性能优化

### 1. 网络优化

```bash
# 优化网络参数
echo 'net.core.rmem_max = 26214400' >> /etc/sysctl.conf
echo 'net.core.rmem_default = 26214400' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 26214400' >> /etc/sysctl.conf
echo 'net.core.wmem_default = 26214400' >> /etc/sysctl.conf
sysctl -p
```

### 2. 系统资源优化

```bash
# 调整系统限制
echo 'tailscale soft nofile 65536' >> /etc/security/limits.conf
echo 'tailscale hard nofile 65536' >> /etc/security/limits.conf

# 调整 systemd 服务限制
mkdir -p /etc/systemd/system/tailscaled.service.d
cat > /etc/systemd/system/tailscaled.service.d/override.conf << EOF
[Service]
LimitNOFILE=65536
EOF
systemctl daemon-reload
systemctl restart tailscaled
```

## 📱 设备管理

### 1. 设备命名规范

建议使用有意义的设备名称：

```bash
# 设置设备名称
sudo tailscale up --hostname=prod-web-01
sudo tailscale up --hostname=dev-db-server
sudo tailscale up --hostname=john-laptop
```

### 2. 设备生命周期管理

- 定期清理离线设备
- 为临时设备设置过期时间
- 使用认证密钥管理自动化部署

```bash
# 使用一次性认证密钥
tailscale up --authkey=tskey-auth-xxxxxx-one-time
```

## 🔄 备份和恢复

### 1. 配置备份

```bash
#!/bin/bash
# 备份 Tailscale 配置

BACKUP_DIR="/opt/backups/tailscale"
mkdir -p $BACKUP_DIR

# 备份配置文件
cp -r /var/lib/tailscale/ $BACKUP_DIR/
cp /etc/systemd/system/tailscaled.service.d/ $BACKUP_DIR/ 2>/dev/null || true

# 导出设备信息
tailscale status --json > $BACKUP_DIR/devices.json

# 压缩备份
tar -czf $BACKUP_DIR/tailscale-backup-$(date +%Y%m%d).tar.gz -C $BACKUP_DIR .

echo "Tailscale configuration backed up to $BACKUP_DIR"
```

### 2. 灾难恢复计划

1. **记录关键信息**：
   - Tailscale 账户信息
   - 设备认证密钥
   - ACL 配置
   - 网络拓扑图

2. **恢复步骤**：
   ```bash
   # 安装 Tailscale
   curl -fsSL https://tailscale.com/install.sh | sh
   
   # 恢复配置
   systemctl stop tailscaled
   cp -r /backup/tailscale/var/lib/tailscale/* /var/lib/tailscale/
   systemctl start tailscaled
   
   # 重新认证（如果需要）
   tailscale up --force-reauth
   ```

## 🚨 故障预防

### 1. 常见问题预防

- 定期更新 Tailscale 版本
- 监控证书过期时间
- 检查防火墙规则变化
- 验证 DNS 配置正确性

### 2. 变更管理

在生产环境中进行任何 Tailscale 配置变更时：

1. **测试环境验证**
2. **制定回滚计划**
3. **分步骤执行**
4. **实时监控**
5. **文档记录**

## 📋 检查清单

### 安全检查清单
- [ ] ACL 规则已配置
- [ ] 设备标签已分配
- [ ] SSH 访问已限制
- [ ] 定期密钥轮转
- [ ] 离线设备已清理

### 性能检查清单
- [ ] DERP 延迟正常 (<100ms)
- [ ] 设备间直连正常
- [ ] 无路由冲突
- [ ] 系统资源充足
- [ ] 网络带宽满足需求

### 运维检查清单
- [ ] 监控告警已配置
- [ ] 日志轮转已设置
- [ ] 备份策略已实施
- [ ] 文档已更新
- [ ] 团队培训已完成

---

*遵循这些最佳实践，可以确保 Tailscale 网络的安全性、稳定性和高性能。*
