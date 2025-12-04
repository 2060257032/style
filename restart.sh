#!/bin/bash

# 云测试平台重启脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[INFO]${NC} 重启云测试平台服务..."
echo ""

# 1. 先停止服务
echo -e "${YELLOW}[STEP 1/3]${NC} 停止当前服务..."
./stop.sh > /dev/null 2>&1
echo -e "${GREEN}[DONE]${NC} 服务已停止"
echo ""

# 2. 等待一下
echo -e "${YELLOW}[STEP 2/3]${NC} 等待清理..."
sleep 3
echo -e "${GREEN}[DONE]${NC} 等待完成"
echo ""

# 3. 重新部署
echo -e "${YELLOW}[STEP 3/3]${NC} 重新部署服务..."
./deploy.sh
