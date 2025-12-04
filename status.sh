
#!/bin/bash

# 云测试平台状态检查脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# 显示横幅
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║           云测试平台 - 系统状态监控                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# 获取当前时间
CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo -e "${BLUE}🕒 检查时间: ${NC}$CURRENT_TIME"
echo ""

# 1. 系统信息
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}📊 系统信息${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "主机名: $(hostname)"
echo -e "系统: $(lsb_release -d | cut -f2)"
echo -e "内核: $(uname -r)"
echo -e "运行时间: $(uptime -p | sed 's/up //')"
echo ""

# 2. 资源使用
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}💾 资源使用${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# CPU使用率
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
echo -e "CPU使用率: ${CPU_USAGE}%"

# 内存使用
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
MEM_FREE=$(free -h | awk '/^Mem:/ {print $4}')
MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100}')
echo -e "内存: ${MEM_USED}/${MEM_TOTAL} (使用率: ${MEM_PERCENT}%)"

# 磁盘使用
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
echo -e "磁盘: 使用 ${DISK_USAGE}, 可用 ${DISK_AVAIL}"
echo ""

# 3. 服务状态
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}🛠️  服务状态${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Redis状态
if systemctl is-active --quiet redis; then
    REDIS_STATUS="${GREEN}✅ 运行中${NC}"
    REDIS_UPTIME=$(systemctl status redis | grep "Active:" | cut -d';' -f2 | xargs)
else
    REDIS_STATUS="${RED}❌ 未运行${NC}"
    REDIS_UPTIME="N/A"
fi
echo -e "Redis服务: $REDIS_STATUS ($REDIS_UPTIME)"

# Flask应用状态
if [ -f "../tmp/app.pid" ]; then
    APP_PID=$(cat ../tmp/app.pid)
    if ps -p $APP_PID > /dev/null; then
        APP_UPTIME=$(ps -p $APP_PID -o etime= | xargs)
        APP_STATUS="${GREEN}✅ 运行中${NC} (PID: $APP_PID, 运行: $APP_UPTIME)"
    else
        APP_STATUS="${RED}❌ 进程不存在${NC}"
    fi
else
    if pgrep -f "python3.*app.py" > /dev/null; then
        APP_PID=$(pgrep -f "python3.*app.py")
        APP_UPTIME=$(ps -p $APP_PID -o etime= | xargs)
        APP_STATUS="${YELLOW}🟡 运行中(无PID文件)${NC} (PID: $APP_PID)"
    else
        APP_STATUS="${RED}❌ 未运行${NC}"
    fi
fi
echo -e "Flask应用: $APP_STATUS"

# 端口监听
echo -e "端口监听:"
if netstat -tulpn | grep -q ":5000"; then
    echo -e "  ${GREEN}✅ 5000端口${NC} - Flask应用"
else
    echo -e "  ${RED}❌ 5000端口${NC} - 未监听"
fi

if netstat -tulpn | grep -q ":6379"; then
    echo -e "  ${GREEN}✅ 6379端口${NC} - Redis服务"
else
    echo -e "  ${RED}❌ 6379端口${NC} - 未监听"
fi
echo ""

# 4. 应用健康检查
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}🏥 应用健康${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if curl -s --max-time 5 http://localhost:5000/health > /dev/null; then
    HEALTH_JSON=$(curl -s http://localhost:5000/health)
    STATUS=$(echo $HEALTH_JSON | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    TIMESTAMP=$(echo $HEALTH_JSON | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$STATUS" = "healthy" ]; then
        echo -e "健康状态: ${GREEN}✅ $STATUS${NC}"
    else
        echo -e "健康状态: ${RED}❌ $STATUS${NC}"
    fi
    echo -e "检查时间: $TIMESTAMP"
    
    # 获取访问计数
    if curl -s http://localhost:5000/api/visitors > /dev/null; then
        COUNT_JSON=$(curl -s http://localhost:5000/api/visitors)
        COUNT=$(echo $COUNT_JSON | grep -o '"visitor_count":[0-9]*' | cut -d':' -f2)
        echo -e "访问计数: ${CYAN}$COUNT${NC} 次"
    fi
else
    echo -e "健康状态: ${RED}❌ 无法连接${NC}"
    echo -e "错误: 应用可能未运行或网络问题"
fi
echo ""

# 5. 日志信息
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}📝 日志信息${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -f "../logs/app.log" ]; then
    LOG_SIZE=$(du -h ../logs/app.log | cut -f1)
    LOG_LINES=$(wc -l < ../logs/app.log)
    LOG_LAST=$(tail -1 ../logs/app.log)
    
    echo -e "应用日志: ${LOG_LINES} 行, 大小: ${LOG_SIZE}"
    echo -e "最后日志: ${YELLOW}$LOG_LAST${NC}"
else
    echo -e "应用日志: ${RED}日志文件不存在${NC}"
fi

if [ -f "/var/log/redis/redis-server.log" ]; then
    REDIS_LOG_SIZE=$(sudo du -h /var/log/redis/redis-server.log | cut -f1)
    echo -e "Redis日志: 大小: ${REDIS_LOG_SIZE}"
fi
echo ""

# 6. 总结与建议
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}💡 总结建议${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 检查问题
PROBLEMS=0

# 检查应用是否运行
if ! pgrep -f "python3.*app.py" > /dev/null; then
    echo -e "${RED}⚠️  问题: Flask应用未运行${NC}"
    echo -e "   建议: 运行 ./scripts/deploy.sh 启动应用"
    PROBLEMS=$((PROBLEMS+1))
fi

# 检查Redis是否运行
if ! systemctl is-active --quiet redis; then
    echo -e "${RED}⚠️  问题: Redis服务未运行${NC}"
    echo -e "   建议: 运行 sudo systemctl start redis"
    PROBLEMS=$((PROBLEMS+1))
fi

# 检查端口是否监听
if ! netstat -tulpn | grep -q ":5000"; then
    echo -e "${RED}⚠️  问题: 5000端口未监听${NC}"
    echo -e "   建议: 检查应用配置或重启应用"
    PROBLEMS=$((PROBLEMS+1))
fi

# 检查磁盘空间
DISK_PERCENT=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_PERCENT -gt 80 ]; then
    echo -e "${YELLOW}⚠️  警告: 磁盘空间不足 (${DISK_PERCENT}%)${NC}"
    echo -e "   建议: 清理日志文件或扩展磁盘"
    PROBLEMS=$((PROBLEMS+1))
fi

if [ $PROBLEMS -eq 0 ]; then
    echo -e "${GREEN}✅ 所有系统正常，无发现问题${NC}"
else
    echo -e "${YELLOW}📋 发现 ${PROBLEMS} 个问题，请根据建议处理${NC}"
fi

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}              状态检查完成！                         ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}🔄 刷新: ${NC}10秒后自动刷新 (按 Ctrl+C 退出)"
echo -e "${BLUE}📁 日志: ${NC}tail -f ../logs/app.log"
echo -e "${BLUE}🚀 管理: ${NC}./scripts/deploy.sh | stop.sh | restart.sh"
