# Tailscale Manager - Tailscale 管理工具集

一个专门用于 Tailscale 安装、配置、故障排除和日常管理的工具集合。

## 🎯 项目简介

本项目旨在提供一套完整的 Tailscale 管理解决方案，包括：
- 📦 自动化安装脚本
- ⚙️ 配置管理工具
- 🔧 故障诊断和修复
- 📊 网络监控和状态检查
- 📚 详细的文档和最佳实践

## 🚀 快速开始

### 安装 Tailscale
```bash
# 使用自动安装脚本
sudo ./scripts/install-tailscale.sh

# 或者手动安装（Ubuntu/Debian）
curl -fsSL https://tailscale.com/install.sh | sh
```

### 解决网络冲突
```bash
# 检查网络冲突
./scripts/check-network-conflicts.sh

# 安全启动（推荐用于云服务器）
sudo tailscale up --netfilter-mode=off --accept-dns=false
```

### 配置开机自启
```bash
# 自动配置开机自启（推荐）
sudo ./scripts/setup-auto-start.sh

# 或手动配置
sudo systemctl enable tailscaled
sudo cp configs/tailscale-auto-connect.service /etc/systemd/system/
sudo systemctl enable tailscale-auto-connect
```

## 📁 项目结构

```
tailscale-manager/
├── README.md                    # 本文档
├── INSTALL.md                   # 详细安装指南
├── TROUBLESHOOTING.md           # 故障排除指南
├── BEST-PRACTICES.md            # 最佳实践
├── CHANGELOG.md                 # 更新日志
├── scripts/                    # 自动化脚本
│   ├── install-tailscale.sh    # 安装脚本
│   ├── setup-auto-start.sh     # 开机自启配置脚本
│   ├── check-network-conflicts.sh  # 网络冲突检查
│   ├── tailscale-status.sh     # 状态检查脚本
│   └── backup-config.sh        # 配置备份脚本
├── configs/                    # 配置文件模板
│   ├── tailscale.conf          # 系统配置模板
│   ├── tailscale-auto-connect.service  # 开机自启服务文件
│   └── acl-examples.json       # ACL 配置示例
├── docs/                       # 详细文档
│   ├── network-troubleshooting.md
│   ├── cloud-provider-notes.md
│   └── advanced-configuration.md
└── logs/                       # 日志目录
    └── troubleshooting-log.md  # 问题记录
```

## 🌟 主要功能

### 1. 网络冲突解决 ✅
- 自动检测云服务商 DNS 冲突（阿里云、腾讯云等）
- 提供安全的启动参数配置
- 验证网络连通性

### 2. 开机自启配置 ✅
- 智能检测云服务商环境
- 自动生成 systemd 服务文件
- 一键配置开机自动连接

### 3. 自动化管理
- 一键安装和配置
- 服务状态监控
- 配置文件备份和恢复

### 3. 故障诊断
- 网络连接诊断
- 路由冲突检测
- 日志分析工具

### 4. 文档和最佳实践
- 详细的配置指南
- 云服务商特定说明
- 安全配置建议

## 🔧 常用命令

### 基本操作
```bash
# 检查 Tailscale 状态
./scripts/tailscale-status.sh

# 安全启动（适用于大多数云服务器）
sudo tailscale up --netfilter-mode=off --accept-dns=false

# 完全重启
sudo tailscale down && sudo tailscale up --netfilter-mode=off --accept-dns=false
```

### 故障排除
```bash
# 网络诊断
./scripts/check-network-conflicts.sh

# 查看详细日志
sudo journalctl -u tailscaled -f
```

## 🌐 云服务商支持

### 已测试平台
- ✅ **阿里云** - 解决 100.100.2.x DNS 冲突
- ⚠️ **腾讯云** - 待测试
- ⚠️ **华为云** - 待测试
- ⚠️ **AWS** - 待测试
- ⚠️ **Google Cloud** - 待测试

### 贡献测试结果
如果你在其他云平台测试了本工具，欢迎提交测试结果！

## 📝 更新日志

### v1.0.0 (2025-08-10)
- ✅ 创建项目基础结构
- ✅ 解决阿里云 DNS 冲突问题
- ✅ 完成基础故障排除文档
- ✅ 创建网络冲突检查脚本

## 🤝 贡献指南

欢迎提交 Issues 和 Pull Requests！特别是：
- 新的云服务商支持
- 故障排除经验分享
- 脚本改进建议

## 📄 许可证

MIT License - 详见 LICENSE 文件

## 🔗 相关项目

- [tailscale-derp](../tailscale-derp/) - Tailscale Custom DERP 服务器部署
- [nginx-domain-manager](../nginx-domain-manager/) - Nginx 域名管理工具

---

**最后更新**: 2025-08-10  
**项目维护**: dangerwedaren@gmail.com
