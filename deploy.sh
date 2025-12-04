
#!/bin/bash

# ============================================
# 云测试平台部署脚本
# 版本: 1.0.0
# 作者: 奶奶的技术团队
# ============================================

set -e  # 遇到任何错误立即退出脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    exit 1
}

# 显示横幅
show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                                                      ║"
    echo "║      基于KVM与Docker的CI/CD自动化测试平台            ║"
    echo "║                    部署脚本 v1.0                     ║"
    echo "║                                                      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# 检查运行环境
check_environment() {
    log_info "检查运行环境..."
    
    # 检查是否在项目根目录
    if [ ! -f "../app/app.py" ]; then
        log_error "请在项目根目录运行此脚本"
    fi
    
    # 检查用户权限
    if [ "$EUID" -eq 0 ]; then 
        log_warning "检测到使用root权限运行，建议使用普通用户"
    fi
    
    # 检查系统类型
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "操作系统: $NAME $VERSION"
        if [[ "$NAME" != *"Ubuntu"* ]] && [[ "$NAME" != *"Debian"* ]]; then
            log_warning "本脚本主要针对Ubuntu/Debian系统测试"
        fi
    fi
}

# 检查并安装依赖
install_dependencies() {
    log_info "检查系统依赖..."
    
    local missing_packages=()
    
    # 检查Python3
    if ! command -v python3 &> /dev/null; then
        log_warning "Python3 未安装"
        missing_packages+=("python3" "python3-pip" "python3-venv")
    else
        log_info "Python3 版本: $(python3 --version)"
    fi
    
    # 检查pip3
    if ! command -v pip3 &> /dev/null; then
        log_warning "pip3 未安装"
        missing_packages+=("python3-pip")
    else
        log_info "pip3 版本: $(pip3 --version | cut -d' ' -f2)"
    fi
    
    # 检查Redis
    if ! command -v redis-cli &> /dev/null; then
        log_warning "Redis 未安装"
        missing_packages+=("redis-server")
    fi
    
    # 如果有缺失的包，安装它们
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log_info "安装缺失的包: ${missing_packages[*]}"
        
        # 更新包列表
        sudo apt update
        
        # 安装缺失的包
        for pkg in "${missing_packages[@]}"; do
            log_info "安装 $pkg..."
            sudo apt install -y "$pkg"
            if [ $? -eq 0 ]; then
                log_success "$pkg 安装成功"
            else
                log_error "$pkg 安装失败"
            fi
        done
        
        # 清理缓存
        sudo apt autoremove -y
        sudo apt clean
    else
        log_success "所有系统依赖已安装"
    fi
}

# 安装Python依赖
install_python_deps() {
    log_info "安装Python依赖..."
    
    # 检查requirements.txt是否存在
    if [ ! -f "../app/requirements.txt" ]; then
        log_error "requirements.txt 文件不存在"
    fi
    
    # 安装依赖
    log_info "使用pip安装依赖包..."
    pip3 install -r ../app/requirements.txt
    
    if [ $? -eq 0 ]; then
        log_success "Python依赖安装成功"
        
        # 显示安装的包
        log_info "已安装的Python包:"
        pip3 list | grep -E "(Flask|redis|Werkzeug)"
    else
        log_error "Python依赖安装失败"
    fi
}

# 配置Redis
configure_redis() {
    log_info "配置Redis服务..."
    
    # 检查Redis是否运行
    if systemctl is-active --quiet redis; then
        log_success "Redis 服务已在运行"
    else
        log_info "启动Redis服务..."
        sudo systemctl start redis
        sudo systemctl enable redis
        
        # 检查是否启动成功
        sleep 2
        if systemctl is-active --quiet redis; then
            log_success "Redis 服务启动成功"
        else
            log_error "Redis 服务启动失败"
        fi
    fi
    
    # 测试Redis连接
    log_info "测试Redis连接..."
    if redis-cli ping | grep -q "PONG"; then
        log_success "Redis 连接正常"
    else
        log_error "Redis 连接失败"
    fi
    
    # 优化Redis配置（可选）
    log_info "优化Redis配置..."
    sudo sed -i 's/^# maxmemory .*/maxmemory 256mb/' /etc/redis/redis.conf 2>/dev/null || true
    sudo sed -i 's/^# maxmemory-policy .*/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf 2>/dev/null || true
    
    # 重启Redis使配置生效
    sudo systemctl restart redis
    log_success "Redis 配置完成"
}

