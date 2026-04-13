#!/bin/bash

# TikTok 解锁状态检测脚本 v2.0
# 使用方法: bash tiktok_check.sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 初始化状态
HOME_CODE=""
LOGIN_CODE=""
RECOMMEND_CODE=""
UPLOAD_CODE=""

echo ""
echo "=========================================="
echo "     TikTok 解锁状态检测脚本 v2.0"
echo "=========================================="
echo ""

# 1. 首页检测
echo -e "${BLUE}[检测] 首页访问...${NC}"
HOME_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://www.tiktok.com/" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
    --max-time 10 2>/dev/null)
echo -e "   HTTP状态码: $HOME_CODE"

# 2. 登录接口检测
echo -e "${BLUE}[检测] 登录接口...${NC}"
LOGIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://www.tiktok.com/passport/web/account/info/" \
    -H "User-Agent: Mozilla/5.0" \
    -H "Referer: https://www.tiktok.com/" \
    --max-time 10 2>/dev/null)
echo -e "   HTTP状态码: $LOGIN_CODE"

# 3. 推荐接口检测
echo -e "${BLUE}[检测] 推荐接口...${NC}"
RECOMMEND_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://www.tiktok.com/api/recommend/item_list/?aid=1988&count=1" \
    -H "User-Agent: Mozilla/5.0" \
    --max-time 10 2>/dev/null)
echo -e "   HTTP状态码: $RECOMMEND_CODE"

# 4. 上传预检
echo -e "${BLUE}[检测] 发布权限...${NC}"
UPLOAD_RESPONSE=$(curl -s -X POST "https://www.tiktok.com/api/v1/video/upload/init/" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
    -H "Referer: https://www.tiktok.com/" \
    --data-raw '{"type":1,"video_id":"test"}' \
    --max-time 10 2>/dev/null)
UPLOAD_CODE=$(echo "$UPLOAD_RESPONSE" | grep -o '"status_code":[0-9]*' | head -1 | cut -d':' -f2)
if [ -z "$UPLOAD_CODE" ]; then
    UPLOAD_CODE="null"
fi
echo -e "   status_code: $UPLOAD_CODE"

# 5. IP信息（可选）
echo -e "${BLUE}[检测] IP信息...${NC}"
IP_INFO=$(curl -s "https://ipinfo.io" --max-time 5 2>/dev/null)
IP=$(echo "$IP_INFO" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
ORG=$(echo "$IP_INFO" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
if [ -n "$IP" ]; then
    echo -e "   IP: $IP"
    echo -e "   运营商: ${ORG:-未知}"
fi

# ============================================
# 判断逻辑
# ============================================
echo ""
echo "=========================================="
echo -e "${BLUE}           检测结果${NC}"
echo "=========================================="

# 状态变量
STATUS=""
STATUS_ICON=""
STATUS_DESC=""
LEVEL=0

# 按优先级判断
if [ "$LOGIN_CODE" = "200" ]; then
    if [ "$RECOMMEND_CODE" = "200" ]; then
        if [ "$UPLOAD_CODE" = "0" ]; then
            STATUS="完全解锁"
            STATUS_ICON="⭐⭐⭐⭐⭐"
            STATUS_DESC="所有功能正常，可以发布视频"
            LEVEL=5
        else
            STATUS="浏览解锁"
            STATUS_ICON="⭐⭐⭐⭐"
            STATUS_DESC="可以浏览、登录、互动，但不可发布视频"
            LEVEL=4
        fi
    else
        STATUS="互动解锁"
        STATUS_ICON="⭐⭐⭐"
        STATUS_DESC="可以登录互动，但刷视频功能异常"
        LEVEL=3
    fi
elif [ "$HOME_CODE" = "200" ] || [ "$HOME_CODE" = "302" ]; then
    if [ "$RECOMMEND_CODE" = "200" ]; then
        STATUS="基础解锁"
        STATUS_ICON="⭐⭐"
        STATUS_DESC="可以浏览，但登录受限"
        LEVEL=2
    else
        STATUS="受限访问"
        STATUS_ICON="⭐"
        STATUS_DESC="只能打开首页或验证页面"
        LEVEL=1
    fi
else
    STATUS="完全屏蔽"
    STATUS_ICON="❌"
    STATUS_DESC="无法访问TikTok，需要更换IP"
    LEVEL=0
fi

# 输出结果
echo ""
echo -e "   ${GREEN}状态: ${STATUS} ${STATUS_ICON}${NC}"
echo -e "   ${GREEN}说明: ${STATUS_DESC}${NC}"

# 详细功能列表
echo ""
echo -e "${BLUE}功能可用性:${NC}"
case $LEVEL in
    5)
        echo -e "   ${GREEN}✅ 浏览视频${NC}"
        echo -e "   ${GREEN}✅ 登录账号${NC}"
        echo -e "   ${GREEN}✅ 点赞/评论/关注${NC}"
        echo -e "   ${GREEN}✅ 发布视频${NC}"
        echo -e "   ${GREEN}✅ 所有核心功能${NC}"
        ;;
    4)
        echo -e "   ${GREEN}✅ 浏览视频${NC}"
        echo -e "   ${GREEN}✅ 登录账号${NC}"
        echo -e "   ${GREEN}✅ 点赞/评论/关注${NC}"
        echo -e "   ${RED}❌ 发布视频${NC}"
        ;;
    3)
        echo -e "   ${GREEN}✅ 登录账号${NC}"
        echo -e "   ${RED}❌ 浏览视频${NC}"
        echo -e "   ${YELLOW}⚠️ 其他功能可能异常${NC}"
        ;;
    2)
        echo -e "   ${GREEN}✅ 浏览视频${NC}"
        echo -e "   ${RED}❌ 登录账号${NC}"
        echo -e "   ${RED}❌ 互动功能${NC}"
        ;;
    1)
        echo -e "   ${YELLOW}⚠️ 仅能打开首页${NC}"
        echo -e "   ${RED}❌ 其他功能不可用${NC}"
        ;;
    0)
        echo -e "   ${RED}❌ 所有功能不可用${NC}"
        ;;
esac

# 判断依据
echo ""
echo -e "${BLUE}判断依据:${NC}"
echo -e "   首页: $HOME_CODE | 登录: $LOGIN_CODE | 推荐: $RECOMMEND_CODE | 发布: $UPLOAD_CODE"

# IP类型提示
if [ -n "$ORG" ]; then
    if echo "$ORG" | grep -qi "hosting\|cloud\|datacenter\|vps\|digitalocean\|vultr\|aws\|azure\|gcp\|netlab"; then
        echo ""
        echo -e "${YELLOW}⚠️ 提示: 当前IP为数据中心IP，虽然当前可用，但仍有被风控的风险${NC}"
    fi
fi

echo ""
echo "=========================================="
echo "检测完成: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""
