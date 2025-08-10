#!/bin/bash

# Tailscale 网络冲突检查脚本
# 用于检测可能与 Tailscale 冲突的网络配置

echo "🔍 Tailscale 网络冲突检查工具"
echo "================================"
echo

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否为 root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  警告: 正在以 root 用户运行${NC}"
    fi
}

# 检查 Tailscale 安装状态
check_tailscale_installation() {
    echo -e "${BLUE}📦 检查 Tailscale 安装状态...${NC}"
    
    if command -v tailscale &> /dev/null; then
        TAILSCALE_VERSION=$(tailscale version 2>/dev/null | head -1)
        echo -e "${GREEN}✅ Tailscale 已安装: $TAILSCALE_VERSION${NC}"
        
        # 检查服务状态
        if systemctl is-active --quiet tailscaled; then
            echo -e "${GREEN}✅ tailscaled 服务正在运行${NC}"
        else
            echo -e "${YELLOW}⚠️  tailscaled 服务未运行${NC}"
            echo "   启动命令: sudo systemctl start tailscaled"
        fi
        
        # 检查连接状态
        TAILSCALE_STATUS=$(tailscale status 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Tailscale 已连接${NC}"
        else
            echo -e "${YELLOW}⚠️  Tailscale 未连接或未登录${NC}"
        fi
    else
        echo -e "${RED}❌ Tailscale 未安装${NC}"
        echo "   安装命令: curl -fsSL https://tailscale.com/install.sh | sh"
        exit 1
    fi
    echo
}

# 检查系统信息
check_system_info() {
    echo -e "${BLUE}🖥️  系统信息...${NC}"
    
    # 操作系统信息
    if [[ -f /etc/os-release ]]; then
        OS_INFO=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
        echo "系统: $OS_INFO"
    fi
    
    # 云服务商检测
    detect_cloud_provider
    echo
}

# 检测云服务商
detect_cloud_provider() {
    # 检测阿里云
    if curl -s --max-time 3 http://100.100.100.200/latest/meta-data/ &>/dev/null; then
        echo -e "${YELLOW}☁️  检测到阿里云环境${NC}"
        CLOUD_PROVIDER="aliyun"
    # 检测腾讯云
    elif curl -s --max-time 3 http://metadata.tencentcloudapi.com/latest/ &>/dev/null; then
        echo -e "${YELLOW}☁️  检测到腾讯云环境${NC}"
        CLOUD_PROVIDER="tencent"
    # 检测 AWS
    elif curl -s --max-time 3 http://169.254.169.254/latest/meta-data/ &>/dev/null; then
        echo -e "${YELLOW}☁️  检测到 AWS 环境${NC}"
        CLOUD_PROVIDER="aws"
    # 检测 Google Cloud
    elif curl -s --max-time 3 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/ &>/dev/null; then
        echo -e "${YELLOW}☁️  检测到 Google Cloud 环境${NC}"
        CLOUD_PROVIDER="gcp"
    else
        echo "☁️  云服务商: 未检测到或本地环境"
        CLOUD_PROVIDER="unknown"
    fi
}

# 检查网络接口
check_network_interfaces() {
    echo -e "${BLUE}🌐 网络接口检查...${NC}"
    
    # 显示所有网络接口
    echo "活跃的网络接口:"
    ip addr show | grep -E '^[0-9]+:' | awk '{print $2}' | sed 's/://' | while read interface; do
        IP_INFO=$(ip addr show $interface | grep 'inet ' | awk '{print $2}' | head -1)
        if [[ ! -z "$IP_INFO" ]]; then
            echo "  $interface: $IP_INFO"
        fi
    done
    
    # 检查 Tailscale 接口
    if ip addr show tailscale0 &>/dev/null; then
        TAILSCALE_IP=$(ip addr show tailscale0 | grep 'inet ' | awk '{print $2}')
        echo -e "${GREEN}✅ Tailscale 接口: tailscale0 ($TAILSCALE_IP)${NC}"
    else
        echo -e "${YELLOW}⚠️  Tailscale 接口不存在${NC}"
    fi
    echo
}

# 检查路由表冲突
check_routing_conflicts() {
    echo -e "${BLUE}🛣️  路由表冲突检查...${NC}"
    
    # 显示当前路由表
    echo "当前路由表:"
    ip route show | head -10
    echo
    
    # 检查 100.x.x.x 网段路由
    CONFLICT_ROUTES=$(ip route show | grep '^100\.')
    if [[ ! -z "$CONFLICT_ROUTES" ]]; then
        echo -e "${RED}❌ 发现潜在的路由冲突:${NC}"
        echo "$CONFLICT_ROUTES" | while read route; do
            echo "  $route"
        done
        echo
        
        # 特定云服务商的解决建议
        case $CLOUD_PROVIDER in
            "aliyun")
                echo -e "${YELLOW}💡 阿里云解决建议:${NC}"
                echo "   这些是阿里云内部 DNS 服务器路由，请勿删除！"
                echo "   建议启动方案: sudo tailscale up --netfilter-mode=off --accept-dns=false"
                ;;
            "tencent")
                echo -e "${YELLOW}💡 腾讯云解决建议:${NC}"
                echo "   建议启动方案: sudo tailscale up --netfilter-mode=off --accept-dns=false"
                ;;
            *)
                echo -e "${YELLOW}💡 通用解决建议:${NC}"
                echo "   检查这些路由是否为重要系统服务"
                echo "   建议启动方案: sudo tailscale up --netfilter-mode=off --accept-dns=false"
                ;;
        esac
        return 1
    else
        echo -e "${GREEN}✅ 未发现 100.x.x.x 网段路由冲突${NC}"
        return 0
    fi
    echo
}