# 配置应用环境
setup_application() {
    log_info "配置应用环境..."
    
    # 创建必要的目录
    log_info "创建日志和临时目录..."
    mkdir -p ../logs ../tmp
    
    # 设置权限
    chmod 755 ../scripts/*.sh 2>/dev/null || true
    
    # 创建环境变量文件
    log_info "创建环境配置文件..."
    cat > ../.env << 'ENVEOF'
# 云测试平台环境配置
APP_NAME="Cloud Test Platform"
APP_VERSION="1.0.0"
APP_PORT=5000
APP_HOST="0.0.0.0"
APP_DEBUG="true"

# Redis配置
REDIS_HOST="localhost"
REDIS_PORT=6379
REDIS_DB=0

# 日志配置
LOG_LEVEL="INFO"
LOG_FILE="../logs/app.log"

# 性能配置
WORKERS=4
THREADS=2
ENVEOF
    
    log_success "应用环境配置完成"
}

# 启动应用
start_application() {
    log_info "启动应用服务..."
    
    # 检查应用是否已经在运行
    if pgrep -f "python3.*app.py" > /dev/null; then
        log_warning "应用已在运行，先停止..."
        pkill -f "python3.*app.py"
        sleep 2
    fi
    
    # 切换到应用目录
    cd ../app
    
    # 启动应用（后台运行）
    log_info "启动Flask应用..."
    nohup python3 app.py > ../logs/app.log 2>&1 &
    APP_PID=$!
    
    # 保存PID到文件
    echo $APP_PID > ../tmp/app.pid
    
    # 等待应用启动
    log_info "等待应用启动（5秒）..."
    sleep 5
    
    # 检查应用是否成功启动
    if ps -p $APP_PID > /dev/null; then
        log_success "应用启动成功，PID: $APP_PID"
    else
        log_error "应用启动失败，检查日志: ../logs/app.log"
    fi
    
    # 回到脚本目录
    cd ../scripts
}

# 验证部署
verify_deployment() {
    log_info "验证部署结果..."
    
    echo ""
    echo -e "${YELLOW}正在进行部署验证...${NC}"
    echo "=" * 50
    
    # 测试1：检查进程
    log_info "测试1：检查应用进程"
    if [ -f "../tmp/app.pid" ]; then
        APP_PID=$(cat ../tmp/app.pid)
        if ps -p $APP_PID > /dev/null; then
            log_success "✓ 应用进程运行正常 (PID: $APP_PID)"
        else
            log_error "✗ 应用进程不存在"
        fi
    else
        log_error "✗ 未找到PID文件"
    fi
    
    # 测试2：检查端口监听
    log_info "测试2：检查端口监听"
    if netstat -tulpn | grep -q ":5000"; then
        log_success "✓ 端口5000监听正常"
    else
        log_error "✗ 端口5000未监听"
    fi
    
    # 测试3：测试API访问
    log_info "测试3：测试API访问"
    sleep 2
    if curl -s http://localhost:5000/health > /dev/null; then
        log_success "✓ 健康检查API访问正常"
        
        # 获取健康状态
        HEALTH_JSON=$(curl -s http://localhost:5000/health)
        STATUS=$(echo $HEALTH_JSON | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        log_info "健康状态: $STATUS"
    else
        log_error "✗ API访问失败"
    fi
    
    # 测试4：测试首页访问
    log_info "测试4：测试首页访问"
    if curl -s http://localhost:5000/ | grep -q "Hello"; then
        log_success "✓ 首页访问正常"
    else
        log_error "✗ 首页访问失败"
    fi
    
    # 测试5：检查Redis连接
    log_info "测试5：检查Redis连接"
    if redis-cli ping | grep -q "PONG"; then
        log_success "✓ Redis连接正常"
    else
        log_error "✗ Redis连接失败"
    fi
    
    echo "=" * 50
}

# 显示部署结果
show_result() {
    echo ""
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                  🎉 部署成功！ 🎉                   ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    echo -e "${BLUE}📋 部署摘要：${NC}"
    echo "   系统: $(lsb_release -d | cut -f2)"
    echo "   用户: $(whoami)"
    echo "   时间: $(date)"
    echo ""
    
    echo -e "${BLUE}🔗 访问地址：${NC}"
    echo "   首页:      http://localhost:5000"
    echo "   仪表板:    http://localhost:5000/dashboard"
    echo "   API文档:   http://localhost:5000/api/visitors"
    echo "   健康检查:  http://localhost:5000/health"
    echo ""
    
    echo -e "${BLUE}📊 服务状态：${NC}"
    echo "   Flask应用:  $(if pgrep -f "python3.*app.py" > /dev/null; then echo "✅ 运行中"; else echo "❌ 未运行"; fi)"
    echo "   Redis服务:  $(systemctl is-active redis && echo "✅ 运行中" || echo "❌ 未运行")"
    echo "   监听端口:   $(netstat -tulpn | grep -q ":5000" && echo "✅ 5000" || echo "❌ 无")"
    echo ""
    
    echo -e "${BLUE}📁 重要文件：${NC}"
    echo "   应用日志:   $(realpath ../logs/app.log)"
    echo "   配置文件:   $(realpath ../.env)"
    echo "   PID文件:    $(realpath ../tmp/app.pid)"
    echo ""
    
    echo -e "${BLUE}⚡ 管理命令：${NC}"
    echo "   查看日志:   tail -f ../logs/app.log"
    echo "   停止应用:   ./scripts/stop.sh"
    echo "   重启应用:   ./scripts/restart.sh"
    echo "   监控状态:   ./scripts/status.sh"
    echo ""
    
    echo -e "${YELLOW}💡 提示：打开浏览器访问 http://localhost:5000/dashboard 查看仪表板${NC}"
}

# 主函数
main() {
    show_banner
    
    log_info "开始部署云测试平台..."
    
    # 执行部署步骤
    check_environment
    install_dependencies
    install_python_deps
    configure_redis
    setup_application
    start_application
    verify_deployment
    
    # 显示结果
    show_result
}

# 执行主函数
main "$@"
