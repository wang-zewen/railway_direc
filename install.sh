#!/bin/bash

# Railway Proxy 一键部署脚本
# 用途: 直接在服务器上部署 VLESS & Trojan 代理
#
# ============================================
# 使用方法
# ============================================
#
# 方法1: 交互式安装 (推荐新手)
#   curl -fsSL https://raw.githubusercontent.com/yourname/repo/main/install.sh | bash
#   或
#   wget -qO- https://raw.githubusercontent.com/yourname/repo/main/install.sh | bash
#
# 方法2: 一键安装 (通过环境变量)
#   curl -fsSL https://url/install.sh | UUID=your-uuid DOMAIN=your-domain.com bash
#
# 方法3: 完全自定义安装
#   curl -fsSL https://url/install.sh | \
#     UUID=5efabea4-f6d4-91fd-b8f0-17e004c89c60 \
#     DOMAIN=your-app.up.railway.app \
#     PORT=8080 \
#     WSPATH=api/v2/ws \
#     NAME=MyNode \
#     bash
#
# ============================================
# 环境变量说明
# ============================================
#
# 必需变量:
#   DOMAIN         - 域名 (必填,无默认值)
#                    示例: your-app.up.railway.app
#
# 可选变量:
#   UUID           - 用户标识 (默认: 自动生成)
#                    示例: 5efabea4-f6d4-91fd-b8f0-17e004c89c60
#
#   PORT           - 服务端口 (默认: 8080)
#                    示例: 8080
#
#   WSPATH         - WebSocket路径 (默认: UUID前8位)
#                    示例: api/v2/ws 或 5efabea4
#
#   NAME           - 节点名称 (默认: 空)
#                    示例: MyNode 或 HK-Server
#
#   NEZHA_SERVER   - 哪吒服务器 (默认: 空,不启用)
#                    示例: nz.example.com:8008
#
#   NEZHA_KEY      - 哪吒密钥 (默认: 空)
#                    示例: your_nezha_key
#
# ============================================
# 使用示例
# ============================================
#
# 示例1: 最简单的安装 (只指定域名,其他自动生成)
#   curl -fsSL https://url/install.sh | DOMAIN=my-app.up.railway.app bash
#
# 示例2: 指定UUID和域名
#   curl -fsSL https://url/install.sh | \
#     UUID=$(uuidgen | tr '[:upper:]' '[:lower:]') \
#     DOMAIN=my-app.up.railway.app \
#     bash
#
# 示例3: 完整配置
#   curl -fsSL https://url/install.sh | \
#     UUID=5efabea4-f6d4-91fd-b8f0-17e004c89c60 \
#     DOMAIN=proxy.example.com \
#     PORT=8080 \
#     WSPATH=secure/tunnel \
#     NAME=US-Server-01 \
#     NEZHA_SERVER=nz.example.com:8008 \
#     NEZHA_KEY=your_key_here \
#     bash
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
        print_error "无法检测系统类型"
        exit 1
    fi
    
    print_info "检测到系统: $OS $VERSION"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_warning "建议使用 root 用户运行此脚本"
        print_info "如需切换: sudo su"
        read -p "是否继续? (y/n): " continue
        if [[ ! $continue =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 安装依赖
install_dependencies() {
    print_info "正在安装依赖..."
    
    case $OS in
        ubuntu|debian)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq > /dev/null 2>&1
            apt-get install -y -qq curl wget git > /dev/null 2>&1
            
            # 安装 Node.js
            if ! command -v node &> /dev/null; then
                curl -fsSL https://deb.nodesource.com/setup_18.x | bash - > /dev/null 2>&1
                apt-get install -y -qq nodejs > /dev/null 2>&1
            fi
            ;;
        centos|rhel|fedora)
            yum install -y -q curl wget git > /dev/null 2>&1
            
            # 安装 Node.js
            if ! command -v node &> /dev/null; then
                curl -fsSL https://rpm.nodesource.com/setup_18.x | bash - > /dev/null 2>&1
                yum install -y -q nodejs > /dev/null 2>&1
            fi
            ;;
        alpine)
            apk add --no-cache curl wget git nodejs npm > /dev/null 2>&1
            ;;
        *)
            print_error "不支持的系统: $OS"
            exit 1
            ;;
    esac
    
    print_success "依赖安装完成"
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

