#!/bin/bash

# TikTok IP 环境全面检测脚本 v3.0
# 依赖：curl, dig, jq (可选，没有就用 grep/sed)

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
echo "   TikTok IP 环境全面检测 v3.0"
echo "=========================================="
echo ""

# 1. 获取本机公网 IP
MY_IP=$(curl -s ifconfig.me)
echo -e "${BLUE}[1/7] 本机 IP: ${GREEN}$MY_IP${NC}"

# 2. IP 类型检测（使用 ip-api.com 的 hosting/proxy 字段）
echo -e "${BLUE}[2/7] 检测 IP 类型（ip-api.com）...${NC}"
IPAPI_DATA=$(curl -s "http://ip-api.com/json/${MY_IP}?fields=status,message,isp,org,as,proxy,hosting,mobile,query")
if echo "$IPAPI_DATA" | grep -q '"status":"success"'; then
    HOSTING=$(echo "$IPAPI_DATA" | grep -o '"hosting":[^,]*' | cut -d':' -f2 | tr -d ' ')
    PROXY=$(echo "$IPAPI_DATA" | grep -o '"proxy":[^,]*' | cut -d':' -f2 | tr -d ' ')
    ISP=$(echo "$IPAPI_DATA" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4)
    AS=$(echo "$IPAPI_DATA" | grep -o '"as":"[^"]*"' | cut -d'"' -f4)
    echo -e "   ISP: $ISP"
    echo -e "   AS: $AS"
    if [ "$HOSTING" = "true" ]; then
        echo -e "   ${RED}⚠️  标记为 hosting (数据中心/云)${NC}"
        HOSTING_FLAG=1
    else
        echo -e "   ${GREEN}✅ 非 hosting (可能是住宅或商业)${NC}"
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

# 3. 补充 ipinfo.io 数据（用于地理位置和时区）
echo -e "${BLUE}[3/7] 补充地理位置信息（ipinfo.io）...${NC}"
IPINFO_DATA=$(curl -s "https://ipinfo.io/${MY_IP}/json")
COUNTRY=$(echo "$IPINFO_DATA" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
CITY=$(echo "$IPINFO_DATA" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
TIMEZONE=$(echo "$IPINFO_DATA" | grep -o '"timezone":"[^"]*"' | cut -d'"' -f4)
ORG=$(echo "$IPINFO_DATA" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
echo -e "   国家: $COUNTRY, 城市: $CITY"
echo -e "   时区: $TIMEZONE"
echo -e "   org: $ORG"

# 4. 信誉检测：使用 ipinfo.io 的 abuse 字段（免费版可能无，尝试）
echo -e "${BLUE}[4/7] 信誉检测（滥用记录）...${NC}"
ABUSE_DATA=$(curl -s "https://ipinfo.io/${MY_IP}/abuse")
if echo "$ABUSE_DATA" | grep -q '"address"'; then
    ABUSE_COUNTRY=$(echo "$ABUSE_DATA" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
    echo -e "   ${RED}⚠️  该 IP 有滥用记录（国家: $ABUSE_COUNTRY）${NC}"
    ABUSE_FLAG=1
else
    echo -e "   ${GREEN}✅ 未发现公开滥用记录${NC}"
    ABUSE_FLAG=0
fi

# 5. 环境一致性：系统时区 vs IP 时区
echo -e "${BLUE}[5/7] 环境一致性检测（时区匹配）...${NC}"
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

# 6. 网络质量检测（curl TikTok 状态码 + ping 延迟）
echo -e "${BLUE}[6/7] 网络质量检测...${NC}"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" "https://www.tiktok.com/" -H "User-Agent: $UA" --max-time 10)
echo -n "   TikTok HTTP 状态码: "
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}200 (正常)${NC}"
    HTTP_OK=1
elif [ "$HTTP_CODE" = "302" ]; then
    echo -e "${YELLOW}302 (可能被重定向至验证页)${NC}"
    HTTP_OK=0
elif [ "$HTTP_CODE" = "403" ]; then
    echo -e "${RED}403 (被封锁)${NC}"
    HTTP_OK=-1
else
    echo -e "${RED}$HTTP_CODE (异常)${NC}"
    HTTP_OK=-1
fi

# Ping 延迟（只 ping 3 次）
PING_RESULT=$(ping -c 3 www.tiktok.com 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
if [ -n "$PING_RESULT" ]; then
    echo -e "   Ping 平均延迟: ${PING_RESULT} ms"
    if (( $(echo "$PING_RESULT < 150" | bc -l) )); then
        PING_GOOD=1
    else
        PING_GOOD=0
    fi
else
    echo -e "   ${YELLOW}无法 ping 通（可能被禁 ICMP）${NC}"
    PING_GOOD=-1
fi

# 7. 综合评分与结论
echo -e "${BLUE}[7/7] 综合评估...${NC}"
SCORE=0
# IP 类型权重 40
if [ "$HOSTING_FLAG" = "0" ] && [ "$PROXY_FLAG" = "0" ]; then
    SCORE=$((SCORE+40))
    TYPE_LEVEL="家宽/住宅级"
elif [ "$HOSTING_FLAG" = "1" ]; then
    SCORE=$((SCORE-30))
    TYPE_LEVEL="数据中心"
elif [ "$PROXY_FLAG" = "1" ]; then
    SCORE=$((SCORE-50))
    TYPE_LEVEL="代理/VPN"
else
    TYPE_LEVEL="未知"
fi

# 信誉权重 20
if [ "$ABUSE_FLAG" = "0" ]; then
    SCORE=$((SCORE+20))
fi

# 环境一致性 20
if [ "$TZ_MATCH" = "1" ]; then
    SCORE=$((SCORE+20))
elif [ "$TZ_MATCH" = "0" ]; then
    SCORE=$((SCORE-10))
fi

# 网络质量 20
if [ "$HTTP_OK" = "1" ]; then
    SCORE=$((SCORE+15))
    if [ "$PING_GOOD" = "1" ]; then
        SCORE=$((SCORE+5))
    fi
elif [ "$HTTP_OK" = "0" ]; then
    SCORE=$((SCORE-10))
else
    SCORE=$((SCORE-20))
fi

echo ""
echo "=========================================="
echo -e "${BLUE}           检测结论${NC}"
echo "=========================================="

if [ $SCORE -ge 70 ]; then
    echo -e "${GREEN}⭐⭐⭐⭐⭐ 顶级家宽 IP${NC}"
    echo -e "✅ 完全适合 TikTok 重度运营（注册、发视频、直播、矩阵）"
    echo -e "✅ 风控风险极低，可放心使用"
elif [ $SCORE -ge 40 ]; then
    echo -e "${GREEN}⭐⭐⭐⭐ 良好住宅/商业 IP${NC}"
    echo -e "✅ 适合日常运营（登录、互动、少量发视频）"
    echo -e "⚠️ 建议避免极端高频操作"
elif [ $SCORE -ge 10 ]; then
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
echo "  - IP 类型: $TYPE_LEVEL"
echo "  - 滥用记录: $([ $ABUSE_FLAG -eq 0 ] && echo '无' || echo '有')"
echo "  - 时区匹配: $([ $TZ_MATCH -eq 1 ] && echo '匹配' || echo '不匹配/未知')"
echo "  - HTTP 状态: $HTTP_CODE"
echo "  - Ping 延迟: ${PING_RESULT:-无法测量} ms"
echo ""
echo "=========================================="
echo "检测完成时间: $(date)"
echo "=========================================="
