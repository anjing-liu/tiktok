#!/bin/bash

# 颜色定义
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo "========================================="
echo "    TikTok 环境深度检测脚本 v1.0"
echo "========================================="

# 1. 基础信息获取
MY_IP=$(curl -s ifconfig.me)
echo -e "${BLUE}[1/5] 检测 IP: ${GREEN}$MY_IP${NC}"

# 2. 核心：IP 类型判断（调用 ipinfo.io 的免费接口）
echo -e "${BLUE}[2/5] 正在进行 IP 类型分析...${NC}"
IPINFO_DATA=$(curl -s "https://ipinfo.io/${MY_IP}/json")
ISP=$(echo "$IPINFO_DATA" | grep -o '"org":"[^"]*"' | cut -d'"' -f4 | sed 's/[0-9]* //g')
ASN=$(echo "$IPINFO_DATA" | grep -o '"asn":"[^"]*"' | cut -d'"' -f4)

# 根据 ISP/ASN 关键词做类型分级判断
FINAL_TYPE="Unknown"
FINAL_SCORE=0
if echo "$ISP" | grep -qiE "China Telecom|China Unicom|China Mobile|Comcast|AT&T|Verizon|Time Warner|Cox|Rogers|Bell|Deutsche Telekom|Orange|BT|Telia|Telefonica|NTT|KDDI|Softbank|SK Broadband|KT Corporation|Telstra|Singtel"; then
    FINAL_TYPE="Premium Residential"
    FINAL_SCORE=100
elif echo "$ISP" | grep -qiE "DigitalOcean|AWS|Amazon|Google Cloud|Microsoft|Azure|Alibaba Cloud|Tencent|Vultr|Linode|Hetzner|OVH|Hostinger|Cloudflare|Akamai|NetLab|M247"; then
    FINAL_TYPE="Datacenter / Cloud"
    FINAL_SCORE=0
elif echo "$ISP" | grep -qiE "VPN|Proxy|Anonymous|Private Internet Access|Nord|Express|Surfshark|HideMyAss|CyberGhost|IPVanish"; then
    FINAL_TYPE="VPN / Proxy"
    FINAL_SCORE=10
else
    FINAL_TYPE="Mixed / Unknown (Proceed with caution)"
    FINAL_SCORE=30
fi

echo -e "   ISP: $ISP"
echo -e "   ASN: $ASN"
echo -e "   ${GREEN}解析结果: $FINAL_TYPE${NC}"

# 3. TikTok 页面访问状态检测
echo -e "${BLUE}[3/5] TikTok 网页访问状态检测...${NC}"
HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" "https://www.tiktok.com/")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "   ${GREEN}✅ 状态码 200，可访问。${NC}"
elif [ "$HTTP_CODE" = "302" ]; then
    echo -e "   ${YELLOW}⚠️ 状态码 302，可能被重定向至验证页面。${NC}"
else
    echo -e "   ${RED}❌ 状态码 $HTTP_CODE，访问受限。${NC}"
fi

# 4. TikTok API 登录接口检测（模拟浏览器）
echo -e "${BLUE}[4/5] TikTok API 登录接口检测...${NC}"
API_CODE=$(curl -s -o /dev/null -w "%{http_code}\n" "https://www.tiktok.com/passport/web/account/info/" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
if [ "$API_CODE" = "200" ]; then
    echo -e "   ${GREEN}✅ 状态码 200，接口通畅。${NC}"
elif [ "$API_CODE" = "000" ]; then
    echo -e "   ${RED}❌ 状态码 000，连接被拒绝或超时。${NC}"
else
    echo -e "   ${YELLOW}⚠️ 状态码 $API_CODE，可能被限流。${NC}"
fi

# 5. 行为模拟测试 (模拟真实用户请求, 检测是否为脚本环境)
echo -e "${BLUE}[5/5] 高级行为模拟测试...${NC}"
RANDOM_WAIT=$(( ( RANDOM % 10 ) + 1 ))
echo "   模拟等待 ${RANDOM_WAIT}s..."
sleep $RANDOM_WAIT
FINAL_CHECK=$(curl -s -L "https://www.tiktok.com/" -H "User-Agent: Mozilla/5.0" | grep -i "video-feed")
if [ -n "$FINAL_CHECK" ]; then
    echo -e "   ${GREEN}✅ 检测通过，页面包含正常视频流。${NC}"
else
    echo -e "   ${YELLOW}⚠️ 未检测到视频流，可能非原生环境。${NC}"
fi

# 最终建议
echo "========================================="
echo -e "最终评级与建议:"

if [ $FINAL_SCORE -ge 80 ]; then
    echo -e "${GREEN}✅ 该 IP 为顶级原生家宽 IP。${NC}"
    echo -e "${GREEN}✅ 适合重度运营与账号矩阵。${NC}"
elif [ $FINAL_SCORE -ge 50 ]; then
    echo -e "${YELLOW}⚠️ 该 IP 为混合类型或小型 ISP。${NC}"
    echo -e "${YELLOW}⚠️ 适合日常观看，不建议大规模运营。${NC}"
else
    echo -e "${RED}❌ 该 IP 为数据中心 / 云 IP 或 VPN。${NC}"
    echo -e "${RED}❌ 仅适合浏览，运营风险较高。${NC}"
fi
echo "========================================="
