#!/bin/bash
set -e

# ==================== 配置 ====================
PORT=${PORT:-8080}
UUID=${UUID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || echo "$(date +%s | md5sum | cut -c1-8)-$(shuf -i 1000-9999 -n 1)-4$(shuf -i 1000-9999 -n 1)-$(shuf -i 8000-9999 -n 1)-$(date +%N | cut -c1-12)")}
DOMAIN=${DOMAIN:-"localhost"}
WSPATH=${WSPATH:-${UUID:0:8}}
NAME=${NAME:-""}
XRAY_VERSION=${XRAY_VERSION:-"1.8.24"}

echo "🚀 Railway Proxy (VLESS+Trojan WebSocket)"
echo "📌 Port: $PORT"

# ==================== 获取 IP ====================
IP=$(curl -s --connect-timeout 3 https://api64.ipify.org||curl -s --connect-timeout 3 https://ifconfig.me||echo "UNKNOWN")
echo "✅ Server IP: $IP"
echo "✅ UUID: $UUID"
echo "✅ Domain: $DOMAIN"
echo "✅ Path: /$WSPATH"

# ==================== 工作目录 ====================
for DIR in "$HOME/railway-proxy" "/tmp/railway-proxy" "/var/tmp/railway-proxy"; do
    if mkdir -p "$DIR" 2>/dev/null; then
        WORKDIR="$DIR"
        break
    fi
done

[ -z "$WORKDIR" ] && { echo "❌ Cannot create working directory"; exit 1; }

cd "$WORKDIR"
echo "✅ Working directory: $WORKDIR"

# ==================== 检测架构 ====================
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64)
        XRAY_ARCH="64"
        ;;
    aarch64|arm64)
        XRAY_ARCH="arm64-v8a"
        ;;
    armv7*|armv7l)
        XRAY_ARCH="arm32-v7a"
        ;;
    *)
        echo "⚠️  Unknown architecture: $ARCH, using 64"
        XRAY_ARCH="64"
        ;;
esac

# ==================== 下载 Xray ====================
if [ ! -f xray ]; then
    echo "📥 Downloading Xray v${XRAY_VERSION}..."
    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-${XRAY_ARCH}.zip"
    
    if curl -sLo x.zip "$DOWNLOAD_URL"; then
        unzip -qo x.zip xray 2>/dev/null || unzip -o x.zip xray
        chmod +x xray
        rm -f x.zip
        echo "✅ Xray installed"
    else
        echo "❌ Failed to download Xray"
        exit 1
    fi
else
    echo "✅ Xray already exists"
fi

# ==================== 生成 Xray 配置 (WebSocket) ====================
cat > config.json << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${PORT},
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/${WSPATH}"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# ==================== 生成订阅链接 ====================
ISP="Unknown"
NODE_NAME="${NAME:-Railway}"

# 使用域名或IP
if [ "$DOMAIN" != "localhost" ]; then
    SERVER_ADDR="$DOMAIN"
else
    SERVER_ADDR="$IP"
fi

# 直连配置: 使用实际端口,无TLS
VLESS_LINK="vless://${UUID}@${SERVER_ADDR}:${PORT}?encryption=none&security=none&type=ws&host=${SERVER_ADDR}&path=%2F${WSPATH}#${NODE_NAME}"

TROJAN_LINK="trojan://${UUID}@${SERVER_ADDR}:${PORT}?security=none&type=ws&host=${SERVER_ADDR}&path=%2F${WSPATH}#${NODE_NAME}-Trojan"

# Base64编码订阅
SUBSCRIPTION=$(echo -e "${VLESS_LINK}\n${TROJAN_LINK}" | base64 -w 0)

# 保存订阅链接
echo "$SUBSCRIPTION" > subscription.txt
echo -e "${VLESS_LINK}\n${TROJAN_LINK}" > links.txt

# ==================== 创建简单的HTTP服务器脚本 ====================
# 使用nc (netcat) 提供HTTP服务
cat > http_server.sh << 'HTTPSERVER'
#!/bin/bash

