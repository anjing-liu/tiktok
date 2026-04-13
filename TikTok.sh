#!/bin/bash

# TikTok 真实解锁检测脚本 v4.0（严谨版）
# 基于页面内容分析，而非仅 HTTP 状态码

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

echo ""
echo "=========================================="
echo "   TikTok 真实解锁检测 v4.0（严谨版）"
echo "=========================================="
echo ""

# 1. 获取最终 URL 和页面内容（跟随重定向）
echo -e "${BLUE}[1/4] 分析页面重定向及内容...${NC}"
TEMP_FILE=$(mktemp)
FINAL_URL=$(curl -s -L -o "$TEMP_FILE" -w "%{url_effective}\n" "https://www.tiktok.com/" \
    -H "User-Agent: $UA" \
    -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
    -H "Accept-Language: en-US,en;q=0.5" \
    --max-time 15 2>/dev/null)

PAGE_SIZE=$(stat -c%s "$TEMP_FILE" 2>/dev/null || echo 0)

echo "   最终 URL: $FINAL_URL"
echo "   页面大小: $PAGE_SIZE 字节"

# 2. 检测屏蔽特征（关键词）
echo -e "${BLUE}[2/4] 检测屏蔽关键词...${NC}"
BLOCKED_KEYWORDS=("Access Denied" "Blocked" "Forbidden" "captcha" "verify" "challenge" "Just a moment" "Checking your browser")
FOUND_BLOCKED=""
for kw in "${BLOCKED_KEYWORDS[@]}"; do
    if grep -iq "$kw" "$TEMP_FILE"; then
        FOUND_BLOCKED="$kw"
        break
    fi
done

if [ -n "$FOUND_BLOCKED" ]; then
    echo -e "   ${RED}⚠️ 检测到屏蔽特征: $FOUND_BLOCKED${NC}"
    BLOCKED_FLAG=1
else
    echo -e "   ${GREEN}✅ 未检测到明显的屏蔽关键词${NC}"
    BLOCKED_FLAG=0
fi

# 3. 检测正常 TikTok 页面特征
echo -e "${BLUE}[3/4] 检测正常页面特征...${NC}"

# 特征1：包含全局数据 JSON
if grep -q "__UNIVERSAL_DATA_FOR_REHYDRATION__" "$TEMP_FILE"; then
    echo -e "   ${GREEN}✅ 包含核心数据 JSON${NC}"
    HAS_JSON=1
else
    echo -e "   ${RED}❌ 缺少核心数据 JSON${NC}"
    HAS_JSON=0
fi

# 特征2：包含视频列表相关字符串
if grep -qE "video-feed|ItemVideo|webapp.video" "$TEMP_FILE"; then
    echo -e "   ${GREEN}✅ 包含视频列表元素${NC}"
    HAS_VIDEO_FEED=1
else
    echo -e "   ${RED}❌ 缺少视频列表元素${NC}"
    HAS_VIDEO_FEED=0
fi

# 特征3：页面标题包含 TikTok
PAGE_TITLE=$(grep -o "<title>[^<]*</title>" "$TEMP_FILE" | sed 's/<title>//;s/<\/title>//')
if echo "$PAGE_TITLE" | grep -qi "TikTok"; then
    echo -e "   ${GREEN}✅ 页面标题正常: $PAGE_TITLE${NC}"
    TITLE_OK=1
else
    echo -e "   ${YELLOW}⚠️ 页面标题异常: ${PAGE_TITLE:-空}${NC}"
    TITLE_OK=0
fi

rm -f "$TEMP_FILE"

# 4. 尝试获取一个真实的视频页面（可选，更严格）
echo -e "${BLUE}[4/4] 测试具体视频页面...${NC}"
# 使用一个已知存在的视频 ID（来自热门视频，不易失效）
TEST_VIDEO_ID="7316591043514453254"
VIDEO_URL="https://www.tiktok.com/@tiktok/video/$TEST_VIDEO_ID"
VIDEO_TEMP=$(mktemp)
curl -s -L -o "$VIDEO_TEMP" "$VIDEO_URL" \
    -H "User-Agent: $UA" \
    --max-time 15 2>/dev/null
VIDEO_SIZE=$(stat -c%s "$VIDEO_TEMP" 2>/dev/null || echo 0)
if grep -q "video-feed\|ItemVideo\|<video" "$VIDEO_TEMP"; then
    echo -e "   ${GREEN}✅ 视频页面可正常获取（大小: $VIDEO_SIZE 字节）${NC}"
    VIDEO_OK=1
elif [ $VIDEO_SIZE -lt 10000 ]; then
    echo -e "   ${RED}❌ 视频页面被屏蔽或返回空内容${NC}"
    VIDEO_OK=0
else
    echo -e "   ${YELLOW}⚠️ 视频页面内容异常${NC}"
    VIDEO_OK=0
fi
rm -f "$VIDEO_TEMP"

# ============================================
# 综合评分与结论
# ============================================
echo ""
echo "=========================================="
echo -e "${BLUE}           检测结论${NC}"
echo "=========================================="

SCORE=0
[ "$BLOCKED_FLAG" -eq 0 ] && SCORE=$((SCORE+1))
[ "$HAS_JSON" -eq 1 ] && SCORE=$((SCORE+2))
[ "$HAS_VIDEO_FEED" -eq 1 ] && SCORE=$((SCORE+2))
[ "$TITLE_OK" -eq 1 ] && SCORE=$((SCORE+1))
[ "$VIDEO_OK" -eq 1 ] && SCORE=$((SCORE+2))

echo ""
if [ $SCORE -ge 7 ]; then
    echo -e "   ${GREEN}✅✅✅ 完全解锁（真实可用）${NC}"
    echo "   说明：IP 可以正常访问 TikTok 所有核心功能。"
    STATUS="完全解锁"
elif [ $SCORE -ge 5 ]; then
    echo -e "   ${GREEN}✅✅ 浏览解锁（可看视频，互动可能受限）${NC}"
    echo "   说明：能看视频，但登录或互动可能触发验证。"
    STATUS="浏览解锁"
elif [ $SCORE -ge 3 ]; then
    echo -e "   ${YELLOW}⚠️ 部分解锁（可能只看到验证页面或内容不全）${NC}"
    echo "   说明：IP 触发了风控，只能看到验证页面或简化内容。"
    STATUS="部分解锁"
else
    echo -e "   ${RED}❌ 完全屏蔽（无法访问）${NC}"
    echo "   说明：IP 被 TikTok 明确封锁。"
    STATUS="完全屏蔽"
fi

echo ""
echo "评分详情: 总分 $SCORE/8"
echo "  - 无屏蔽关键词: $([ $BLOCKED_FLAG -eq 1 ] && echo '否' || echo '是')"
echo "  - 包含核心JSON: $([ $HAS_JSON -eq 1 ] && echo '是' || echo '否')"
echo "  - 包含视频列表: $([ $HAS_VIDEO_FEED -eq 1 ] && echo '是' || echo '否')"
echo "  - 页面标题正常: $([ $TITLE_OK -eq 1 ] && echo '是' || echo '否')"
echo "  - 视频页可访问: $([ $VIDEO_OK -eq 1 ] && echo '是' || echo '否')"
echo ""
echo "=========================================="