# 检查 DNS 配置
check_dns_configuration() {
    echo -e "${BLUE}🔍 DNS 配置检查...${NC}"
    
    # 检查 /etc/resolv.conf
    if [[ -f /etc/resolv.conf ]]; then
        echo "当前 DNS 配置 (/etc/resolv.conf):"
        cat /etc/resolv.conf | grep -v '^#' | grep -v '^$'
        echo
    fi
    
    # 检查 systemd-resolved
    if command -v resolvectl &>/dev/null; then
        echo "systemd-resolved 状态:"
        resolvectl status | grep -E "(DNS Servers|Current DNS Server)" | head -5
        
        # 检查是否使用了 100.x.x.x DNS
        DNS_100_CONFLICT=$(resolvectl status | grep -E "DNS Servers.*100\.")
        if [[ ! -z "$DNS_100_CONFLICT" ]]; then
            echo -e "${YELLOW}⚠️  发现 100.x.x.x 网段的 DNS 服务器${NC}"
            echo "$DNS_100_CONFLICT"
        fi
    fi
    echo
}

# 网络连通性测试
test_connectivity() {
    echo -e "${BLUE}🌍 网络连通性测试...${NC}"
    
    # 测试外网 IP
    if ping -c 3 8.8.8.8 &>/dev/null; then
        echo -e "${GREEN}✅ 外网 IP 连通 (8.8.8.8)${NC}"
    else
        echo -e "${RED}❌ 外网 IP 不通 (8.8.8.8)${NC}"
    fi
    
    # 测试域名解析
    if ping -c 3 google.com &>/dev/null; then
        echo -e "${GREEN}✅ 域名解析正常 (google.com)${NC}"
    else
        echo -e "${RED}❌ 域名解析失败 (google.com)${NC}"
    fi
    
    # 测试 Tailscale 网络
    if tailscale status &>/dev/null; then
        OTHER_NODES=$(tailscale status --json 2>/dev/null | grep -o '"TailscaleIPs":\["[^"]*"' | cut -d'"' -f4 | grep -v "$(tailscale ip)" | head -1)
        if [[ ! -z "$OTHER_NODES" ]]; then
            if ping -c 3 "$OTHER_NODES" &>/dev/null; then
                echo -e "${GREEN}✅ Tailscale 网络连通 ($OTHER_NODES)${NC}"
            else
                echo -e "${YELLOW}⚠️  Tailscale 网络可能有问题 ($OTHER_NODES)${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  没有其他 Tailscale 设备可测试${NC}"
        fi
    fi
    echo
}

# 生成修复建议
generate_recommendations() {
    echo -e "${BLUE}💡 修复建议和下一步操作${NC}"
    echo "================================"
    
    case $CLOUD_PROVIDER in
        "aliyun")
            echo -e "${YELLOW}🌟 阿里云服务器推荐配置:${NC}"
            echo "sudo tailscale up --netfilter-mode=off --accept-dns=false --accept-routes=false"
            ;;
        "tencent"|"aws"|"gcp")
            echo -e "${YELLOW}🌟 云服务器推荐配置:${NC}"
            echo "sudo tailscale up --netfilter-mode=off --accept-dns=false --accept-routes=false"
            ;;
        *)
            echo -e "${YELLOW}🌟 通用推荐配置:${NC}"
            echo "sudo tailscale up --netfilter-mode=off --accept-dns=false"
            ;;
    esac
    
    echo
    echo -e "${GREEN}✅ 参数说明:${NC}"
    echo "  --netfilter-mode=off  : 避免 iptables 规则冲突"
    echo "  --accept-dns=false    : 保持当前 DNS 设置"
    echo "  --accept-routes=false : 不接受路由广播"
    echo
    
    echo -e "${GREEN}🔧 其他有用命令:${NC}"
    echo "  检查状态: tailscale status"
    echo "  重新连接: sudo tailscale down && sudo tailscale up --netfilter-mode=off --accept-dns=false"
    echo "  查看日志: sudo journalctl -u tailscaled -f"
    echo "  网络诊断: tailscale netcheck"
    echo
}

# 主函数
main() {
    check_root
    echo
    check_tailscale_installation
    check_system_info
    check_network_interfaces
    check_routing_conflicts
    ROUTING_CONFLICT=$?
    check_dns_configuration
    test_connectivity
    generate_recommendations
    
    if [[ $ROUTING_CONFLICT -eq 1 ]]; then
        echo -e "${RED}⚠️  检测到路由冲突，建议使用推荐的启动参数${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ 网络配置检查完成，未发现严重冲突${NC}"
        exit 0
    fi
}

# 运行主函数
main "$@"
