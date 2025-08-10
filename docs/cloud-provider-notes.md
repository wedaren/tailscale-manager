# 云服务商特别说明

不同的云服务商可能会有特定的网络配置，这些配置可能与 Tailscale 产生冲突。本文档记录了各个云服务商的特殊情况和解决方案。

## 🌥️ 阿里云 (Alibaba Cloud)

### 环境特点
- 使用 100.100.2.x 网段作为内部 DNS 服务器
- 常见 DNS IP: `100.100.2.136`, `100.100.2.138`
- 这些 IP 通过 DHCP 自动配置到路由表

### 冲突原因
Tailscale 使用 100.64.0.0/10 网段（RFC 6598 CGNAT），与阿里云的 100.100.2.x 网段重叠，导致路由冲突。

### ✅ 验证测试的解决方案
```bash
# 安全启动命令
sudo tailscale up --netfilter-mode=off --accept-dns=false --accept-routes=false
```

### 验证步骤
```bash
# 1. 检查路由冲突
ip route show | grep '^100\.'

# 2. 测试外网连接
ping -c 3 8.8.8.8

# 3. 测试 DNS 解析
ping -c 3 google.com

# 4. 验证 Tailscale 功能
tailscale status
```

### 注意事项
- ❌ **绝对不要删除** 100.100.2.x 的路由！这会导致 DNS 解析失败
- ✅ 使用 `--netfilter-mode=off` 让 Tailscale 不管理 iptables
- ✅ 使用 `--accept-dns=false` 保持阿里云的 DNS 配置

---

## 🌥️ 腾讯云 (Tencent Cloud)

### 环境特点
- 待测试和验证
- 可能也有内部网络服务使用 100.x.x.x 网段

### 预期解决方案
```bash
# 推荐启动命令（待验证）
sudo tailscale up --netfilter-mode=off --accept-dns=false
```

### 需要测试
- [ ] 内部 DNS 服务器配置
- [ ] 路由表冲突检测
- [ ] 最佳启动参数

---

## 🌥️ 华为云 (Huawei Cloud)

### 环境特点
- 待测试和验证

### 预期解决方案
```bash
# 推荐启动命令（待验证）
sudo tailscale up --netfilter-mode=off --accept-dns=false
```

### 需要测试
- [ ] 内部网络配置
- [ ] DNS 服务器设置
- [ ] 路由冲突情况

---

## ☁️ Amazon Web Services (AWS)

### 环境特点
- 使用 169.254.x.x 网段的元数据服务
- 通常不会与 Tailscale 的 100.64.0.0/10 网段冲突

### 预期解决方案
```bash
# 标准启动命令（待验证）
sudo tailscale up
```

### 需要测试
- [ ] VPC 网络配置兼容性
- [ ] 安全组规则要求
- [ ] NAT 网关配置影响

---

## ☁️ Google Cloud Platform (GCP)

### 环境特点
- 待测试和验证

### 预期解决方案
```bash
# 标准启动命令（待验证）
sudo tailscale up
```

### 需要测试
- [ ] VPC 网络兼容性
- [ ] 防火墙规则配置
- [ ] 内部 DNS 设置

---

## 🔧 通用诊断步骤

无论使用哪个云服务商，都可以按以下步骤进行诊断：

### 1. 环境检测
```bash
# 使用我们的自动检测脚本
./scripts/check-network-conflicts.sh
```

### 2. 手动检测步骤
```bash
# 检查云服务商类型
curl -s --max-time 3 http://100.100.100.200/latest/meta-data/ # 阿里云
curl -s --max-time 3 http://metadata.tencentcloudapi.com/latest/ # 腾讯云
curl -s --max-time 3 http://169.254.169.254/latest/meta-data/ # AWS

# 检查网络配置
ip route show
resolvectl status

# 检查 100.x.x.x 网段使用情况
ip route show | grep '^100\.'
```

### 3. 测试连接
```bash
# 测试基本连接
ping -c 3 8.8.8.8
ping -c 3 google.com

# 测试 Tailscale
tailscale status
tailscale netcheck
```

## 📝 贡献测试结果

如果你在某个云服务商上测试了 Tailscale，请帮助完善这份文档：

### 测试报告模板
```markdown
## 云服务商: [服务商名称]
### 测试日期: YYYY-MM-DD
### 系统环境: [操作系统版本]
### Tailscale 版本: [版本号]

### 发现的问题:
- 描述遇到的具体问题

### 解决方案:
- 有效的启动参数配置
- 其他必要的配置步骤

### 验证结果:
- [ ] 外网连接正常
- [ ] DNS 解析正常  
- [ ] Tailscale 网络正常
- [ ] 设备间通信正常
```

### 提交方式
1. 在项目中创建 Issue
2. 或者直接提交 Pull Request 更新本文档
3. 或者发邮件到 dangerwedaren@gmail.com

## 🚨 紧急情况处理

如果 Tailscale 导致云服务器完全无法联网：

### 立即恢复步骤
```bash
# 1. 立即停止 Tailscale
sudo tailscale down
sudo systemctl stop tailscaled

# 2. 检查网络是否恢复
ping -c 3 8.8.8.8

# 3. 如果仍有问题，重启网络服务
sudo systemctl restart networking     # Ubuntu/Debian
sudo systemctl restart NetworkManager # CentOS/RHEL

# 4. 检查并清理异常路由（小心操作）
ip route show
# 如果有异常路由，可以删除（但要确保不删除重要的系统路由）
# sudo ip route del <异常路由>

# 5. 重新配置 Tailscale
sudo systemctl start tailscaled
sudo tailscale up --netfilter-mode=off --accept-dns=false
```

### 预防措施
- 在生产环境测试前，建议先在测试环境验证
- 保持 SSH 连接，在另一个终端测试 Tailscale
- 记录原始的网络配置，以便紧急恢复

---

*本文档会持续更新，记录更多云服务商的测试结果和解决方案。*
