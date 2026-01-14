#!/bin/bash
set -e

# ==================== 配置 ====================
PORT=${PORT:-8080}
UUID=${UUID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || echo "$(date +%s | md5sum | cut -c1-8)-$(shuf -i 1000-9999 -n 1)-4$(shuf -i 1000-9999 -n 1)-$(shuf -i 8000-9999 -n 1)-$(date +%N | cut -c1-12)")}
DOMAIN=${DOMAIN:-"localhost"}
WSPATH=${WSPATH:-${UUID:0:8}}
NAME=${NAME:-""}
NEZHA_SERVER=${NEZHA_SERVER:-""}
NEZHA_KEY=${NEZHA_KEY:-""}

echo "🚀 Railway Proxy Deployment"
echo "📌 Port: $PORT"

# ==================== 获取 IP ====================
IP=$(curl -s --connect-timeout 3 https://api64.ipify.org||curl -s --connect-timeout 3 https://ifconfig.me||echo "UNKNOWN")
echo "✅ Server IP: $IP"
echo "✅ UUID: $UUID"
echo "✅ Domain: $DOMAIN"
echo "✅ Path: /$WSPATH"

# ==================== 工作目录 ====================
# 尝试创建工作目录,按优先级
for DIR in "$HOME/railway-proxy" "/tmp/railway-proxy" "/var/tmp/railway-proxy"; do
    if mkdir -p "$DIR" 2>/dev/null; then
        WORKDIR="$DIR"
        break
    fi
done

[ -z "$WORKDIR" ] && { echo "❌ Cannot create working directory"; exit 1; }

cd "$WORKDIR"
echo "✅ Working directory: $WORKDIR"

# ==================== 安装 Node.js (如果需要) ====================
if ! command -v node &>/dev/null; then
    echo "📥 Installing Node.js..."
    if command -v apt-get &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
        apt-get install -y nodejs >/dev/null 2>&1
    elif command -v yum &>/dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
        yum install -y nodejs >/dev/null 2>&1
    fi
    echo "✅ Node.js installed"
fi

# ==================== 创建 package.json ====================
cat > package.json << 'EOF'
{
  "name": "railway-proxy",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "axios": "^1.6.0",
    "ws": "^8.14.0"
  }
}
EOF

# ==================== 创建 server.js ====================
cat > server.js << 'SERVERJS'
const http = require('http');
const fs = require('fs');
const axios = require('axios');
const net = require('net');
const crypto = require('crypto');
const { WebSocket, createWebSocketStream } = require('ws');

const UUID = process.env.UUID || '';
const DOMAIN = process.env.DOMAIN || 'localhost';
const WSPATH = process.env.WSPATH || UUID.slice(0, 8);
const SUB_PATH = process.env.SUB_PATH || 'sub';
const NAME = process.env.NAME || '';
const PORT = process.env.PORT || 8080;

let ISP = 'Unknown';
axios.get('https://api.ip.sb/geoip', { timeout: 5000 })
  .then(res => { ISP = `${res.data.country_code}-${res.data.isp}`.replace(/ /g, '_'); })
  .catch(() => {});

const httpServer = http.createServer((req, res) => {
  if (req.url === '/') {
    fs.readFile('index.html', 'utf8', (err, content) => {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(err ? '<h1>✓ Service Running</h1>' : content);
    });
  } else if (req.url === `/${SUB_PATH}`) {
    const name = NAME ? `${NAME}-${ISP}` : ISP;
    const vless = `vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=%2F${WSPATH}#${name}`;
    const trojan = `trojan://${UUID}@${DOMAIN}:443?security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=%2F${WSPATH}#${name}`;
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end(Buffer.from(vless + '\n' + trojan).toString('base64') + '\n');
  } else {
    res.writeHead(404);
    res.end('Not Found');
  }
});

const wss = new WebSocket.Server({ server: httpServer });
const uuid = UUID.replace(/-/g, "");

function handleVless(ws, msg) {
  const id = msg.slice(1, 17);
  if (!id.every((v, i) => v == parseInt(uuid.substr(i * 2, 2), 16))) return false;
  let i = msg.slice(17, 18).readUInt8() + 19;
  const port = msg.slice(i, i += 2).readUInt16BE();
  const atyp = msg.slice(i, i += 1).readUInt8();
  const host = atyp == 1 ? msg.slice(i, i += 4).join('.') :
    (atyp == 2 ? new TextDecoder().decode(msg.slice(i + 1, i += 1 + msg[i])) :
    msg.slice(i, i += 16).reduce((s, b, j, a) => (j % 2 ? s.concat(a.slice(j - 1, j + 1)) : s), [])
      .map(b => b.readUInt16BE().toString(16)).join(':'));
  ws.send(new Uint8Array([msg[0], 0]));
  const stream = createWebSocketStream(ws);
  net.connect({ host, port }, function() {
    this.write(msg.slice(i));
    stream.pipe(this).pipe(stream);
  }).on('error', () => {});
  return true;
}

