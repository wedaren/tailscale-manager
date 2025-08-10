# Tailscale 故障排除指南

本文档记录了 Tailscale 使用过程中的常见问题和解决方案。

## 🔧 基础故障排除

### 检查服务状态
```bash
# 检查 tailscaled 服务状态
sudo systemctl status tailscaled

# 检查 Tailscale 连接状态
tailscale status

# 查看详细日志
sudo journalctl -u tailscaled -f
```

### 基本重启步骤
```bash
# 完全重启 Tailscale
sudo tailscale down
sudo systemctl restart tailscaled
sudo tailscale up --netfilter-mode=off --accept-dns=false
```

## 🌐 网络连接问题

### 问题1: 启动 Tailscale 后无法访问外网

**症状**:
- 启动 Tailscale 后，ping 外网 IP 失败
- 网页无法加载
- DNS 解析错误

**诊断步骤**:
```bash
# 1. 检查路由表
ip route show

# 2. 检查 DNS 配置
cat /etc/resolv.conf
resolvectl status  # 或 systemd-resolve --status

# 3. 测试基本连接
ping -c 3 8.8.8.8
ping -c 3 google.com
```

**常见原因和解决方案**:

#### A. 云服务商 DNS 冲突 ⭐ 最常见

**阿里云服务器**:
- DNS 服务器: 100.100.2.136, 100.100.2.138
- 与 Tailscale 的 100.64.0.0/10 网段冲突

**解决方案**:
```bash
# 使用 netfilter-mode=off 启动
sudo tailscale up --netfilter-mode=off --accept-dns=false --accept-routes=false
```

**验证修复**:
```bash
# 测试外网连接
ping -c 3 8.8.8.8
curl -I google.com

# 确认 Tailscale 正常工作
tailscale status
```

#### B. iptables 规则冲突

**症状**: 网络间歇性不通
**解决**:
```bash
# 清理冲突的 iptables 规则
sudo iptables -L -n -v
sudo iptables -t nat -L -n -v

# 重启网络服务
sudo systemctl restart networking  # Debian/Ubuntu
sudo systemctl restart NetworkManager  # 其他发行版
```

#### C. 路由优先级问题

**检查**:
```bash
ip route show table main
ip route show table local
```

**修复**:
```bash
# 手动添加默认路由（如果缺失）
sudo ip route add default via <gateway_ip> dev <interface>
```

### 问题2: Tailscale 设备间无法互通

**诊断**:
```bash
# 检查防火墙设置
sudo ufw status  # Ubuntu
sudo firewall-cmd --list-all  # CentOS/RHEL

# 测试 Tailscale 网络内连接
tailscale ping <device-name>
ping <tailscale-ip>
```

**解决**:
```bash
# 开放 Tailscale 端口
sudo ufw allow 41641/udp
sudo firewall-cmd --permanent --add-port=41641/udp
sudo firewall-cmd --reload
```

### 问题3: DNS 解析问题

**症状**: IP 可以 ping 通，但域名无法解析

**检查 DNS 配置**:
```bash
# 查看当前 DNS 服务器
resolvectl status

# 测试 DNS 解析
nslookup google.com
dig google.com
```

**解决方案**:
```bash
# 方案1: 使用公共 DNS
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf

# 方案2: 重启 DNS 服务
sudo systemctl restart systemd-resolved

# 方案3: 刷新 DNS 缓存
sudo resolvectl flush-caches
```

## 🔐 认证和权限问题

### 问题4: 无法连接到 tailscaled

**错误信息**: `failed to connect to local tailscaled`

**解决**:
```bash
# 启动 tailscaled 服务
sudo systemctl start tailscaled
sudo systemctl enable tailscaled

# 检查权限
sudo tailscale set --operator=$USER
```

### 问题5: 认证失败或过期

**解决**:
```bash
# 强制重新认证
sudo tailscale up --force-reauth

# 使用认证密钥（无头服务器）
sudo tailscale up --authkey=tskey-auth-xxxxxx
```

## 🚨 紧急恢复程序

### 网络完全不通时的恢复步骤

```bash
# 1. 立即停止 Tailscale
sudo tailscale down

# 2. 停止服务
sudo systemctl stop tailscaled

# 3. 检查网络是否恢复
ping -c 3 8.8.8.8

# 4. 如果仍有问题，重启网络服务
sudo systemctl restart networking
# 或
sudo systemctl restart NetworkManager

# 5. 重新配置 Tailscale
sudo systemctl start tailscaled
sudo tailscale up --netfilter-mode=off --accept-dns=false
```

## 📊 高级诊断工具

### 网络诊断脚本

创建一个网络诊断脚本：
```bash
#!/bin/bash
# 保存为 network-diagnostics.sh

echo "=== Tailscale Network Diagnostics ==="
echo

echo "1. Tailscale Status:"
tailscale status
echo

echo "2. Network Interfaces:"
ip addr show
echo

echo "3. Routing Table:"
ip route show
echo

echo "4. DNS Configuration:"
resolvectl status 2>/dev/null || cat /etc/resolv.conf
echo

echo "5. Connectivity Tests:"
echo "Testing external connectivity..."
ping -c 3 8.8.8.8 2>/dev/null && echo "✅ External IP reachable" || echo "❌ External IP unreachable"
ping -c 3 google.com 2>/dev/null && echo "✅ DNS resolution works" || echo "❌ DNS resolution failed"
echo

echo "6. Tailscale Service:"
sudo systemctl status tailscaled --no-pager -l
echo

echo "7. Recent Tailscale Logs:"
sudo journalctl -u tailscaled --since "10 minutes ago" --no-pager -l
```

### 性能诊断
```bash
# 检查 Tailscale 连接质量
tailscale netcheck

# 测试特定设备的连接
tailscale ping <device-name>

# 检查 DERP 服务器连接
tailscale derp map
```

## 📝 问题记录模板

当遇到新问题时，请记录以下信息：

```markdown
## 问题描述
- 日期: YYYY-MM-DD
- 系统: Ubuntu 20.04 / CentOS 8 / etc.
- Tailscale 版本: x.x.x
- 云服务商: 阿里云/腾讯云/AWS/etc.

## 症状
描述具体的问题现象...

## 环境信息
```bash
# 相关命令输出
tailscale status
ip route show
resolvectl status
```

## 解决步骤
1. 尝试的第一个方法...
2. 尝试的第二个方法...
3. 最终解决方案...

## 验证结果
- [ ] 外网连接正常
- [ ] Tailscale 网络正常
- [ ] DNS 解析正常
- [ ] 设备间通信正常
```

## 🔗 有用的链接

- [Tailscale 官方故障排除](https://tailscale.com/kb/1023/troubleshooting/)
- [Tailscale 网络检查工具](https://tailscale.com/kb/1080/cli/#netcheck)
- [Linux 网络诊断命令](https://tailscale.com/kb/1080/cli/)

---

**提示**: 如果本文档没有涵盖你遇到的问题，请提交 Issue 或 Pull Request，帮助完善这份故障排除指南。
