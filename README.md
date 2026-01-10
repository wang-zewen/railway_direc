# Railway Proxy Docker

一个支持VLESS和Trojan协议的代理服务器,适用于Railway等容器平台部署。

## 特性

- ✅ 支持 VLESS 和 Trojan 协议
- ✅ WebSocket 传输
- ✅ 自动生成订阅链接
- ✅ 支持自定义域名
- ✅ 内置网页伪装
- ✅ 支持哪吒监控

## Docker 镜像使用

### 从 GitHub Container Registry 拉取

```bash
docker pull ghcr.io/你的用户名/railway-proxy:latest
```

### 运行容器

```bash
docker run -d \
  -p 8080:8080 \
  -e UUID=你的UUID \
  -e DOMAIN=你的域名 \
  -e PORT=8080 \
  ghcr.io/你的用户名/railway-proxy:latest
```

## Railway 部署

### 方法1: 使用 GitHub 仓库

1. Fork 本仓库到你的 GitHub
2. 在 Railway 中选择 "Deploy from GitHub repo"
3. 选择你 fork 的仓库
4. 设置环境变量后部署

### 方法2: 使用 Docker 镜像

1. 在 Railway 创建新项目
2. 选择 "Deploy from Docker Image"
3. 输入镜像地址: `ghcr.io/你的用户名/railway-proxy:latest`
4. 设置环境变量
5. 部署完成

## 环境变量配置

必需变量:
- `UUID`: 你的唯一标识符 (默认: 随机生成)
- `DOMAIN`: 你的域名或 Railway 分配的域名
- `PORT`: 服务端口 (Railway 必须设置为 8080)

可选变量:
- `NAME`: 节点名称
- `WSPATH`: WebSocket 路径 (默认: UUID前8位)
- `SUB_PATH`: 订阅路径 (默认: sub)
- `NEZHA_SERVER`: 哪吒监控服务器地址
- `NEZHA_PORT`: 哪吒监控端口
- `NEZHA_KEY`: 哪吒监控密钥

## 获取订阅

访问以下地址获取 base64 编码的订阅:

```
https://你的域名/sub
```

## Railway 环境变量示例

```bash
UUID=5efabea4-f6d4-91fd-b8f0-17e004c89c60
DOMAIN=your-app.up.railway.app
PORT=8080
WSPATH=api/data
NAME=MyNode
```

## 客户端配置

### VLESS

- 地址: `你的域名`
- 端口: `443`
- UUID: `你设置的UUID`
- 传输协议: `WebSocket`
- 路径: `/你设置的WSPATH`
- TLS: `启用`

### Trojan

- 地址: `你的域名`
- 端口: `443`
- 密码: `你设置的UUID`
- 传输协议: `WebSocket`
- 路径: `/你设置的WSPATH`
- TLS: `启用`

## 本地构建

```bash
# 克隆仓库
git clone https://github.com/你的用户名/railway-proxy.git
cd railway-proxy

# 构建镜像
docker build -t railway-proxy .

# 运行容器
docker run -d -p 8080:8080 \
  -e UUID=你的UUID \
  -e DOMAIN=localhost \
  railway-proxy
```

## 发布到 GitHub Container Registry

```bash
# 登录
echo $GITHUB_TOKEN | docker login ghcr.io -u 你的用户名 --password-stdin

# 构建并打标签
docker build -t ghcr.io/你的用户名/railway-proxy:latest .

# 推送镜像
docker push ghcr.io/你的用户名/railway-proxy:latest
```

## 安全建议

1. 使用强随机 UUID
2. 定期更换域名和路径
3. 启用 TLS 加密
4. 限制访问频率
5. 不要在生产环境使用默认配置

## 注意事项

- Railway 的 Public Networking 端口必须设置为 8080
- 确保环境变量中的 PORT 设置为 8080
- DOMAIN 必须设置为你的实际域名或 Railway 分配的域名
- 使用前请检查当地法律法规

## License

MIT