function handleTrojan(ws, msg) {
  if (msg.length < 58) return false;
  const hash = crypto.createHash('sha224').update(UUID).digest('hex');
  if (msg.slice(0, 56).toString() !== hash) return false;
  let i = 56;
  if (msg[i] === 0x0d && msg[i + 1] === 0x0a) i += 2;
  if (msg[i++] !== 0x01) return false;
  const atyp = msg[i++];
  let host, port;
  if (atyp === 1) {
    host = msg.slice(i, i += 4).join('.');
  } else if (atyp === 3) {
    const len = msg[i++];
    host = msg.slice(i, i += len).toString();
  } else if (atyp === 4) {
    host = msg.slice(i, i += 16).reduce((s, b, j, a) => 
      (j % 2 ? s.concat(a.slice(j - 1, j + 1)) : s), [])
      .map(b => b.readUInt16BE().toString(16)).join(':');
  } else return false;
  port = msg.readUInt16BE(i);
  i += 2;
  if (msg[i] === 0x0d && msg[i + 1] === 0x0a) i += 2;
  const stream = createWebSocketStream(ws);
  net.connect({ host, port }, function() {
    if (i < msg.length) this.write(msg.slice(i));
    stream.pipe(this).pipe(stream);
  }).on('error', () => {});
  return true;
}

wss.on('connection', ws => {
  ws.once('message', msg => {
    if (msg.length > 17 && msg[0] === 0 && handleVless(ws, msg)) return;
    if (!handleTrojan(ws, msg)) ws.close();
  }).on('error', () => {});
});

httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`✓ Server running on port ${PORT}`);
  console.log(`✓ Subscription: https://${DOMAIN}/${SUB_PATH}`);
});
SERVERJS

# ==================== 创建 index.html ====================
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Service Running</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 3rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            backdrop-filter: blur(10px);
        }
        h1 { font-size: 3rem; margin: 0 0 1rem; }
        .status {
            display: inline-block;
            padding: 8px 16px;
            background: rgba(0, 255, 0, 0.2);
            border-radius: 20px;
            margin-top: 1rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Service Running</h1>
        <div class="status">● ONLINE</div>
    </div>
</body>
</html>
EOF

# ==================== 创建 .env ====================
cat > .env << EOF
UUID=$UUID
DOMAIN=$DOMAIN
PORT=$PORT
WSPATH=$WSPATH
SUB_PATH=sub
NAME=$NAME
EOF

# ==================== 安装依赖 ====================
echo "📦 Installing dependencies..."
npm install --production >/dev/null 2>&1 && echo "✅ Dependencies installed"

# ==================== 启动服务 ====================
echo ""
echo "=========================================="
echo "🎉 Deployment Complete!"
echo "=========================================="
echo "📍 Server: $IP:$PORT"
echo "🔑 UUID: $UUID"
echo "🌐 Domain: $DOMAIN"
echo "📂 Path: /$WSPATH"
echo ""
echo "🔗 Subscription:"
echo "https://$DOMAIN/sub"
echo ""
echo "⚙️  Client Configuration:"
echo "  - Protocol: VLESS/Trojan"
echo "  - Address: $DOMAIN"
echo "  - Port: 443"
echo "  - UUID: $UUID"
echo "  - Transport: WebSocket"
echo "  - Path: /$WSPATH"
echo "  - TLS: Enabled"
echo ""
echo "💾 Config saved to: $WORKDIR/.env"
echo "=========================================="
echo ""

# ==================== 保存信息到文件 ====================
cat > INFO.txt << INFO
Railway Proxy Info
==========================================
UUID: $UUID
Domain: $DOMAIN
Port: $PORT
Path: /$WSPATH
Server IP: $IP

Subscription: https://$DOMAIN/sub

Client Config:
- Protocol: VLESS/Trojan
- Address: $DOMAIN
- Port: 443
- UUID: $UUID
- Transport: WebSocket
- Path: /$WSPATH
- TLS: Enabled

Working Directory: $WORKDIR
Deployment time: $(date)
==========================================
INFO

echo "🚀 Starting server..."
echo "💡 Press Ctrl+C to stop"
echo ""

# ==================== 运行服务器 ====================
while :; do
    PORT=$PORT UUID=$UUID DOMAIN=$DOMAIN WSPATH=$WSPATH NAME="$NAME" node server.js 2>&1 || sleep 3
done
