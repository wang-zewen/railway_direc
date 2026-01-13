#!/bin/bash

# Railway Proxy 一键部署脚本
# 用途: 直接在服务器上部署 VLESS & Trojan 代理
#
# ============================================
# 使用方法
# ============================================
#
# 基础安装 (自动生成UUID):
#   curl -fsSL https://url/install.sh | bash
#
# 自定义UUID:
#   curl -fsSL https://url/install.sh | UUID=your-uuid bash
#
# 完整配置:
#   curl -fsSL https://url/install.sh | \
#     UUID=5efabea4-f6d4-91fd-b8f0-17e004c89c60 \
#     DOMAIN=your-app.up.railway.app \
#     PORT=8080 \
#     WSPATH=api/v2/ws \
#     NAME=MyNode \
#     bash
#
# ============================================
# 环境变量配置
# ============================================
#
# UUID           - 用户标识 (默认: 自动生成)
# DOMAIN         - 域名 (默认: localhost)
# PORT           - 服务端口 (默认: 8080)
# WSPATH         - WebSocket路径 (默认: UUID前8位)
# NAME           - 节点名称 (默认: 空)
# NEZHA_SERVER   - 哪吒服务器 (默认: 空)
# NEZHA_KEY      - 哪吒密钥 (默认: 空)
#
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 打印函数
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║    Railway Proxy 一键部署脚本                             ║
║    VLESS & Trojan 协议支持                                ║
║    WebSocket + TLS 传输                                   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检测系统
detect_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "Unable to detect system type"
        exit 1
    fi
    
    print_info "🐧 Detected system: $OS $VERSION"
}

# 检查权限 (不强制要求root,只警告)
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        print_warning "⚠️  Not running as root, some operations may fail"
        print_info "💡 If you encounter permission issues, run: sudo bash"
    fi
}

# 安装依赖
install_dependencies() {
    print_info "📦 Installing dependencies..."
    
    case $OS in
        ubuntu|debian)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq > /dev/null 2>&1 || true
            apt-get install -y -qq curl wget git > /dev/null 2>&1 || true
            
            # 安装 Node.js
            if ! command -v node &> /dev/null; then
                print_info "📥 Installing Node.js..."
                curl -fsSL https://deb.nodesource.com/setup_18.x | bash - > /dev/null 2>&1 || true
                apt-get install -y -qq nodejs > /dev/null 2>&1 || true
            fi
            ;;
        centos|rhel|fedora)
            yum install -y -q curl wget git > /dev/null 2>&1 || true
            
            # 安装 Node.js
            if ! command -v node &> /dev/null; then
                print_info "📥 Installing Node.js..."
                curl -fsSL https://rpm.nodesource.com/setup_18.x | bash - > /dev/null 2>&1 || true
                yum install -y -q nodejs > /dev/null 2>&1 || true
            fi
            ;;
        alpine)
            apk add --no-cache curl wget git nodejs npm > /dev/null 2>&1 || true
            ;;
        *)
            print_warning "⚠️  Unsupported system: $OS, continuing anyway..."
            ;;
    esac
    
    print_success "✅ Dependencies installed"
}

# 生成 UUID
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    elif command -v python &> /dev/null; then
        python -c "import uuid; print(str(uuid.uuid4()))"
    else
        cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s | md5sum | cut -c1-8)-$(shuf -i 1000-9999 -n 1)-4$(shuf -i 1000-9999 -n 1)-$(shuf -i 8000-9999 -n 1)-$(date +%N | cut -c1-12)"
    fi
}

# 生成 UUID
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    elif command -v python &> /dev/null; then
        python -c "import uuid; print(str(uuid.uuid4()))"
    else
        cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s | md5sum | cut -c1-8)-$(shuf -i 1000-9999 -n 1)-4$(shuf -i 1000-9999 -n 1)-$(shuf -i 8000-9999 -n 1)-$(date +%N | cut -c1-12)"
    fi
}

