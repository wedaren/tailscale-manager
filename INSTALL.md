# Tailscale 安装指南

本文档提供了在各种 Linux 发行版上安装 Tailscale 的详细步骤。

## 🔧 系统要求

- Linux 内核 3.13 或更高版本
- 网络管理权限（通常需要 root 或 sudo）
- 开放的互联网连接

## 📦 安装方法

### 方法1：官方一键安装脚本（推荐）

```bash
# 下载并执行官方安装脚本
curl -fsSL https://tailscale.com/install.sh | sh

# 或者先下载再执行
curl -fsSL https://tailscale.com/install.sh -o install-tailscale.sh
chmod +x install-tailscale.sh
sudo ./install-tailscale.sh
```

### 方法2：使用包管理器

#### Ubuntu/Debian
```bash
# 添加 Tailscale 仓库
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# 更新包列表并安装
sudo apt update
sudo apt install tailscale
```

#### CentOS/RHEL/Fedora
```bash
# CentOS/RHEL 7/8
sudo yum install yum-utils
sudo yum-config-manager --add-repo https://pkgs.tailscale.com/stable/centos/7/tailscale.repo
sudo yum install tailscale

# Fedora
sudo dnf install tailscale

# RHEL 9/CentOS Stream 9
sudo dnf install tailscale
```

#### Arch Linux
```bash
# 从 AUR 安装
yay -S tailscale
# 或者
paru -S tailscale
```

### 方法3：下载二进制文件

```bash
# 下载最新版本（以 amd64 为例）
wget https://pkgs.tailscale.com/stable/tailscale_latest_amd64.tgz

# 解压
tar xzf tailscale_latest_amd64.tgz

# 复制到系统目录
sudo cp tailscale_*/tailscale /usr/bin/
sudo cp tailscale_*/tailscaled /usr/sbin/

# 创建 systemd 服务文件
sudo cp tailscale_*/systemd/tailscaled.service /lib/systemd/system/
```

## ⚙️ 安装后配置

### 1. 启动服务
```bash
# 启动 tailscaled 守护进程
sudo systemctl start tailscaled

# 设置开机自启
sudo systemctl enable tailscaled

# 检查服务状态
sudo systemctl status tailscaled
```

### 2. 连接到 Tailscale 网络
```bash
# 基本连接（会打开浏览器进行认证）
sudo tailscale up

# 如果是服务器环境，使用认证密钥
sudo tailscale up --authkey=tskey-auth-xxxxxx
```

### 3. 云服务器特殊配置

对于云服务器（特别是阿里云、腾讯云等），推荐使用以下参数避免网络冲突：

```bash
# 推荐的云服务器启动命令
sudo tailscale up --netfilter-mode=off --accept-dns=false --accept-routes=false
```

参数说明：
- `--netfilter-mode=off`: 不管理 iptables 规则，避免与云服务商内部网络冲突
- `--accept-dns=false`: 不使用 Tailscale 的 DNS 设置，保持云服务商的 DNS
- `--accept-routes=false`: 不接受其他节点的路由广播

## 🔍 安装验证

### 检查安装状态
```bash
# 检查版本
tailscale version

# 检查连接状态
tailscale status

# 检查 IP 地址
tailscale ip
```

### 网络连通性测试
```bash
# 测试外网连接
ping -c 3 8.8.8.8

# 测试 DNS 解析
nslookup google.com

# 测试 Tailscale 网络内其他设备
ping 100.x.x.x  # 其他设备的 Tailscale IP
```

## 🚨 常见安装问题

### 问题1: 服务启动失败
```bash
# 检查错误日志
sudo journalctl -u tailscaled -n 50

# 常见解决方法
sudo systemctl daemon-reload
sudo systemctl restart tailscaled
```

### 问题2: 权限问题
```bash
# 如果遇到权限问题，设置操作员
sudo tailscale set --operator=$USER

# 然后就可以不用 sudo 操作
tailscale status
```

### 问题3: 防火墙问题
```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 41641/udp

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=41641/udp
sudo firewall-cmd --reload

# 或者完全禁用防火墙（不推荐生产环境）
sudo ufw disable
sudo systemctl disable firewalld
```

### 问题4: 网络冲突
如果启动 Tailscale 后无法访问外网，请参考 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 中的网络冲突解决方案。

## 📋 安装检查清单

安装完成后，请确认以下项目：

- [ ] `tailscale version` 显示版本信息
- [ ] `sudo systemctl status tailscaled` 显示 active (running)
- [ ] `tailscale status` 显示已连接的设备
- [ ] `ping 8.8.8.8` 可以正常访问外网
- [ ] 可以 ping 通 Tailscale 网络中的其他设备

## 🔄 更新 Tailscale

### 使用包管理器更新
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade tailscale

# CentOS/RHEL
sudo yum update tailscale

# Fedora
sudo dnf update tailscale
```

### 手动更新
```bash
# 重新运行官方安装脚本
curl -fsSL https://tailscale.com/install.sh | sh
```

## 🗑️ 卸载 Tailscale

### 完全卸载
```bash
# 停止并断开连接
sudo tailscale down
sudo systemctl stop tailscaled
sudo systemctl disable tailscaled

# 卸载软件包（Ubuntu/Debian）
sudo apt remove tailscale

# 删除配置文件
sudo rm -rf /var/lib/tailscale/
sudo rm -f /etc/systemd/system/tailscaled.service.d/*

# 重新加载 systemd
sudo systemctl daemon-reload
```

---

**注意**: 本指南适用于大多数常见的 Linux 发行版。如果遇到特定系统的问题，请参考 [Tailscale 官方文档](https://tailscale.com/kb/) 或提交 Issue。