# 收集配置
collect_config() {
    print_info "开始配置参数..."
    echo ""
    
    # 检查是否为非交互模式 (所有必需变量都已设置)
    if [ -n "$UUID" ] && [ -n "$DOMAIN" ]; then
        print_info "检测到环境变量,使用非交互模式"
        USER_UUID=${UUID}
        PORT=${PORT:-8080}
        WSPATH=${WSPATH:-${USER_UUID:0:8}}
        NODE_NAME=${NAME:-""}
        NEZHA_SERVER=${NEZHA_SERVER:-""}
        NEZHA_KEY=${NEZHA_KEY:-""}
        
        # 显示配置但不需要确认
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}配置信息:${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  UUID: ${CYAN}$USER_UUID${NC}"
        echo -e "  域名: ${CYAN}$DOMAIN${NC}"
        echo -e "  端口: ${CYAN}$PORT${NC}"
        echo -e "  路径: ${CYAN}/$WSPATH${NC}"
        echo -e "  名称: ${CYAN}${NODE_NAME:-未设置}${NC}"
        if [ -n "$NEZHA_SERVER" ]; then
            echo -e "  哪吒: ${CYAN}已配置${NC}"
        fi
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        return
    fi
    
    # 交互模式
    # UUID
    if [ -z "$UUID" ]; then
        echo -e "${CYAN}请输入 UUID (留空自动生成):${NC}"
        read -p "> " USER_UUID
        if [ -z "$USER_UUID" ]; then
            USER_UUID=$(generate_uuid)
            print_success "已生成 UUID: $USER_UUID"
        fi
    else
        USER_UUID=$UUID
        print_info "使用环境变量 UUID: $USER_UUID"
    fi
    
    # 域名
    if [ -z "$DOMAIN" ]; then
        echo -e "${CYAN}请输入域名 (必填):${NC}"
        echo -e "${YELLOW}提示: Railway会自动分配域名,如 your-app.up.railway.app${NC}"
        read -p "> " DOMAIN
        while [ -z "$DOMAIN" ]; do
            print_error "域名不能为空!"
            read -p "> " DOMAIN
        done
    else
        print_info "使用环境变量 DOMAIN: $DOMAIN"
    fi
    
    # 端口
    if [ -z "$PORT" ]; then
        echo -e "${CYAN}请输入服务端口 (默认 8080):${NC}"
        read -p "> " input_port
        PORT=${input_port:-8080}
    else
        PORT=${PORT:-8080}
        print_info "使用端口: $PORT"
    fi
    
    # WebSocket 路径
    if [ -z "$WSPATH" ]; then
        echo -e "${CYAN}请输入 WebSocket 路径 (默认使用UUID前8位):${NC}"
        read -p "> " WSPATH
        if [ -z "$WSPATH" ]; then
            WSPATH=${USER_UUID:0:8}
        fi
    else
        print_info "使用 WebSocket 路径: /$WSPATH"
    fi
    
    # 节点名称
    if [ -z "$NAME" ]; then
        echo -e "${CYAN}请输入节点名称 (可选):${NC}"
        read -p "> " NODE_NAME
    else
        NODE_NAME=$NAME
        print_info "使用节点名称: $NODE_NAME"
    fi
    
    # 哪吒监控
    if [ -z "$NEZHA_SERVER" ]; then
        echo -e "${CYAN}是否配置哪吒监控? (y/n, 默认n):${NC}"
        read -p "> " use_nezha
        if [[ $use_nezha =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}哪吒服务器地址 (例: nz.abc.com:8008):${NC}"
            read -p "> " NEZHA_SERVER
            
            echo -e "${CYAN}哪吒密钥:${NC}"
            read -p "> " NEZHA_KEY
        fi
    else
        print_info "使用哪吒监控配置"
    fi
    
    # 确认配置
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}配置信息确认:${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  UUID: ${CYAN}$USER_UUID${NC}"
    echo -e "  域名: ${CYAN}$DOMAIN${NC}"
    echo -e "  端口: ${CYAN}$PORT${NC}"
    echo -e "  路径: ${CYAN}/$WSPATH${NC}"
    echo -e "  名称: ${CYAN}${NODE_NAME:-未设置}${NC}"
    if [ -n "$NEZHA_SERVER" ]; then
        echo -e "  哪吒: ${CYAN}已配置${NC}"
    fi
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    read -p "确认以上信息? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_error "用户取消"
        exit 1
    fi
}

# 创建工作目录
create_workdir() {
    WORKDIR="/opt/railway-proxy"
    
    if [ -d "$WORKDIR" ]; then
        print_warning "目录已存在,正在备份..."
        mv "$WORKDIR" "${WORKDIR}.backup.$(date +%s)"
    fi
    
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"
    
    print_success "工作目录创建: $WORKDIR"
}

# 创建项目文件
create_files() {
    print_info "正在创建项目文件..."
    
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

    print_success "项目文件创建完成"
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
    print_success "配置文件创建完成"
}

# 安装依赖
install_deps() {
    print_info "正在安装 Node.js 依赖..."
    npm install --production > /dev/null 2>&1
    print_success "依赖安装完成"
}

# 创建 systemd 服务
create_service() {
    print_info "正在创建系统服务..."
    
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
    print_success "系统服务创建完成"
}

# 启动服务
start_service() {
    print_info "正在启动服务..."
    systemctl restart railway-proxy
    sleep 2
    
    if systemctl is-active --quiet railway-proxy; then
        print_success "服务启动成功"
    else
        print_error "服务启动失败,查看日志: journalctl -u railway-proxy -f"
        exit 1
    fi
}

# 显示信息
show_info() {
    local IP=$(curl -s ip.sb 2>/dev/null || echo "unknown")
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}         🎉 部署完成!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}服务信息:${NC}"
    echo -e "  UUID: ${YELLOW}$USER_UUID${NC}"
    echo -e "  域名: ${YELLOW}$DOMAIN${NC}"
    echo -e "  端口: ${YELLOW}$PORT${NC}"
    echo -e "  路径: ${YELLOW}/$WSPATH${NC}"
    echo -e "  服务器IP: ${YELLOW}$IP${NC}"
    echo ""
    echo -e "${CYAN}订阅地址:${NC}"
    echo -e "  ${YELLOW}https://$DOMAIN/sub${NC}"
    echo ""
    echo -e "${CYAN}客户端配置:${NC}"
    echo -e "  协议: VLESS/Trojan"
    echo -e "  地址: $DOMAIN"
    echo -e "  端口: 443"
    echo -e "  UUID/密码: $USER_UUID"
    echo -e "  传输: WebSocket"
    echo -e "  路径: /$WSPATH"
    echo -e "  TLS: 开启"
    echo ""
    echo -e "${CYAN}管理命令:${NC}"
    echo -e "  状态: ${YELLOW}systemctl status railway-proxy${NC}"
    echo -e "  启动: ${YELLOW}systemctl start railway-proxy${NC}"
    echo -e "  停止: ${YELLOW}systemctl stop railway-proxy${NC}"
    echo -e "  重启: ${YELLOW}systemctl restart railway-proxy${NC}"
    echo -e "  日志: ${YELLOW}journalctl -u railway-proxy -f${NC}"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    cat > $WORKDIR/INFO.txt << INFO
Railway Proxy 部署信息
==========================================
UUID: $USER_UUID
域名: $DOMAIN
端口: $PORT
路径: /$WSPATH
IP: $IP

订阅: https://$DOMAIN/sub

客户端配置:
- 协议: VLESS/Trojan
- 地址: $DOMAIN
- 端口: 443
- UUID: $USER_UUID
- 传输: WebSocket
- 路径: /$WSPATH
- TLS: 开启

管理:
systemctl {status|start|stop|restart} railway-proxy
journalctl -u railway-proxy -f

部署时间: $(date)
==========================================
INFO
}

# 主函数
main() {
    show_welcome
    detect_system
    check_root
    install_dependencies
    collect_config
    create_workdir
    create_files
    create_env
    install_deps
    create_service
    start_service
    show_info
    echo ""
    print_success "部署完成! 服务已启动并设置为开机自启"
}

trap 'print_error "脚本执行出错"' ERR
main "$@"
