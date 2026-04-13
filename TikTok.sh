#!/bin/bash

# TikTok IP 环境全面检测脚本 v4.0 (五步法)
# 依赖: curl, dig, whois, bc, jq (可选)

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 临时文件
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo ""
echo "=========================================="
echo "   TikTok IP 环境全面检测 v4.0"
echo "=========================================="
echo ""

# 1. 获取本机公网 IP
MY_IP=$(curl -s ifconfig.me)
echo -e "${BLUE}[1/5] 本机 IP: ${GREEN}$MY_IP${NC}"

# 2. IP 类型检测（使用 ip-api.com 和 ipinfo.io 交叉验证）
echo -e "${BLUE}[2/5] IP 类型与信誉检测...${NC}"
IPAPI_DATA=$(curl -s "http://ip-api.com/json/${MY_IP}?fields=status,message,isp,org,as,proxy,hosting,mobile,query")
if echo "$IPAPI_DATA" | grep -q '"status":"success"'; then
    HOSTING=$(echo "$IPAPI_DATA" | grep -o '"hosting":[^,]*' | cut -d':' -f2 | tr -d ' ')
    PROXY=$(echo "$IPAPI_DATA" | grep -o '"proxy":[^,]*' | cut -d':' -f2 | tr -d ' ')
    ISP=$(echo "$IPAPI_DATA" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4)
    AS=$(echo "$IPAPI_DATA" | grep -o '"as":"[^"]*"' | cut -d'"' -f4)
    echo -e "   ISP: $ISP"
    echo -e "   AS: $AS"
    if [ "$HOSTING" = "true" ]; then
        echo -e "   ${RED}⚠️  ip-api.com 标记为 hosting (数据中心/云)${NC}"
        HOSTING_FLAG=1
    else
        echo -e "   ${GREEN}✅ ip-api.com 标记为非 hosting${NC}"
        HOSTING_FLAG=0
    fi
    if [ "$PROXY" = "true" ]; then
        echo -e "   ${RED}⚠️  标记为 proxy/VPN${NC}"
        PROXY_FLAG=1
    else
        PROXY_FLAG=0
    fi
else
    echo -e "   ${YELLOW}⚠️  ip-api.com 查询失败${NC}"
    HOSTING_FLAG=-1
    PROXY_FLAG=-1
fi

# 补充 ipinfo.io 数据
IPINFO_DATA=$(curl -s "https://ipinfo.io/${MY_IP}/json")
COUNTRY=$(echo "$IPINFO_DATA" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
CITY=$(echo "$IPINFO_DATA" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
TIMEZONE=$(echo "$IPINFO_DATA" | grep -o '"timezone":"[^"]*"' | cut -d'"' -f4)
ORG=$(echo "$IPINFO_DATA" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
echo -e "   国家: $COUNTRY, 城市: $CITY"
echo -e "   时区: $TIMEZONE"
echo -e "   org: $ORG"

# 3. 环境一致性检测（系统时区 vs IP 时区）
echo -e "${BLUE}[3/5] 环境一致性检测...${NC}"
SYS_TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || date +%Z)
if [ -n "$TIMEZONE" ]; then
    if echo "$SYS_TZ" | grep -qiE "$(echo "$TIMEZONE" | sed 's/\/.*//')"; then
        echo -e "   ${GREEN}✅ 系统时区 ($SYS_TZ) 与 IP 时区 ($TIMEZONE) 大致匹配${NC}"
        TZ_MATCH=1
    else
        echo -e "   ${YELLOW}⚠️  系统时区 ($SYS_TZ) 与 IP 时区 ($TIMEZONE) 不匹配，建议调整${NC}"
        TZ_MATCH=0
    fi
else
    TZ_MATCH=-1
fi

# 4. IP 稳定性与黑名单检测
echo -e "${BLUE}[4/5] IP 稳定性与黑名单检测...${NC}"
echo -n "   25 端口状态: "
if timeout 3 nc -zv "$MY_IP" 25 2>&1 | grep -q "open"; then
    echo -e "${RED}开放 (风险较高)${NC}"
    PORT25_OPEN=1
else
    echo -e "${GREEN}关闭 (正常)${NC}"
    PORT25_OPEN=0
fi

# 简单黑名单检测 (spamhaus)
echo -n "   Spamhaus 黑名单: "
REVERSE_IP=$(echo "$MY_IP" | awk -F. '{print $4"."$3"."$2"."$1}')
if dig +short "$REVERSE_IP.zen.spamhaus.org" | grep -q "127.0.0"; then
    echo -e "${RED}被列入 (高风险)${NC}"
    BLACKLISTED=1
else
    echo -e "${GREEN}干净 (正常)${NC}"
    BLACKLISTED=0
fi

# 5. TikTok 接口与页面活跃度测试
echo -e "${BLUE}[5/5] TikTok 接口活跃度测试...${NC}"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
COOKIE_JAR=$(mktemp)

# 访问首页获取 cookie
curl -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" "https://www.tiktok.com/" -H "User-Agent: $UA" >/dev/null

# 测试推荐接口
RECOMMEND=$(curl -s -b "$COOKIE_JAR" "https://www.tiktok.com/api/recommend/item_list/?aid=1988&count=5" -H "User-Agent: $UA" -H "Referer: https://www.tiktok.com/")
VIDEO_COUNT=$(echo "$RECOMMEND" | grep -o '"id":"[0-9]*"' | wc -l)
if [ "$VIDEO_COUNT" -gt 0 ]; then
    echo -e "   ${GREEN}✅ 获取到 $VIDEO_COUNT 个推荐视频${NC}"
    RECOMMEND_OK=1
else
    echo -e "   ${YELLOW}⚠️  未获取到推荐视频${NC}"
    RECOMMEND_OK=0
fi

# 测试页面内容完整性
HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" "https://www.tiktok.com/" -H "User-Agent: $UA")
if [ "$HTTP_CODE" = "200" ]; then
    PAGE_CONTENT=$(curl -s -L "https://www.tiktok.com/" -H "User-Agent: $UA")
    if echo "$PAGE_CONTENT" | grep -q "__UNIVERSAL_DATA_FOR_REHYDRATION__"; then
        echo -e "   ${GREEN}✅ 页面包含 TikTok 核心数据${NC}"
        PAGE_OK=2
    elif echo "$PAGE_CONTENT" | grep -qi "captcha\|verify"; then
        echo -e "   ${YELLOW}⚠️  页面可能触发验证${NC}"
        PAGE_OK=1
    else
        echo -e "   ${RED}❌ 页面内容异常${NC}"
        PAGE_OK=0
    fi
else
    echo -e "   ${RED}❌ HTTP 状态码异常: $HTTP_CODE${NC}"
    PAGE_OK=0
fi

rm -f "$COOKIE_JAR"

# 综合评分
SCORE=0
# IP 类型
if [ "$HOSTING_FLAG" = "0" ] && [ "$PROXY_FLAG" = "0" ]; then
    SCORE=$((SCORE+30))
elif [ "$HOSTING_FLAG" = "1" ]; then
    SCORE=$((SCORE-30))
elif [ "$PROXY_FLAG" = "1" ]; then
    SCORE=$((SCORE-50))
fi
# 时区匹配
[ "$TZ_MATCH" = "1" ] && SCORE=$((SCORE+20)) || SCORE=$((SCORE-10))
# 黑名单
[ "$BLACKLISTED" = "0" ] && SCORE=$((SCORE+20)) || SCORE=$((SCORE-30))
# 端口 25
[ "$PORT25_OPEN" = "0" ] && SCORE=$((SCORE+10)) || SCORE=$((SCORE-10))
# TikTok 接口和页面
[ "$RECOMMEND_OK" = "1" ] && SCORE=$((SCORE+10))
case $PAGE_OK in
    2) SCORE=$((SCORE+20)) ;;
    1) SCORE=$((SCORE-10)) ;;
    0) SCORE=$((SCORE-30)) ;;
