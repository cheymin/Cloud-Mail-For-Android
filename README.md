# Cloud Mail Android App

这是一个支持 Cloud Mail API 的 Android 应用，提供邮件管理和用户管理功能。

## 功能特性

- **用户登录**: 使用邮箱和密码生成认证 Token
- **邮件列表**: 查看收件和发件邮件列表，支持分页和下拉刷新
- **邮件详情**: 显示邮件主题、发件人、收件人、时间等详细信息
- **添加用户**: 支持添加新用户账户
- **模糊搜索**: 支持邮件的模糊匹配搜索

## 技术栈

- **语言**: Kotlin
- **最低 SDK**: Android 6.0 (API 24)
- **目标 SDK**: Android 14 (API 34)
- **架构**: MVVM
- **网络库**: Retrofit + OkHttp + Gson
- **异步处理**: Kotlin Coroutines
- **UI 组件**: RecyclerView, SwipeRefreshLayout, Material Design

## 项目结构

```
CloudMailApp/
├── app/
│   ├── src/main/
│   │   ├── java/com/cloudmail/app/
│   │   │   ├── api/              # API 接口定义
│   │   │   │   ├── CloudMailApi.kt
│   │   │   │   └── RetrofitClient.kt
│   │   │   ├── model/            # 数据模型
│   │   │   │   └ Models.kt
│   │   │   ├── utils/            # 工具类
│   │   │   │   ├── SharedPreferencesManager.kt
│   │   │   ├── LoginActivity.kt  # 登录页面
│   │   │   ├── MainActivity.kt   # 主页面
│   │   │   ├── AddUserActivity.kt # 添加用户页面
│   │   │   ├── EmailAdapter.kt   # 邮件列表适配器
│   │   ├── res/                  # 资源文件
│   │   ├── AndroidManifest.xml
│   ├── build.gradle.kts
│   ├── proguard-rules.pro
├── gradle/
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
```

## Cloud Mail API 接口

应用集成了以下 Cloud Mail API 接口：

### 1. 生成 Token
- **接口**: POST `/api/public/genToken`
- **用途**: 用户登录认证
- **参数**: email, password
- **返回**: token

### 2. 邮件查询
- **接口**: POST `/api/public/emailList`
- **用途**: 查询邮件列表
- **参数**: toEmail, sendName, sendEmail, subject, content, timeSort, type, isDel, num, size
- **返回**: 邮件列表数据

### 3. 添加用户
- **接口**: POST `/api/public/addUser`
- **用途**: 添加新邮箱用户
- **参数**: list (用户数组)
- **返回**: 操作结果

## 如何使用

### 1. 配置服务器地址
在登录页面输入您的 Cloud Mail 服务 Base URL（例如：`https://your-domain.com/`）

### 2. 登录
输入管理员邮箱和密码进行登录，系统会自动生成并保存 Token

### 3. 查看邮件
登录成功后会显示邮件列表，支持：
- 下拉刷新
- 自动分页加载
- 显示收件/发件状态
- 显示邮件详情预览

### 4. 添加用户
点击右上角"Add User"按钮，输入邮箱地址和可选的密码、角色信息

## 构建和运行

### 环境要求
- Android Studio Arctic Fox 或更高版本
- JDK 8 或更高版本
- Android SDK API 24+

### 构建步骤
1. 克隆项目到本地
2. 使用 Android Studio 打开项目
3. 等待 Gradle 同步完成
4. 点击 Run 按钮 or 使用命令：
   ```bash
   ./gradlew assembleDebug
   ```

### 安装到设备
```bash
./gradlew installDebug
```

## 配置说明

### Retrofit 配置
在 `RetrofitClient.kt` 中可以修改：
- Base URL（默认值）
- 连接超时时间
- 日志级别

### SharedPreferences
应用使用 SharedPreferences 存储：
- 用户 Token
- 用户邮箱
- 服务器 Base URL

## 权限要求

应用需要以下权限：
- `INTERNET`: 网络访问
- `ACCESS_NETWORK_STATE`: 网络状态检测

## 注意事项

1. **Token 管理**: Token 全局只有一个，重新生成会导致旧的失效
2. **模糊搜索**: 参数支持 % 符号进行模糊匹配
   - `'admin'`: 精确匹配
   - `'admin%'`: 开头匹配
   - `'%@example.com'`: 结尾匹配
   - `''%admin%'`: 包含匹配

3. **邮件类型**: type 参数（0=收件，1=发件，空=全部）
4. **删除状态**: isDel 参数（0=正常，2=删除，空=全部）

## License

本项目仅供学习和参考使用。

## 联系方式

如有问题或建议，请通过 Cloud Mail 官方渠道联系。