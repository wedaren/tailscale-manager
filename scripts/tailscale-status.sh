#!/bin/bash

# Tailscale 状态检查脚本
# 提供全面的 Tailscale 状态信息

echo "📊 Tailscale 状态检查工具"
echo "========================"
echo

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查 Tailscale 基本状态
check_basic_status() {
    echo -e "${BLUE}📦 Tailscale 基本信息${NC}"
    echo "------------------------"
    
    # 版本信息
    if command -v tailscale &> /dev/null; then
        VERSION=$(tailscale version 2>/dev/null | head -1)
        echo "版本: $VERSION"
    else
        echo -e "${RED}❌ Tailscale 未安装${NC}"
        return 1
    fi
    
    # 服务状态
    if systemctl is-active --quiet tailscaled; then
        echo -e "服务状态: ${GREEN}运行中${NC}"
    else
        echo -e "服务状态: ${RED}已停止${NC}"
    fi
    
    # 开机自启状态
    if systemctl is-enabled --quiet tailscaled; then
        echo -e "开机自启: ${GREEN}已启用${NC}"
    else
        echo -e "开机自启: ${YELLOW}未启用${NC}"
    fi
    echo
}

# 检查网络状态
check_network_status() {
    echo -e "${BLUE}🌐 网络状态${NC}"
    echo "------------------------"
    
    # Tailscale 连接状态
    STATUS_OUTPUT=$(tailscale status 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo -e "连接状态: ${GREEN}已连接${NC}"
        
        # 获取本机 IP
        MY_IP=$(tailscale ip 2>/dev/null)
        if [[ ! -z "$MY_IP" ]]; then
            echo "本机 Tailscale IP: $MY_IP"
        fi
        
        # 统计在线设备数
        ONLINE_COUNT=$(echo "$STATUS_OUTPUT" | grep -v "offline" | grep -c "100\.")
        TOTAL_COUNT=$(echo "$STATUS_OUTPUT" | grep -c "100\.")
        echo "设备统计: $ONLINE_COUNT/$TOTAL_COUNT 在线"
        
    else
        echo -e "连接状态: ${RED}未连接${NC}"
    fi
    echo
}

# 显示设备列表
show_device_list() {
    echo -e "${BLUE}📱 设备列表${NC}"
    echo "------------------------"
    
    STATUS_OUTPUT=$(tailscale status 2>/dev/null)
    if [[ $? -eq 0 ]] && [[ ! -z "$STATUS_OUTPUT" ]]; then
        echo "$STATUS_OUTPUT" | while IFS= read -r line; do
            if [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
                IP=$(echo $line | awk '{print $1}')
                NAME=$(echo $line | awk '{print $2}')
                STATUS=$(echo $line | grep -o "offline\|idle" || echo "active")
                
                case $STATUS in
                    "offline")
                        echo -e "  ${RED}🔴${NC} $NAME ($IP) - 离线"
                        ;;
                    "idle")
                        echo -e "  ${YELLOW}🟡${NC} $NAME ($IP) - 空闲"
                        ;;
                    *)
                        echo -e "  ${GREEN}🟢${NC} $NAME ($IP) - 在线"
                        ;;
                esac
            fi
        done
    else
        echo -e "${YELLOW}⚠️  无法获取设备列表${NC}"
    fi
    echo
}

# 网络质量检查
check_network_quality() {
    echo -e "${BLUE}🔍 网络质量检查${NC}"
    echo "------------------------"
    
    # DERP 服务器连接检查
    echo "DERP 服务器连接检查:"
    if command -v tailscale netcheck &>/dev/null; then
        tailscale netcheck 2>/dev/null | grep -E "(DERP|latency)" | head -5
    else
        echo "  使用 'tailscale netcheck' 命令查看详细信息"
    fi
    echo
    
    # 测试到其他节点的连接
    echo "节点连通性测试:"
    STATUS_OUTPUT=$(tailscale status 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        # 获取第一个在线设备进行测试
        FIRST_ONLINE=$(echo "$STATUS_OUTPUT" | grep -v "offline" | grep "100\." | head -1 | awk '{print $2}')
        if [[ ! -z "$FIRST_ONLINE" ]] && [[ "$FIRST_ONLINE" != "$(hostname)" ]]; then
            if tailscale ping "$FIRST_ONLINE" --timeout=5s &>/dev/null; then
                echo -e "  ${GREEN}✅${NC} 到 $FIRST_ONLINE 的连接正常"
            else
                echo -e "  ${YELLOW}⚠️${NC} 到 $FIRST_ONLINE 的连接可能有问题"
            fi
        else
            echo "  没有其他在线设备可测试"
        fi
    fi
    echo
}

# 检查外网连接
check_external_connectivity() {
    echo -e "${BLUE}🌍 外网连接检查${NC}"
    echo "------------------------"
    
    # 测试基本连接
    if ping -c 2 8.8.8.8 &>/dev/null; then
        echo -e "${GREEN}✅${NC} 外网 IP 连通 (8.8.8.8)"
    else
        echo -e "${RED}❌${NC} 外网 IP 不通 (8.8.8.8)"
    fi
    
    if ping -c 2 google.com &>/dev/null; then
        echo -e "${GREEN}✅${NC} DNS 解析正常 (google.com)"
    else
        echo -e "${RED}❌${NC} DNS 解析失败 (google.com)"
    fi
    
    # HTTP 连接测试
    if curl -s --max-time 5 -o /dev/null http://httpbin.org/ip; then
        echo -e "${GREEN}✅${NC} HTTP 连接正常"
    else
        echo -e "${YELLOW}⚠️${NC} HTTP 连接可能有问题"
    fi
    echo
}

# 检查配置信息
check_configuration() {
    echo -e "${BLUE}⚙️  配置信息${NC}"
    echo "------------------------"
    
    # 显示当前启动参数（从进程信息推断）
    TAILSCALE_PREFS="/var/lib/tailscale/tailscaled.state"
    if [[ -f "$TAILSCALE_PREFS" ]]; then
        echo "配置文件: $TAILSCALE_PREFS"
    fi
    
    # 检查是否使用了特殊参数
    if pgrep -f "netfilter-mode=off" &>/dev/null; then
        echo -e "${GREEN}✅${NC} 使用了 netfilter-mode=off"
    fi
    
    if pgrep -f "accept-dns=false" &>/dev/null; then
        echo -e "${GREEN}✅${NC} 使用了 accept-dns=false"
    fi
    echo
}

# 显示有用的命令
show_useful_commands() {
    echo -e "${BLUE}🔧 常用命令${NC}"
    echo "------------------------"
    echo "基本操作:"
    echo "  tailscale status              - 查看状态"
    echo "  tailscale ip                  - 查看本机 IP"
    echo "  tailscale ping <device>       - 测试连接"
    echo "  tailscale netcheck            - 网络诊断"
    echo
    echo "管理操作:"
    echo "  sudo tailscale up             - 连接网络"
    echo "  sudo tailscale down           - 断开连接"
    echo "  sudo systemctl restart tailscaled  - 重启服务"
    echo
    echo "日志查看:"
    echo "  sudo journalctl -u tailscaled -f     - 查看实时日志"
    echo "  sudo journalctl -u tailscaled --since '1 hour ago'  - 查看历史日志"
    echo
}

# 主函数
main() {
    check_basic_status
    check_network_status
    show_device_list
    check_network_quality
    check_external_connectivity
    check_configuration
    show_useful_commands
    
    echo -e "${GREEN}📊 状态检查完成！${NC}"
}

# 运行主函数
main "$@"