PORT=$1
WSPATH=$2
SUBSCRIPTION_FILE=$3

while true; do
    {
        read -r request
        read -r host
        while read -r header && [ "$header" != $'\r' ]; do
            :
        done
        
        # 解析请求路径
        REQUEST_PATH=$(echo "$request" | awk '{print $2}')
        
        if [ "$REQUEST_PATH" = "/" ]; then
            # 返回简单HTML页面
            echo -ne "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n"
            echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Service Running</title></head><body style="display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:white;font-family:Arial"><div style="text-align:center;padding:3rem;background:rgba(255,255,255,0.1);border-radius:20px;backdrop-filter:blur(10px)"><h1 style="font-size:3rem;margin:0 0 1rem">🚀 Service Running</h1><div style="display:inline-block;padding:8px 16px;background:rgba(0,255,0,0.2);border-radius:20px;margin-top:1rem">● ONLINE</div></div></body></html>'
        elif [ "$REQUEST_PATH" = "/sub" ]; then
            # 返回订阅内容
            echo -ne "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n"
            cat "$SUBSCRIPTION_FILE"
        else
            # 404
            echo -ne "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nNot Found"
        fi
    } | nc -l -p $PORT -q 1 2>/dev/null || nc -l $PORT 2>/dev/null
done
HTTPSERVER

chmod +x http_server.sh

# ==================== 显示配置信息 ====================
echo ""
echo "=========================================="
echo "🎉 Deployment Complete!"
echo "=========================================="
echo "📍 Server: ${SERVER_ADDR}:${PORT}"
echo "🔑 UUID: $UUID"
echo "📂 WebSocket Path: /$WSPATH"
echo ""
echo "🔗 VLESS Link:"
echo "$VLESS_LINK"
echo ""
echo "🔗 Trojan Link:"
echo "$TROJAN_LINK"
echo ""
echo "📥 Subscription URL:"
echo "http://${SERVER_ADDR}:${PORT}/sub"
echo ""
echo "⚙️  Client Configuration:"
echo "  - Protocol: VLESS or Trojan"
echo "  - Address: ${SERVER_ADDR}"
echo "  - Port: ${PORT}"
echo "  - UUID: $UUID"
echo "  - Encryption: none"
echo "  - Transport: WebSocket"
echo "  - Path: /${WSPATH}"
echo "  - TLS: Disabled"
echo ""
echo "💾 Files saved:"
echo "  - Config: $WORKDIR/config.json"
echo "  - Subscription: $WORKDIR/subscription.txt"
echo "  - Links: $WORKDIR/links.txt"
echo "=========================================="
echo ""

# ==================== 保存部署信息 ====================
cat > INFO.txt << INFO
Railway Proxy Deployment Info
==========================================
Server IP: $IP
Port: $PORT
UUID: $UUID
Domain: $DOMAIN
WebSocket Path: /$WSPATH

Subscription: https://$DOMAIN/sub

VLESS Link:
$VLESS_LINK

Trojan Link:
$TROJAN_LINK

Client Configuration:
- Protocol: VLESS or Trojan
- Address: $DOMAIN
- Port: 443 (with TLS) or $PORT (direct)
- UUID/Password: $UUID
- Transport: WebSocket
- Path: /$WSPATH
- TLS: Enable for port 443

Working Directory: $WORKDIR
Deployment Time: $(date)
==========================================
INFO

# ==================== 启动服务 ====================
echo "🚀 Starting Xray proxy server..."
echo "💡 Press Ctrl+C to stop"
echo ""

# 在后台启动HTTP服务器
if command -v nc &>/dev/null; then
    echo "✅ Starting HTTP server on port $PORT for web interface..."
    ./http_server.sh $PORT "$WSPATH" subscription.txt &
    HTTP_PID=$!
    echo "✅ HTTP server started (PID: $HTTP_PID)"
fi

# 启动Xray (无限循环,自动重启)
while :; do
    ./xray run -c config.json 2>&1 || sleep 3
done