esac

echo ""
echo "=========================================="
echo -e "${BLUE}           检测结论${NC}"
echo "=========================================="

if [ $SCORE -ge 80 ]; then
    echo -e "${GREEN}⭐⭐⭐⭐⭐ 顶级家宽 IP${NC}"
    echo -e "✅ 完全适合 TikTok 重度运营（注册、发视频、直播、矩阵）"
elif [ $SCORE -ge 50 ]; then
    echo -e "${GREEN}⭐⭐⭐⭐ 良好住宅/商业 IP${NC}"
    echo -e "✅ 适合日常运营（登录、互动、少量发视频）"
elif [ $SCORE -ge 20 ]; then
    echo -e "${YELLOW}⭐⭐⭐ 混合型 IP（小型 ISP 或企业宽带）${NC}"
    echo -e "⚠️ 适合观看和基础互动，不建议批量运营"
elif [ $SCORE -ge -20 ]; then
    echo -e "${RED}⭐⭐ 数据中心 / 云 VPS IP${NC}"
    echo -e "❌ 仅适合浏览，登录和发视频极易触发验证"
else
    echo -e "${RED}⭐ 高风险 IP（代理/黑名单）${NC}"
    echo -e "❌ 强烈不建议用于任何 TikTok 操作"
fi

echo ""
echo "评分详情: ${SCORE} 分"
echo "  - IP 类型: $([ "$HOSTING_FLAG" = "0" ] && [ "$PROXY_FLAG" = "0" ] && echo "家宽/住宅级" || echo "数据中心/代理")"
echo "  - 时区匹配: $([ "$TZ_MATCH" = "1" ] && echo "匹配" || echo "不匹配/未知")"
echo "  - 黑名单: $([ "$BLACKLISTED" = "0" ] && echo "干净" || echo "被列入")"
echo "  - 25 端口: $([ "$PORT25_OPEN" = "0" ] && echo "关闭" || echo "开放")"
echo "  - 推荐接口: $([ "$RECOMMEND_OK" = "1" ] && echo "活跃" || echo "不活跃")"
echo "  - 页面状态: $([ "$PAGE_OK" -eq 2 ] && echo "正常" || ([ "$PAGE_OK" -eq 1 ] && echo "触发验证" || echo "异常"))"
echo ""
echo "=========================================="
echo "检测完成时间: $(date)"
echo "=========================================="
