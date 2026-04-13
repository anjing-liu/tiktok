import requests
import argparse
import subprocess
import sys
import time
from urllib.parse import urlparse

def get_public_ip(proxies=None):
    """获取当前出口IP"""
    try:
        r = requests.get("https://api.ipify.org?format=json", proxies=proxies, timeout=10)
        return r.json()["ip"]
    except:
        return None

def get_ip_info(ip, proxies=None):
    """ip-api.com 多维度信息（免费、无key）"""
    url = f"http://ip-api.com/json/{ip}?fields=status,message,country,countryCode,regionName,city,isp,org,as,proxy,hosting,mobile,query"
    try:
        r = requests.get(url, proxies=proxies, timeout=10)
        return r.json()
    except:
        return {"status": "fail", "message": "请求失败"}

def test_latency(proxies=None):
    """简单延迟测试（tiktok.com）"""
    start = time.time()
    try:
        r = requests.get("https://www.tiktok.com", proxies=proxies, timeout=8)
        latency = round((time.time() - start) * 1000)
        return latency if r.status_code == 200 else 9999
    except:
        return 9999

def test_tiktok_access(proxies=None):
    """TikTok首页连通性测试"""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"
    }
    try:
        r = requests.get("https://www.tiktok.com", headers=headers, proxies=proxies, timeout=10, allow_redirects=True)
        if r.status_code == 200 and "tiktok.com" in r.url and len(r.text) > 10000:
            return "✅ 正常访问", True
        elif r.status_code == 403 or r.status_code == 429:
            return f"❌ 被限流/封锁 (状态码 {r.status_code})", False
        else:
            return f"⚠️ 异常 (状态码 {r.status_code})", False
    except Exception as e:
        return f"❌ 连接失败: {str(e)[:80]}", False

def main():
    parser = argparse.ArgumentParser(description="TikTok IP 多维度测试脚本（运营 vs 观看）")
    parser.add_argument("--proxy", help="代理地址，例如 http://user:pass@ip:port 或 socks5://ip:port")
    parser.add_argument("--target", default="US", help="目标国家代码（如 US、GB、JP），默认 US")
    args = parser.parse_args()

    proxies = {"http": args.proxy, "https": args.proxy} if args.proxy else None
    if args.proxy and args.proxy.startswith("socks"):
        proxies = {"http": args.proxy, "https": args.proxy}

    print("🔍 TikTok IP 测试开始...\n")

    # 1. 获取出口IP
    public_ip = get_public_ip(proxies)
    if not public_ip:
        print("❌ 无法获取出口IP，请检查代理是否可用")
        sys.exit(1)
    print(f"📍 出口IP: {public_ip}")

    # 2. IP详细信息
    info = get_ip_info(public_ip, proxies)
    if info.get("status") != "success":
        print(f"❌ IP信息查询失败: {info.get('message', '未知错误')}")
        sys.exit(1)

    country = info.get("countryCode", "未知")
    city = info.get("city", "未知")
    isp = info.get("isp", "未知")
    is_proxy = info.get("proxy", False)
    is_hosting = info.get("hosting", False)
    is_mobile = info.get("mobile", False)

    print(f"🌍 地区: {info.get('country')} ({country}) - {city}")
    print(f"🏢 ISP: {isp}")
    print(f"📡 类型: {'移动网络' if is_mobile else '住宅/ISP' if not is_hosting and not is_proxy else '数据中心/代理'}")
    print(f"🚩 代理检测: {'是' if is_proxy else '否'}")
    print(f"🖥️  Hosting检测: {'是' if is_hosting else '否'}")

    # 3. 延迟
    latency = test_latency(proxies)
    print(f"⚡ TikTok延迟: {latency}ms {'✅ 优秀' if latency < 150 else '⚠️ 一般' if latency < 300 else '❌ 较高'}")

    # 4. TikTok访问测试
    access_status, access_ok = test_tiktok_access(proxies)
    print(f"🔗 TikTok访问: {access_status}")

    # 5. 多维度打分 & 结论
    score = 0
    reasons = []

    if country == args.target:
        score += 30
        reasons.append("✅ 地区匹配目标国家")
    else:
        reasons.append(f"⚠️ 地区不匹配（当前{country}，目标{args.target}）")

    if not is_proxy and not is_hosting:
        score += 40
        reasons.append("✅ 纯住宅/ISP属性（运营推荐）")
    elif is_mobile:
        score += 25
        reasons.append("✅ 移动IP（TikTok友好，但稳定性稍差）")
    else:
        reasons.append("❌ 数据中心或已知代理（运营高风险）")

    if latency < 200:
        score += 15
    elif latency < 350:
        score += 5

    if access_ok:
        score += 15
        reasons.append("✅ TikTok连通正常")
    else:
        reasons.append("❌ TikTok访问异常")

    print("\n" + "="*60)
    print("🎯 测试结论")
    print("="*60)
    for r in reasons:
        print(r)

    if score >= 80:
        print("\n🚀 **极适合运营**（多账号养号/直播/批量发视频）")
        print("   建议搭配指纹浏览器使用，单IP单号长期稳定")
    elif score >= 60:
        print("\n⚠️ **适合观看 + 轻度运营**（单号刷视频、偶尔发内容）")
        print("   运营风险中等，建议先小号测试")
    elif score >= 40:
        print("\n📺 **仅适合观看**（刷视频正常，但运营容易被风控）")
    else:
        print("\n❌ **不推荐使用**（观看都可能卡顿/限流）")

    print(f"\n综合分数: {score}/100")
    print("\n💡 额外建议（强烈推荐手动补充）:")
    print("   1. whoer.net 或 scamalytics.com 检查欺诈分数（<30分才干净）")
    print("   2. f.vision 综合指纹检测")
    print("   3. VPS用户可运行流媒体解锁脚本：")
    print("      bash <(wget -qO- https://down.vpsaff.net/linux/speedtest/superbench.sh) -f")
    print("   4. 运营一定要用**静态住宅IP**，动态IP容易被关联封号")

if __name__ == "__main__":
    main()
