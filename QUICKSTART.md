# 🚀 快速开始指南

## 第一步: 准备 GitHub 仓库

1. **创建新的 GitHub 仓库**
   - 登录 GitHub
   - 点击右上角 "+" -> "New repository"
   - 仓库名: `railway-proxy` (或其他名称)
   - 可见性: Public 或 Private
   - 不勾选任何初始化选项
   - 点击 "Create repository"

2. **上传代码到 GitHub**

   在本地终端执行:

   ```bash
   # 初始化 Git 仓库
   cd /path/to/proxy-docker
   git init
   git add .
   git commit -m "Initial commit"
   
   # 关联远程仓库(替换为你的仓库地址)
   git remote add origin https://github.com/你的用户名/railway-proxy.git
   
   # 推送代码
   git branch -M main
   git push -u origin main
   ```

## 第二步: 配置 GitHub Actions

代码推送后,GitHub Actions 会自动:
1. 构建 Docker 镜像
2. 推送到 GitHub Container Registry (ghcr.io)

**查看构建进度:**
- 访问你的仓库
- 点击 "Actions" 标签
- 等待构建完成 (绿色勾号✅)

**构建完成后,镜像地址为:**
```
ghcr.io/你的用户名/railway-proxy:latest
```

## 第三步: 设置镜像为公开

默认情况下,GHCR 镜像是私有的,需要设置为公开:

1. 访问你的 GitHub 个人资料页
2. 点击 "Packages" 标签
3. 找到 `railway-proxy` 包
4. 点击进入包详情页
5. 点击右侧 "Package settings"
6. 滚动到底部,找到 "Change visibility"
7. 选择 "Public"
8. 确认更改

## 第四步: 部署到 Railway

### 选项 A: 使用 Docker 镜像 (推荐)

1. **登录 Railway**
   - 访问 [railway.app](https://railway.app)
   - 使用 GitHub 账号登录

2. **创建新项目**
   - 点击 "New Project"
   - 选择 "Deploy from Docker Image"

3. **输入镜像地址**
   ```
   ghcr.io/你的用户名/railway-proxy:latest
   ```

4. **等待部署完成**
   - Railway 会自动拉取镜像并部署

5. **配置环境变量**
   
   点击项目 -> "Variables" 标签,添加:
   
   ```bash
   UUID=5efabea4-f6d4-91fd-b8f0-17e004c89c60  # 改成你的UUID
   PORT=8080
   DOMAIN=your-app.up.railway.app  # 暂时先不填,等获取域名后再填
   ```

6. **获取域名**
   - 点击 "Settings" -> "Networking"
   - 查看 "Public Networking" 下的域名
   - 例如: `nodejs-production-22f5f.up.railway.app`

7. **更新 DOMAIN 变量**
   - 返回 "Variables" 标签
   - 修改 `DOMAIN` 为上一步获取的域名
   - 点击项目右上角的 "Redeploy"

### 选项 B: 从 GitHub 仓库部署

1. 登录 Railway
2. 点击 "New Project" -> "Deploy from GitHub repo"
3. 授权并选择你的 `railway-proxy` 仓库
4. Railway 会自动检测 Dockerfile 并构建
5. 配置环境变量(同上)

## 第五步: 测试连接

1. **访问网页**
   ```
   https://your-app.up.railway.app/
   ```
   应该看到欢迎页面

2. **获取订阅**
   ```
   https://your-app.up.railway.app/sub
   ```
   会返回 base64 编码的订阅内容

3. **配置客户端**
   
   **方法1: 使用订阅链接**
   - 复制订阅地址
   - 在客户端(V2rayN/V2rayNG)中添加订阅
   - 更新订阅

   **方法2: 手动配置**
   - 协议: VLESS 或 Trojan
   - 地址: `your-app.up.railway.app`
   - 端口: `443`
   - UUID: `你设置的UUID`
   - 传输: WebSocket
   - 路径: `/你的WSPATH` (默认是UUID前8位)
   - TLS: 启用

## 环境变量说明

| 变量 | 必需 | 默认值 | 说明 |
|------|------|--------|------|
| `UUID` | ✅ | 随机生成 | 用户标识,建议自己生成 |
| `PORT` | ✅ | 8080 | Railway必须设为8080 |
| `DOMAIN` | ✅ | - | Railway分配的域名 |
| `WSPATH` | ❌ | UUID前8位 | WebSocket路径 |
| `NAME` | ❌ | - | 节点名称 |
| `SUB_PATH` | ❌ | sub | 订阅路径 |

## 生成 UUID

**Linux/Mac:**
```bash
uuidgen | tr '[:upper:]' '[:lower:]'
```

**Windows PowerShell:**
```powershell
[guid]::NewGuid().ToString()
```

**在线生成:**
https://www.uuidgenerator.net/

## 故障排查

### 问题1: 部署失败

**检查:**
- GitHub Actions 是否构建成功?
- 镜像是否设置为公开?
- Railway 日志中的错误信息?

### 问题2: 无法访问网页

**检查:**
- DOMAIN 环境变量是否正确?
- PORT 是否设为 8080?
- Railway 的 Networking 是否显示 Port 8080?

### 问题3: 客户端无法连接

**检查:**
- UUID 是否正确?
- 路径是否正确? (查看 WSPATH 变量)
- TLS 是否启用?
- 端口是否设为 443?

### 问题4: 订阅链接无法获取

**检查:**
- 访问 `https://你的域名/sub` 是否正常?
- SUB_PATH 环境变量是否正确?
- 服务是否正常运行? (查看 Railway 日志)

## 查看日志

Railway 日志查看方法:
1. 进入项目
2. 点击 "Deployments"
3. 选择最新的部署
4. 点击 "View Logs"

正常日志应该显示:
```
Server is running on port 8080
```

## 下一步

✅ 部署成功后,可以:

1. **配置自定义域名**
   - 在 Railway 中添加自定义域名
   - 更新 DOMAIN 环境变量
   - 准备多个域名轮换

2. **优化安全性**
   - 使用强随机 UUID
   - 自定义 WSPATH 路径
   - 定期更换配置

3. **添加监控**
   - 配置哪吒监控
   - 实时监控服务状态

4. **多节点部署**
   - 部署多个实例
   - 不同地区/平台
   - 提高可用性

## 需要帮助?

- 📖 阅读完整的 [README.md](README.md)
- 🚂 查看 [Railway 部署指南](RAILWAY_DEPLOY.md)
- 💡 在 GitHub Issues 提问

---

祝你部署顺利! 🎉