# 获取服务器IP
get_server_ip() {
    local ip=""
    
    # 尝试多个IP查询服务
    for url in "https://api64.ipify.org" "https://ifconfig.me" "https://ip.sb"; do
        ip=$(curl -s --max-time 3 "$url" 2>/dev/null)
        if [ -n "$ip" ] && [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return
        fi
    done
    
    echo "UNKNOWN"
}

# 初始化配置
init_config() {
    print_info "🔧 Initializing configuration..."
    
    # UUID: 优先环境变量,否则自动生成
    if [ -z "$UUID" ]; then
        USER_UUID=$(generate_uuid)
        print_info "✅ Generated UUID: $USER_UUID"
    else
        USER_UUID=$UUID
        print_info "✅ Using UUID: $USER_UUID"
    fi
    
    # DOMAIN: 使用环境变量或默认值
    if [ -z "$DOMAIN" ]; then
        DOMAIN="localhost"
        print_warning "⚠️  No DOMAIN specified, using: localhost"
    else
        print_info "✅ Using DOMAIN: $DOMAIN"
    fi
    
    # PORT: 使用环境变量或默认值
    PORT=${PORT:-8080}
    print_info "✅ Using PORT: $PORT"
    
    # WSPATH: 使用环境变量或UUID前8位
    if [ -z "$WSPATH" ]; then
        WSPATH=${USER_UUID:0:8}
        print_info "✅ Generated WSPATH: /$WSPATH"
    else
        print_info "✅ Using WSPATH: /$WSPATH"
    fi
    
    # NAME: 使用环境变量或留空
    NODE_NAME=${NAME:-""}
    if [ -n "$NODE_NAME" ]; then
        print_info "✅ Using NAME: $NODE_NAME"
    fi
    
    # 哪吒监控配置
    NEZHA_SERVER=${NEZHA_SERVER:-""}
    NEZHA_KEY=${NEZHA_KEY:-""}
    if [ -n "$NEZHA_SERVER" ]; then
        print_info "✅ Nezha monitoring enabled"
    fi
    
    # 获取服务器IP
    print_info "🌐 Getting server IP..."
    SERVER_IP=$(get_server_ip)
    print_info "✅ Server IP: $SERVER_IP"
    
    # 显示配置摘要
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}📋 Configuration Summary${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  UUID: ${CYAN}$USER_UUID${NC}"
    echo -e "  Domain: ${CYAN}$DOMAIN${NC}"
    echo -e "  Port: ${CYAN}$PORT${NC}"
    echo -e "  Path: ${CYAN}/$WSPATH${NC}"
    echo -e "  Server IP: ${CYAN}$SERVER_IP${NC}"
    if [ -n "$NODE_NAME" ]; then
        echo -e "  Name: ${CYAN}$NODE_NAME${NC}"
    fi
    if [ -n "$NEZHA_SERVER" ]; then
        echo -e "  Nezha: ${CYAN}Enabled${NC}"
    fi
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 创建工作目录
create_workdir() {
    WORKDIR="/opt/railway-proxy"
    
    if [ -d "$WORKDIR" ]; then
        print_warning "⚠️  Directory exists, backing up..."
        mv "$WORKDIR" "${WORKDIR}.backup.$(date +%s)"
    fi
    
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"
    
    print_success "✅ Working directory created: $WORKDIR"
}

# 创建项目文件
create_files() {
    print_info "📝 Creating project files..."
    
    # package.json
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

    # server.js (精简版,核心功能)
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

    # index.html
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
        p { font-size: 1.2rem; opacity: 0.9; }
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
        <p>Everything is OK</p>
        <div class="status">● ONLINE</div>
    </div>
</body>
</html>
EOF

    print_success "✅ Project files created"
}

# 创建环境变量文件
create_env() {
    cat > .env << EOF
UUID=$USER_UUID
DOMAIN=$DOMAIN
PORT=$PORT
WSPATH=$WSPATH
SUB_PATH=sub
NAME=$NODE_NAME
EOF
    print_success "✅ Configuration file created"
}

# 安装依赖
install_deps() {
    print_info "📦 Installing Node.js dependencies..."
    npm install --production > /dev/null 2>&1
    print_success "✅ Dependencies installed"
}

# 创建 systemd 服务
create_service() {
    print_info "🔧 Creating systemd service..."
    
    cat > /etc/systemd/system/railway-proxy.service << EOF
[Unit]
Description=Railway Proxy Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORKDIR
EnvironmentFile=$WORKDIR/.env
ExecStart=/usr/bin/node $WORKDIR/server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable railway-proxy > /dev/null 2>&1
    print_success "✅ Systemd service created"
}

# 启动服务
start_service() {
    print_info "🚀 Starting service..."
    systemctl restart railway-proxy
    sleep 2
    
    if systemctl is-active --quiet railway-proxy; then
        print_success "✅ Service started successfully"
    else
        print_error "❌ Service failed to start"
        print_info "💡 Check logs: journalctl -u railway-proxy -f"
        exit 1
    fi
}

# 显示信息
show_info() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}         🎉 Deployment Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}📍 Service Information:${NC}"
    echo -e "  UUID: ${YELLOW}$USER_UUID${NC}"
    echo -e "  Domain: ${YELLOW}$DOMAIN${NC}"
    echo -e "  Port: ${YELLOW}$PORT${NC}"
    echo -e "  Path: ${YELLOW}/$WSPATH${NC}"
    echo -e "  Server IP: ${YELLOW}$SERVER_IP${NC}"
    echo ""
    echo -e "${CYAN}🔗 Subscription URL:${NC}"
    echo -e "  ${YELLOW}https://$DOMAIN/sub${NC}"
    echo ""
    echo -e "${CYAN}⚙️  Client Configuration:${NC}"
    echo -e "  Protocol: VLESS/Trojan"
    echo -e "  Address: $DOMAIN"
    echo -e "  Port: 443"
    echo -e "  UUID/Password: $USER_UUID"
    echo -e "  Transport: WebSocket"
    echo -e "  Path: /$WSPATH"
    echo -e "  TLS: Enabled"
    echo ""
    echo -e "${CYAN}🛠️  Management Commands:${NC}"
    echo -e "  Status: ${YELLOW}systemctl status railway-proxy${NC}"
    echo -e "  Start: ${YELLOW}systemctl start railway-proxy${NC}"
    echo -e "  Stop: ${YELLOW}systemctl stop railway-proxy${NC}"
    echo -e "  Restart: ${YELLOW}systemctl restart railway-proxy${NC}"
    echo -e "  Logs: ${YELLOW}journalctl -u railway-proxy -f${NC}"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    cat > $WORKDIR/INFO.txt << INFO
Railway Proxy Deployment Info
==========================================
UUID: $USER_UUID
Domain: $DOMAIN
Port: $PORT
Path: /$WSPATH
Server IP: $SERVER_IP

Subscription: https://$DOMAIN/sub

Client Configuration:
- Protocol: VLESS/Trojan
- Address: $DOMAIN
- Port: 443
- UUID: $USER_UUID
- Transport: WebSocket
- Path: /$WSPATH
- TLS: Enabled

Management:
systemctl {status|start|stop|restart} railway-proxy
journalctl -u railway-proxy -f

Deployment time: $(date)
==========================================
INFO
}

# 主函数
main() {
    show_welcome
    detect_system
    check_permissions
    install_dependencies
    init_config
    create_workdir
    create_files
    create_env
    install_deps
    create_service
    start_service
    show_info
    echo ""
    print_success "🎉 Deployment complete! Service started successfully"
}

trap 'print_error "⚠️  Script execution error"' ERR
main "$@"
