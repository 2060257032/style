#!/bin/bash

# 云测试平台停止脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[INFO]${NC} 停止云测试平台服务..."

# 1. 停止Flask应用
echo -e "${YELLOW}[ACTION]${NC} 停止Flask应用..."
if [ -f "../tmp/app.pid" ]; then
    APP_PID=$(cat ../tmp/app.pid)
    if ps -p $APP_PID > /dev/null; then
        kill $APP_PID
        echo -e "${GREEN}[SUCCESS]${NC} 应用已停止 (PID: $APP_PID)"
        rm -f ../tmp/app.pid
    else
        echo -e "${YELLOW}[WARNING]${NC} 应用进程不存在，清理PID文件"
        rm -f ../tmp/app.pid
    fi
else
    echo -e "${YELLOW}[WARNING]${NC} 未找到PID文件，尝试查找进程..."
    pkill -f "python3.*app.py" && echo -e "${GREEN}[SUCCESS]${NC} 应用已停止" || echo -e "${YELLOW}[WARNING]${NC} 未找到运行中的应用"
fi

# 2. 检查是否完全停止
echo -e "${YELLOW}[ACTION]${NC} 检查应用是否完全停止..."
sleep 2
if pgrep -f "python3.*app.py" > /dev/null; then
    echo -e "${RED}[ERROR]${NC} 应用仍在运行，强制停止..."
    pkill -9 -f "python3.*app.py"
    sleep 1
fi

# 3. 停止Redis服务（可选）
echo -e "${BLUE}[QUESTION]${NC} 是否停止Redis服务？ (y/N): "
read -r stop_redis
if [[ "$stop_redis" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[ACTION]${NC} 停止Redis服务..."
    sudo systemctl stop redis
    echo -e "${GREEN}[SUCCESS]${NC} Redis服务已停止"
fi

# 4. 显示停止结果
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}            🛑 服务停止完成！ 🛑                   ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📊 当前状态：${NC}"
echo "   Flask应用: $(if pgrep -f "python3.*app.py" > /dev/null; then echo "❌ 仍在运行"; else echo "✅ 已停止"; fi)"
echo "   Redis服务: $(systemctl is-active redis 2>/dev/null && echo "✅ 运行中" || echo "🟡 已停止")"
echo ""
echo -e "${YELLOW}💡 提示：使用 ./scripts/deploy.sh 重新启动服务${NC}"
