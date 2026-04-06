# Netlify VPN转发服务

一个部署在Netlify上的VPN转发服务，自动生成Clash配置文件，导入本地Clash客户端即可使用。

## 功能特性

- 🚀 **一键配置** - 注册即可获取Clash配置文件
- 📥 **下载配置** - 下载yaml配置文件导入Clash
- 📋 **订阅链接** - 支持Clash订阅链接自动更新
- 📊 **流量统计** - 实时显示已用/剩余流量
- 🔄 **自动重置** - 每月1号自动重置流量统计
- 🎨 **美观后台** - 现代化深色主题管理界面

## 部署步骤

### 1. Fork或克隆本项目

```bash
git clone https://github.com/your-username/netlify-vpn-proxy.git
cd netlify-vpn-proxy
```

### 2. 安装依赖

```bash
npm install
```

### 3. 部署到Netlify

#### 方法一：通过Netlify CLI

```bash
# 安装Netlify CLI
npm install -g netlify-cli

# 登录Netlify
netlify login

# 创建新站点
netlify init

# 部署
netlify deploy --prod
```

#### 方法二：通过GitHub自动部署

1. 将代码推送到GitHub仓库
2. 登录 [Netlify](https://app.netlify.com)
3. 点击 "Add new site" → "Import an existing project"
4. 选择你的GitHub仓库
5. 构建设置保持默认即可
6. 点击 "Deploy site"

## 使用方法

### 1. 访问管理后台

部署完成后，访问你的站点URL进入管理后台。

### 2. 注册获取配置

点击"立即注册获取配置"按钮，系统会为你生成专属的Clash配置。

### 3. 下载配置文件

点击"下载配置文件"按钮，将`vpn-config.yaml`保存到本地。

### 4. 导入Clash客户端

打开Clash客户端（Clash for Windows / ClashX / Clash for Android等）：
- 选择"配置" → "导入配置文件"
- 选择下载的`vpn-config.yaml`文件

### 5. 开启代理

在Clash中选择导入的代理节点，开启系统代理即可使用。

## 订阅链接

你也可以使用订阅链接在Clash中添加订阅：

1. 复制订阅链接
2. 在Clash客户端中选择"配置" → "添加订阅"
3. 粘贴订阅链接并更新

订阅链接格式：
```
https://your-site.netlify.app/.netlify/functions/proxy/subscribe?user_id=YOUR_USER_ID
```

## API接口

### 注册用户

```
POST /.netlify/functions/proxy/register
```

响应示例：
```json
{
  "success": true,
  "userId": "abc123xyz",
  "userName": "VPN-abc123",
  "subscribeUrl": "https://your-site.netlify.app/.netlify/functions/proxy/subscribe?user_id=abc123xyz",
  "configDownloadUrl": "https://your-site.netlify.app/.netlify/functions/proxy/config?user_id=abc123xyz",
  "clashConfig": "port: 7890\n..."
}
```

### 下载配置文件

```
GET /.netlify/functions/proxy/config?user_id=YOUR_USER_ID
```

返回YAML格式的Clash配置文件。

### 订阅链接

```
GET /.netlify/functions/proxy/subscribe?user_id=YOUR_USER_ID
```

返回Base64编码的配置文件，可用于Clash订阅。

### 获取流量统计

```
GET /.netlify/functions/admin/stats
```

响应示例：
```json
{
  "used": 1073741824,
  "usedFormatted": "1 GB",
  "remaining": 107374182400,
  "remainingFormatted": "100 GB",
  "total": 108447924224,
  "totalFormatted": "101 GB",
  "percentage": 0.99,
  "requests": 150,
  "resetDate": "2024-02-01T00:00:00.000Z",
  "resetDateFormatted": "2024年2月1日 00:00",
  "daysUntilReset": 15
}
```

## 生成的Clash配置示例

```yaml
port: 7890
socks-port: 7891
mixed-port: 7892
allow-lan: true
mode: rule
log-level: info
external-controller: 127.0.0.1:9090

proxies:
  - name: "VPN-abc123"
    type: http
    server: your-site.netlify.app
    port: 443
    tls: true
    headers:
      X-User-ID: abc123xyz

proxy-groups:
  - name: "Proxy"
    type: select
    proxies:
      - "VPN-abc123"
      - DIRECT

rules:
  - MATCH,Proxy
```

## 流量说明

- Netlify免费套餐提供 **100GB/月** 的带宽
- 流量统计每月1号自动重置
- 当流量用尽时，代理服务将返回 429 错误

## 注意事项

1. **用户ID**：请妥善保管你的用户ID，可用于恢复配置
2. **流量限制**：注意监控流量使用情况，避免超出免费额度
3. **合规使用**：请遵守当地法律法规，合法使用本服务

## 项目结构

```
netlify-vpn-proxy/
├── netlify/
│   └── functions/
│       ├── proxy.js      # 代理转发核心 + 配置生成
│       └── admin.js      # 流量统计API
├── public/
│   └── index.html        # 管理后台界面
├── netlify.toml          # Netlify配置
├── package.json
└── README.md
```

## 技术栈

- **前端**: 原生HTML/CSS/JavaScript
- **后端**: Netlify Functions (Node.js)
- **存储**: Netlify Blobs
- **HTTP客户端**: node-fetch

## 许可证

MIT License
