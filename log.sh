
#!/bin/bash

# 云测试平台日志查看脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║           云测试平台 - 日志查看工具                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

echo -e "${BLUE}📝 可用日志文件:${NC}"
echo "  1. 应用日志 (app.log)"
echo "  2. Redis日志 (redis-server.log)"
echo "  3. 部署日志 (deploy.log)"
echo "  4. 系统日志 (syslog)"
echo ""
echo -e "${YELLOW}请选择要查看的日志 (输入数字 1-4):${NC} "
read -r choice

case $choice in
    1)
        echo -e "${GREEN}正在显示应用日志...${NC}"
        echo -e "${YELLOW}------------------------------------------------${NC}"
        if [ -f "../logs/app.log" ]; then
            tail -50 ../logs/app.log
        else
            echo -e "${RED}应用日志文件不存在${NC}"
            echo "可能是首次运行，或者日志路径不正确"
        fi
        ;;
    2)
        echo -e "${GREEN}正在显示Redis日志...${NC}"
        echo -e "${YELLOW}------------------------------------------------${NC}"
        if [ -f "/var/log/redis/redis-server.log" ]; then
            sudo tail -30 /var/log/redis/redis-server.log
        else
            echo -e "${RED}Redis日志文件不存在${NC}"
            echo "请检查Redis服务是否安装"
        fi
        ;;
    3)
        echo -e "${GREEN}正在显示部署日志...${NC}"
        echo -e "${YELLOW}------------------------------------------------${NC}"
        if [ -f "../logs/deploy.log" ]; then
            tail -30 ../logs/deploy.log
        else
            echo "暂无部署日志"
        fi
        ;;
    4)
        echo -e "${GREEN}正在显示系统日志...${NC}"
        echo -e "${YELLOW}------------------------------------------------${NC}"
        sudo tail -20 /var/log/syslog | grep -E "(redis|python|flask)"
        ;;
    *)
        echo -e "${RED}无效的选择${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}------------------------------------------------${NC}"
echo -e "${BLUE}日志查看选项:${NC}"
echo "  实时查看: tail -f [日志文件]"
echo "  查看全部: cat [日志文件]"
echo "  搜索错误: grep -i error [日志文件]"
echo ""
echo -e "${GREEN}当前查看:${NC}"
case $choice in
    1) echo "  应用日志: $(realpath ../logs/app.log 2>/dev/null || echo "不存在")" ;;
    2) echo "  Redis日志: /var/log/redis/redis-server.log" ;;
    3) echo "  部署日志: $(realpath ../logs/deploy.log 2>/dev/null || echo "不存在")" ;;
    4) echo "  系统日志: /var/log/syslog (相关部分)" ;;
esac
