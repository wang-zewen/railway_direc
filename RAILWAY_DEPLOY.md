# Railway 部署指南

## 方法一: 使用 Docker 镜像直接部署 (推荐)

### 步骤

1. **访问 Railway**
   - 登录 [Railway.app](https://railway.app)
   - 创建新项目 (New Project)

2. **选择部署方式**
   - 点击 "Deploy from Docker Image"
   - 输入镜像地址: `ghcr.io/你的GitHub用户名/railway-proxy:latest`

3. **配置环境变量**
   
   在 Railway 项目的 "Variables" 标签中添加以下环境变量:

   ```bash
   UUID=5efabea4-f6d4-91fd-b8f0-17e004c89c60  # 改成你自己的UUID
   PORT=8080                                   # 必须是8080
   DOMAIN=your-app.up.railway.app              # 等项目创建后填写
   WSPATH=api/data                             # 可选,自定义路径
   NAME=MyNode                                 # 可选,节点名称
   ```

4. **获取域名**
   - 部署完成后,在 "Settings" -> "Networking" 中查看分配的域名
   - 例如: `nodejs-production-22f5f.up.railway.app`
   - 将这个域名填入 `DOMAIN` 环境变量

5. **重新部署**
   - 修改环境变量后,点击 "Redeploy"

6. **测试连接**
   ```bash
   # 浏览器访问
   https://your-app.up.railway.app
   
   # 获取订阅
   https://your-app.up.railway.app/sub
   ```

## 方法二: 从 GitHub 仓库部署

### 步骤

1. **Fork 仓库**
   - 访问本项目的 GitHub 仓库
   - 点击右上角 "Fork" 按钮

2. **在 Railway 中连接 GitHub**
   - 登录 Railway
   - 创建新项目
   - 选择 "Deploy from GitHub repo"
   - 授权并选择你 fork 的仓库

3. **配置环境变量**
   
   添加相同的环境变量(同方法一)

4. **自动部署**
   - Railway 会自动检测 Dockerfile 并构建
   - 每次推送到 main 分支会自动重新部署

## 环境变量详解

### 必需变量

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `UUID` | 用户唯一标识 | `5efabea4-f6d4-91fd-b8f0-17e004c89c60` |
| `PORT` | 服务端口 (Railway必须8080) | `8080` |
| `DOMAIN` | 你的域名 | `your-app.up.railway.app` |

### 可选变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `NAME` | 节点名称 | 空 |
| `WSPATH` | WebSocket路径 | UUID前8位 |
| `SUB_PATH` | 订阅路径 | `sub` |
| `NEZHA_SERVER` | 哪吒监控服务器 | 空 |
| `NEZHA_PORT` | 哪吒监控端口 | 空 |
| `NEZHA_KEY` | 哪吒监控密钥 | 空 |

## 使用自定义域名

1. **在 Railway 中添加域名**
   - 进入 "Settings" -> "Networking"
   - 点击 "+ Custom Domain"
   - 输入你的域名

2. **配置 DNS**
   - 在你的域名提供商处添加 CNAME 记录
   - 指向 Railway 提供的地址

3. **更新环境变量**
   - 将 `DOMAIN` 改为你的自定义域名
   - 重新部署

## 获取订阅链接

部署成功后,访问:

```
https://your-domain.com/sub
```

返回的是 base64 编码的订阅内容,包含:
- VLESS 节点配置
- Trojan 节点配置

直接复制到支持订阅的客户端即可。

## 客户端配置示例

### V2rayN / V2rayNG

1. 添加订阅地址: `https://your-domain.com/sub`
2. 更新订阅即可使用

### Clash

手动配置节点:

```yaml
proxies:
  - name: "Railway-VLESS"
    type: vless
    server: your-domain.com
    port: 443
    uuid: 你的UUID
    network: ws
    tls: true
    ws-opts:
      path: /你的路径
```

## 常见问题

### 1. 无法连接?

检查清单:
- ✅ `PORT` 是否设置为 `8080`
- ✅ `DOMAIN` 是否正确
- ✅ Railway 的 Networking 是否显示 Port 8080
- ✅ 客户端是否启用了 TLS

### 2. 订阅链接无法获取?

- 检查 `SUB_PATH` 环境变量是否正确
- 确认服务已经成功部署
- 查看 Railway 的日志是否有错误

### 3. 域名被墙怎么办?

- 使用自定义域名并准备多个备用
- 或者直接使用 Railway 分配的 IP 地址
- 定期更换域名和路径

### 4. 如何获取 Railway 的 IP?

```bash
# 使用 nslookup
nslookup your-app.up.railway.app

# 使用 dig
dig your-app.up.railway.app +short
```

## 安全建议

1. ⚠️ **不要使用默认 UUID**
   - 生成自己的 UUID: `uuidgen` (Linux/Mac)
   - 在线生成: https://www.uuidgenerator.net/

2. ⚠️ **定期更换路径**
   - 修改 `WSPATH` 环境变量
   - 重新部署后更新客户端配置

3. ⚠️ **使用强随机路径**
   ```bash
   # 示例
   WSPATH=api/v2/data/stream
   WSPATH=ws/tunnel/secure
   ```

4. ⚠️ **启用哪吒监控**
   - 监控服务状态
   - 及时发现问题

## 高级配置

### 多节点部署

1. 部署多个 Railway 项目
2. 使用不同的 UUID 和路径
3. 合并订阅链接

### 负载均衡

可以配合 Cloudflare 的负载均衡功能:
1. 多个 Railway 实例
2. 相同的自定义域名
3. Cloudflare 自动分配流量

## 性能优化

- Railway 免费计划有流量限制
- 建议使用 Railway Pro 获得更好性能
- 或者部署到多个平台分散流量

## 问题排查

### 查看日志

在 Railway 的 "Deployments" 标签中:
1. 选择最新的部署
2. 点击 "View Logs"
3. 查看实时日志输出

### 常见错误

```
Error: listen EADDRINUSE
```
解决: 确保 PORT 环境变量设置正确

```
Server is running on port 8080
```
正常: 服务已成功启动

## 更新镜像

如果使用 Docker 镜像部署:

1. 等待 GitHub Actions 构建新镜像
2. 在 Railway 中重新部署
3. 或者手动触发重新拉取镜像

## 技术支持

遇到问题可以:
- 查看项目 README
- 检查 Railway 官方文档
- 查看 GitHub Issues

---

Happy Deploying! 🚀
