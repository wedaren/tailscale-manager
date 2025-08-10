#!/bin/bash

# Tailscale 开机自启配置脚本
# 配置 Tailscale 在系统启动时自动连接网络

echo "🚀 Tailscale 开机自启配置工具"
echo "=============================="
echo

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ 此脚本需要 root 权限运行${NC}"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检查 Tailscale 是否已安装
check_tailscale() {
    echo -e "${BLUE}📦 检查 Tailscale 安装状态...${NC}"
    
    if ! command -v tailscale &> /dev/null; then
        echo -e "${RED}❌ Tailscale 未安装${NC}"
        echo "请先安装 Tailscale: curl -fsSL https://tailscale.com/install.sh | sh"
        exit 1
    fi
    
    # 检查 tailscaled 服务
    if ! systemctl is-enabled --quiet tailscaled; then
        echo -e "${YELLOW}⚠️  启用 tailscaled 开机自启...${NC}"
        systemctl enable tailscaled
    fi
    
    echo -e "${GREEN}✅ Tailscale 安装检查完成${NC}"
    echo
}

# 检测云服务商并设置合适的参数
detect_cloud_and_set_params() {
    echo -e "${BLUE}☁️  检测云服务商环境...${NC}"
    
    TAILSCALE_PARAMS="--accept-routes=false"
    
    # 检测阿里云
    if curl -s --max-time 3 http://100.100.100.200/latest/meta-data/ &>/dev/null; then
        echo -e "${YELLOW}检测到阿里云环境${NC}"
        TAILSCALE_PARAMS="--netfilter-mode=off --accept-dns=false --accept-routes=false"
        CLOUD_TYPE="aliyun"
    # 检测腾讯云
    elif curl -s --max-time 3 http://metadata.tencentcloudapi.com/latest/ &>/dev/null; then
        echo -e "${YELLOW}检测到腾讯云环境${NC}"
        TAILSCALE_PARAMS="--netfilter-mode=off --accept-dns=false --accept-routes=false"
        CLOUD_TYPE="tencent"
    # 检测 AWS
    elif curl -s --max-time 3 http://169.254.169.254/latest/meta-data/ &>/dev/null; then
        echo -e "${YELLOW}检测到 AWS 环境${NC}"
        TAILSCALE_PARAMS="--accept-routes=false"
        CLOUD_TYPE="aws"
    else
        echo "本地或未识别的环境"
        CLOUD_TYPE="generic"
    fi
    
    echo "将使用参数: $TAILSCALE_PARAMS"
    echo
}

# 创建 systemd 服务文件
create_systemd_service() {
    echo -e "${BLUE}📝 创建 systemd 服务文件...${NC}"
    
    SERVICE_FILE="/etc/systemd/system/tailscale-auto-connect.service"
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Tailscale Auto Connect
After=tailscaled.service
Wants=tailscaled.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/tailscale up $TAILSCALE_PARAMS
ExecStop=/usr/bin/tailscale down

[Install]
WantedBy=multi-user.target
EOF
    
    echo -e "${GREEN}✅ 服务文件已创建: $SERVICE_FILE${NC}"
}

# 启用并启动服务
enable_service() {
    echo -e "${BLUE}⚙️  配置服务...${NC}"
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable tailscale-auto-connect.service
    
    # 启动服务进行测试
    if systemctl start tailscale-auto-connect.service; then
        echo -e "${GREEN}✅ 服务启动成功${NC}"
    else
        echo -e "${RED}❌ 服务启动失败${NC}"
        systemctl status tailscale-auto-connect.service --no-pager -l
        exit 1
    fi
}

# 验证配置
verify_setup() {
    echo -e "${BLUE}🔍 验证配置...${NC}"
    
    # 检查服务状态
    if systemctl is-enabled --quiet tailscale-auto-connect.service; then
        echo -e "${GREEN}✅ 开机自启已启用${NC}"
    else
        echo -e "${RED}❌ 开机自启配置失败${NC}"
        exit 1
    fi
    
    # 检查 Tailscale 连接状态
    if tailscale status &>/dev/null; then
        echo -e "${GREEN}✅ Tailscale 网络连接正常${NC}"
        MY_IP=$(tailscale ip 2>/dev/null)
        echo "本机 Tailscale IP: $MY_IP"
    else
        echo -e "${YELLOW}⚠️  Tailscale 未连接${NC}"
    fi
    
    # 测试外网连接
    if ping -c 3 8.8.8.8 &>/dev/null; then
        echo -e "${GREEN}✅ 外网连接正常${NC}"
    else
        echo -e "${RED}❌ 外网连接异常${NC}"
    fi
    echo
}

# 显示完成信息和管理命令
show_completion_info() {
    echo -e "${GREEN}🎉 Tailscale 开机自启配置完成！${NC}"
    echo "=================================="
    echo
    echo -e "${BLUE}📋 配置信息:${NC}"
    echo "云服务商: $CLOUD_TYPE"
    echo "启动参数: $TAILSCALE_PARAMS"
    echo "服务文件: /etc/systemd/system/tailscale-auto-connect.service"
    echo
    echo -e "${BLUE}🔧 管理命令:${NC}"
    echo "查看服务状态: sudo systemctl status tailscale-auto-connect"
    echo "重启服务:     sudo systemctl restart tailscale-auto-connect"
    echo "停用自启:     sudo systemctl disable tailscale-auto-connect"
    echo "删除服务:     sudo systemctl disable tailscale-auto-connect && sudo rm /etc/systemd/system/tailscale-auto-connect.service"
    echo
    echo -e "${BLUE}📊 验证命令:${NC}"
    echo "检查状态:     tailscale status"
    echo "测试网络:     ping 8.8.8.8"
    echo
    echo -e "${YELLOW}💡 提示: 系统重启后，Tailscale 将自动连接网络${NC}"
}

# 提供卸载选项
show_uninstall_option() {
    echo -e "${BLUE}🗑️  如需卸载开机自启:${NC}"
    echo "sudo systemctl disable tailscale-auto-connect"
    echo "sudo systemctl stop tailscale-auto-connect"
    echo "sudo rm /etc/systemd/system/tailscale-auto-connect.service"
    echo "sudo systemctl daemon-reload"
}

# 主函数
main() {
    check_root
    check_tailscale
    detect_cloud_and_set_params
    create_systemd_service
    enable_service
    verify_setup
    show_completion_info
    show_uninstall_option
}

# 运行主函数
main "$@"
