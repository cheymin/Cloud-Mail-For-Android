<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="Cloud Mail Logo">
</p>

<h1 align="center">Cloud Mail for Android</h1>

<p align="center">
  基于 <a href="https://github.com/cheymin/Cloud-Mail-For-Android">Cloud Mail API</a> 的现代化安卓邮件客户端，使用 Flutter 构建，支持 Material You 与 Apple 双主题风格。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-%3E%3D3.0.0-0175C2?logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/API-Cloud%20Mail-green" alt="Cloud Mail API">
  <img src="https://img.shields.io/badge/AI-OpenAI-412991?logo=openai" alt="OpenAI">
  <img src="https://img.shields.io/badge/翻译-LibreTranslate-00B386" alt="LibreTranslate">
</p>

---

## 功能一览

### 邮件

- **收件箱 / 已发送 / 星标 / 垃圾箱**：多文件夹邮件管理，支持分页加载与下拉刷新
- **全部邮件**：跨账户汇总所有收件，一处查看所有邮箱的新邮件
- **缓存优先加载**：进入页面先用本地缓存渲染，后台静默拉取最新数据，告别"加载半天"
- **邮件详情**：HTML 正文渲染、附件预览与下载、发件人头像、收发时间
- **双指缩放**：邮件正文支持双指捏合自由缩放（单指正常滚动，互不干扰），可在设置中关闭
- **长按复制**：SelectionArea 包裹全文，长按弹出系统级 复制 / 分享 / 全选 菜单
- **一键翻译**：调用 LibreTranslate 免费 API 翻译全文为中文，无需配置；也可回退 AI 翻译
- **写邮件**：全屏编辑界面，支持回复 / 转发、添加图片与附件
- **搜索**：按主题、发件人、正文模糊搜索

### AI 助手

- ChatGPT 风格对话界面，发送消息后显示"思考反馈"
- 兼容 OpenAI Chat Completions API，可自定义 Base URL 与模型
- 支持拉取上游可用模型列表
- 对话历史本地保存，可随时清空

### 联系人

- 本地存储，按首字母分组展示，支持搜索
- 新增 / 编辑 / 删除联系人，查看详情并发起写信
- **快速导入**：
  - 批量粘贴文本（支持 `姓名 <邮箱>`、`姓名,邮箱`、纯邮箱等格式）
  - 从文件导入 vCard（.vcf）/ CSV（.csv）
- **WebDAV 云同步**：配置 WebDAV 服务器后可在多设备间同步联系人和应用设置

### 个性化

- **主题色**：9 色预设，支持自定义
- **字体**：内置系统字体 + **导入自定义字体**（.ttf / .otf，持久化保存）
- **背景图**：从相册选择自定义背景
- **界面风格**：Google 风（Material You，密集列表、pill 按钮）/ Apple 风（Mimestream，留白、圆形头像）
- **深色模式**：跟随系统 / 强制浅色 / 强制深色
- **毛玻璃效果**：联系人详情等弹层使用 BackdropFilter 毛玻璃

### 账户与安全

- 多邮箱账户管理，一键切换当前发件账户
- Token 本地加密存储
- 退出登录一键清除本地凭证

### 应用更新

- 启动时检查 GitHub Releases 最新版本
- 列出所有已发布版本，用户手动选择下载
- **GitHub 镜像加速**：下载时可选直连 / ghproxy / moeyy / kkgithub 等镜像，自动测速
- **应用内下载**：进度条显示、下载完成自动弹出安装

---

## 技术栈

| 项目 | 说明 |
|------|------|
| 框架 | Flutter (Dart SDK >= 3.0.0) |
| 状态管理 | Provider |
| 本地存储 | SharedPreferences（邮件缓存 + 联系人 + 个性化配置） |
| 网络请求 | http / dio |
| HTML 渲染 | flutter_widget_from_html_core |
| 附件选择 | image_picker + file_picker |
| 字体动态加载 | FontLoader |
| 应用更新 | GitHub Releases API + dio 下载 |
| 云同步 | WebDAV（MKCOL / PROPFIND） |
| AI | OpenAI 兼容 Chat Completions API |
| 翻译 | LibreTranslate 免费公共 API |
| 持续集成 | GitHub Actions（tag `v*` 触发构建发布） |

---

## 项目结构

```
lib/
├── main.dart                          # 应用入口 + 主题配置 + 路由
├── models/
│   ├── email.dart                     # 邮件 / 账户 数据模型
│   └── contact.dart                   # 联系人模型 + ContactStore 本地存储
├── screens/
│   ├── login_screen.dart              # 登录页
│   ├── email/
│   │   ├── mailbox_screen.dart        # 邮件列表（多文件夹 + 缓存）
│   │   ├── email_detail_screen.dart   # 邮件详情（HTML + 缩放 + 复制 + 翻译）
│   │   └── compose_screen.dart        # 写邮件（全屏）
│   ├── contacts/
│   │   └── contacts_screen.dart       # 联系人（分组 + 搜索 + 导入）
│   ├── ai/
│   │   └── ai_screen.dart             # AI 助手（ChatGPT 风格）
│   ├── accounts/
│   │   └── account_screen.dart        # 账户管理
│   ├── settings/
│   │   └── settings_screen.dart       # 设置（个性化 + AI + WebDAV + 关于）
│   └── update/
│       └── update_screen.dart         # 应用更新（版本列表 + 镜像下载）
├── services/
│   ├── api_service.dart               # Cloud Mail API 封装
│   ├── ai_service.dart                # AI 服务（OpenAI 兼容）
│   ├── translate_service.dart         # 翻译服务（LibreTranslate）
│   ├── update_service.dart            # GitHub Releases 更新检测
│   ├── webdav_service.dart            # WebDAV 服务
│   ├── app_sync.dart                  # 应用设置云同步
│   └── contact_sync.dart              # 联系人云同步
└── utils/
    ├── storage.dart                   # SharedPreferences 封装
    ├── theme.dart                     # 主题（Google/Apple 双风格 + 个性化）
    └── glass.dart                     # 毛玻璃效果
```

---

## 快速开始

### 环境要求

- Flutter 3.x
- Dart SDK >= 3.0.0
- Android Studio 或 VS Code

### 构建运行

```bash
# 安装依赖
flutter pub get

# 调试运行
flutter run

# 构建 Release APK
flutter build apk --release
```

### 使用

1. 首次启动输入 Cloud Mail 服务器地址（Base URL）
2. 用邮箱密码登录，自动生成并保存 Token
3. 进入邮件列表即可收发邮件
4. 在设置中配置 AI 助手、个性化、WebDAV 同步等

---

## 配置说明

### AI 助手

在「设置 → AI 助手」中配置：

- **API Key**：OpenAI 或兼容服务的密钥
- **API 地址**：默认 `https://api.openai.com/v1`，可填第三方兼容服务
- **模型**：点击「拉取模型」从上游获取可用模型列表

### WebDAV 云同步

在「设置 → 云同步」中配置：

- 服务器地址（如 `https://dav.example.com/remote.php/dav/files/user`）
- 用户名 / 应用密码
- 远程目录（默认 `/CloudMail`）

配置后可「测试连接」、「上传配置」或「拉取配置」。

---

## 持续集成

项目配置了 GitHub Actions（`.github/workflows/build.yml`）：

- 推送 `v*` 格式的 tag 自动触发构建
- 编译 Release APK 并发布到 GitHub Releases
- 用户在应用内「检查更新」即可看到新版本并下载

```bash
# 发布新版本
git tag v4.5.4
git push origin v4.5.4
```

---

## License

本项目仅供学习和参考使用。

---

Made with Flutter
