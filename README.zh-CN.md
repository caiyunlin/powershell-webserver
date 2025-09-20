# PowerShell Web Server

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)](https://www.microsoft.com/windows)

一个基于 PowerShell 实现的轻量级 Web 服务器，使用 .NET HttpListener，支持静态文件服务和 RESTful API 端点。

## 🚀 功能特性

- **静态文件服务**: 从 `wwwroot` 目录提供文件服务
- **RESTful API**: 通过 PowerShell 控制器处理 POST 端点
- **简单身份验证**: 内置登录功能
- **JSON 支持**: 自动 JSON 解析和响应格式化
- **URL 解码**: 正确处理 URL 编码数据
- **Base64 工具**: 内置编码/解码功能
- **优雅关闭**: 通过注销端点清洁退出

## 📁 项目结构

```
powershell-webserver/
├── webserver.ps1           # 主服务器脚本
├── startweb.bat           # 快速启动批处理文件
├── README.md              # 英文文档
├── README.zh-CN.md        # 中文文档（本文件）
├── wwwroot/               # 静态网页文件
│   ├── index.html         # 主页面，包含测试界面
│   └── logout.html        # 登出页面
└── controller/            # API 控制器
    ├── login.ps1          # 登录端点
    └── test.ps1           # 测试端点
```

## 🛠️ 系统要求

- Windows 操作系统
- PowerShell 5.1 或更高版本
- 管理员权限（用于绑定 HTTP 端口）

## 🚀 快速开始

### 方法 1: 使用批处理文件
```batch
# 以管理员身份运行
startweb.bat
```

### 方法 2: 手动启动
```powershell
# 以管理员身份运行
.\webserver.ps1 -port 8090
```

### 方法 3: 自定义配置
```powershell
# 自定义端口和路径
.\webserver.ps1 -port 8080 -webPath "wwwroot" -controllerPath "controller"
```

## 🌐 使用方法

1. **访问 Web 界面**
   - 打开浏览器并访问 `http://localhost:8090`
   - 默认端口为 8090（可在 `startweb.bat` 中配置或通过参数设置）

2. **测试功能**
   - **参数测试**: 输入文本并点击"参数测试"来测试 API 参数
   - **登录测试**: 使用用户名 `admin` 和密码 `admin` 测试身份验证
   - **静态文件**: `wwwroot` 中的任何文件都会自动提供服务

3. **API 端点**
   - `POST /login` - 身份验证端点
   - `POST /test` - 参数测试端点
   - 通过在 `controller` 目录中创建 `.ps1` 文件来添加自定义端点

## 🔧 配置选项

### 参数说明

| 参数 | 类型 | 必需 | 默认值 | 描述 |
|------|------|------|--------|------|
| `port` | 整数 | 是 | - | HTTP 服务器端口 |
| `webPath` | 字符串 | 否 | "wwwroot" | 静态文件目录 |
| `controllerPath` | 字符串 | 否 | "controller" | API 控制器目录 |

### API 控制器示例

在 `controller` 目录中创建新文件：

```powershell
# controller/hello.ps1
$response = @{
    status = "success"
    message = "你好，$($postData.name)！"
    timestamp = (Get-Date).ToString()
}

Send-WebResponse $context $response
```

通过以下方式访问：`POST /hello`，JSON 主体为 `{"name": "世界"}`

## 🛑 停止服务器

- **优雅关闭**: 访问 `http://localhost:8090/logout.html`
- **强制停止**: 关闭 PowerShell 控制台窗口
- **注意**: `Ctrl+C` 可能无法可靠工作

## 🔒 安全注意事项

⚠️ **这是一个开发/演示服务器，在没有适当安全措施的情况下不应在生产环境中使用：**

- 默认凭据是硬编码的（`admin`/`admin`）
- 不支持 HTTPS
- 没有输入验证或清理
- 没有速率限制或 DoS 保护
- 以提升的权限运行

## 🐛 故障排除

- **访问被拒绝**: 确保您以管理员身份运行
- **端口已被使用**: 在 `startweb.bat` 中更改端口号或使用不同的端口
- **文件未找到**: 检查文件是否存在于 `wwwroot` 目录中
- **API 错误**: 检查 PowerShell 控制台以查看错误消息

## 📝 许可证

此项目是开源的，采用 [MIT 许可证](LICENSE)。

## 🤝 贡献

欢迎贡献！请随时提交 Pull Request。

## 📞 支持

如果您遇到任何问题或有疑问，请在此仓库中[创建 issue](../../issues)。
