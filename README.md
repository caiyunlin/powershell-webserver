# PowerShell Web Server

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)](https://www.microsoft.com/windows)

A lightweight web server implemented in PowerShell using .NET HttpListener, supporting both static file serving and RESTful API endpoints.

## 🚀 Features

- **Static File Serving**: Serves files from the `wwwroot` directory
- **RESTful API**: POST endpoints handled by PowerShell controllers
- **Simple Authentication**: Built-in login functionality
- **JSON Support**: Automatic JSON parsing and response formatting
- **URL Decoding**: Proper handling of URL-encoded data
- **Base64 Utilities**: Built-in encoding/decoding functions
- **Graceful Shutdown**: Clean exit via logout endpoint

## 📁 Project Structure

```
powershell-webserver/
├── webserver.ps1           # Main server script
├── startweb.bat           # Quick start batch file
├── README.md              # This file
├── README.zh-CN.md        # Chinese documentation
├── wwwroot/               # Static web files
│   ├── index.html         # Main page with test interfaces
│   └── logout.html        # Logout page
└── controller/            # API controllers
    ├── login.ps1          # Login endpoint
    └── test.ps1           # Test endpoint
```

## 🛠️ Requirements

- Windows operating system
- PowerShell 5.1 or later
- Administrator privileges (for binding to HTTP ports)

## 🚀 Quick Start

### Method 1: Using Batch File
```batch
# Run as Administrator
startweb.bat
```

### Method 2: Manual Start
```powershell
# Run as Administrator
.\webserver.ps1 -port 8090
```

### Method 3: Custom Configuration
```powershell
# Custom port and paths
.\webserver.ps1 -port 8080 -webPath "wwwroot" -controllerPath "controller"
```

## 🌐 Usage

1. **Access the Web Interface**
   - Open your browser and navigate to `http://localhost:8090`
   - Default port is 8090 (configurable in `startweb.bat` or via parameters)

2. **Test Features**
   - **Parameter Test**: Enter text and click "Test Parameters" to test API parameters
   - **Login Test**: Use username `admin` and password `admin` to test authentication
   - **Static Files**: Any files in `wwwroot` are served automatically

3. **API Endpoints**
   - `POST /login` - Authentication endpoint
   - `POST /test` - Parameter testing endpoint
   - Add custom endpoints by creating `.ps1` files in the `controller` directory

## 🔧 Configuration

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `port` | Integer | Yes | - | HTTP server port |
| `webPath` | String | No | "wwwroot" | Static files directory |
| `controllerPath` | String | No | "controller" | API controllers directory |

### Example API Controller

Create a new file in the `controller` directory:

```powershell
# controller/hello.ps1
$response = @{
    status = "success"
    message = "Hello, $($postData.name)!"
    timestamp = (Get-Date).ToString()
}

Send-WebResponse $context $response
```

Access via: `POST /hello` with JSON body `{"name": "World"}`

## 🛑 Stopping the Server

- **Graceful Shutdown**: Navigate to `http://localhost:8090/logout.html`
- **Force Stop**: Close the PowerShell console window
- **Note**: `Ctrl+C` may not work reliably

## 🔒 Security Considerations

⚠️ **This is a development/demo server and should not be used in production environments without proper security measures:**

- Default credentials are hardcoded (`admin`/`admin`)
- No HTTPS support
- No input validation or sanitization
- No rate limiting or DoS protection
- Runs with elevated privileges

## 🐛 Troubleshooting

- **Access Denied**: Ensure you're running as Administrator
- **Port Already in Use**: Change the port number in `startweb.bat` or use a different port
- **File Not Found**: Check that files exist in the `wwwroot` directory
- **API Errors**: Check PowerShell console for error messages

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

If you encounter any issues or have questions, please [create an issue](../../issues) in this repository.

