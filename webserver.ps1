# PowerShell Web Server
Param(
    [parameter(Mandatory=$true)][Int]$port,
    [parameter(Mandatory=$false)][String]$webPath="wwwroot",
    [parameter(Mandatory=$false)][String]$controllerPath="controller",
    # 最大并发处理请求数 (线程池限流)，默认 = 逻辑CPU数
    [parameter(Mandatory=$false)][Int]$MaxConcurrency = [Environment]::ProcessorCount
)

Add-Type -AssemblyName System.Web

$scriptPath = $PSScriptRoot

$http = [System.Net.HttpListener]::new()
$http.Prefixes.Add("http://localhost:$port/")
$http.Start()

# ---- Ctrl+C Support & Running Flag ----
# Use a script-scoped flag so the CancelKeyPress handler can signal the main loop
$script:ServerRunning = $true
[Console]::TreatControlCAsInput = $false

# Windows PowerShell 5.1 不支持用 += 直接给静态事件绑定脚本块，这里使用显式委托方式
$script:CtrlCHandler = [System.ConsoleCancelEventHandler]{
    param($sender, $e)
    try {
        $e.Cancel = $true
        if ($script:ServerRunning) {
            Write-Host "`nCtrl+C received, stopping server..." -ForegroundColor Yellow
            $script:ServerRunning = $false
            try { if ($http.IsListening) { $http.Stop() } } catch {}
        }
    } catch {}
}
try {
    [Console]::add_CancelKeyPress($script:CtrlCHandler)
} catch {
    Write-Host "Warn: Failed to register Ctrl+C handler: $($_.Exception.Message)" -ForegroundColor Yellow
}

function ConvertTo-Base64($str){
    $result = [Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes($str))
    return $result
}

function ConvertFrom-Base64($str){
    $byteArray = [Convert]::FromBase64String($str)
    return [System.Text.UTF8Encoding]::UTF8.GetString($byteArray)
}

function Send-WebResponse($context, $content) {
    if($content.GetType().Name -ne "String"){
        $content = ConvertTo-JSON $content
    }
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
    $context.Response.ContentLength64 = $buffer.Length
    $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
}

function Get-PostData {
    param(
        [Parameter(Mandatory)][System.Net.HttpListenerContext]$Context
    )
    $reader = [System.IO.StreamReader]::new($Context.Request.InputStream)
    $text = $reader.ReadToEnd()
    $text = [System.Web.HttpUtility]::UrlDecode($text)
    Write-Host $text
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    try { return ConvertFrom-Json $text -ErrorAction Stop } catch { return $text }
}

if ($http.IsListening) {
    write-host "HTTP Server Ready!  " -f 'black' -b 'gre'
    write-host "$($http.Prefixes)" -f 'y'
}

<#
    Main loop refactored to non-blocking style:
    - Use BeginGetContext() + WaitOne(timeout) so we periodically return to the loop
      giving PowerShell a chance to process Ctrl+C (CancelKeyPress)
    - Preserves original request handling logic
    - Graceful shutdown triggered by either Ctrl+C or /logout.html
 #>

<#
    多线程（并发）实现（兼容 Windows PowerShell 5.1）
    - 不再使用 ThreadPool 直接执行脚本块（5.1 下线程没有 PowerShell 运行空间）
    - 改为 RunspacePool：创建一个共享的运行空间池，最大并发 = -MaxConcurrency
    - 每个请求包装成一个 PowerShell 实例异步提交 (BeginInvoke)
    - 主线程：仅负责 Accept + 回收已完成的异步实例
    - /logout.html 内部调用 $http.Stop() 触发主循环退出
    注意：控制器脚本内仍可使用 $postData / $context
#>

Write-Host "Max Concurrency (RunspacePool): $MaxConcurrency" -ForegroundColor Cyan

# 初始化运行空间池
$initial = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$pool = [RunspaceFactory]::CreateRunspacePool(1, $MaxConcurrency, $initial, $Host)
$pool.Open()

# 处理请求的脚本（在子运行空间中执行，避免引用主脚本作用域变量）
$requestWorker = {
    param($context, $scriptPath, $webPath, $controllerPath, $httpListener)

    function Send-WebResponse {
        param($context, $content)
        if ($null -ne $content -and $content.GetType().Name -ne 'String') { $content = ConvertTo-Json $content }
        if ($null -eq $content) { $content = '' }
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
        try { $context.Response.ContentLength64 = $buffer.Length } catch {}
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
    }
    function Get-PostData {
        param($Context)
        $reader = [System.IO.StreamReader]::new($Context.Request.InputStream)
        $text = $reader.ReadToEnd()
        $text = [System.Web.HttpUtility]::UrlDecode($text)
        if ([string]::IsNullOrWhiteSpace($text)) { return $null }
        try { return ConvertFrom-Json $text -ErrorAction Stop } catch { return $text }
    }
    function ConvertTo-Base64([string]$str){ [Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes($str)) }
    function ConvertFrom-Base64([string]$str){ [System.Text.UTF8Encoding]::UTF8.GetString([Convert]::FromBase64String($str)) }

    try {
        $RequestUrl = $context.Request.Url.LocalPath
        Write-Host "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') : $($context.Request.HttpMethod) $($context.Request.Url) (Runspace $([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.Id))" -ForegroundColor Magenta

        if ($context.Request.HttpMethod -eq 'GET') {
            if ($RequestUrl -eq '/') { $RequestUrl = '/index.html' }
            $filePath = Join-Path -Path $scriptPath -ChildPath (Join-Path $webPath $RequestUrl.TrimStart('/'))
            if (Test-Path $filePath) {
                try {
                    $fileStream = [System.IO.File]::OpenRead($filePath)
                    $fileStream.CopyTo($context.Response.OutputStream)
                    $fileStream.Close()
                } catch { Send-WebResponse $context '500 : Internal Server Error' }
            } else {
                Send-WebResponse $context "404 : Not found $RequestUrl"
            }
        }
        elseif ($context.Request.HttpMethod -eq 'POST') {
            $controllerFile = Join-Path -Path $scriptPath -ChildPath (Join-Path $controllerPath ($RequestUrl + '.ps1').TrimStart('/'))
            $jsonObj = @{ status = 'error'; message = "Unsupported API $RequestUrl" }
            if (Test-Path $controllerFile) {
                try {
                    $postData = Get-PostData -Context $context
                    . $controllerFile
                } catch {
                    $jsonObj.message = $_.ToString()
                    Send-WebResponse $context $jsonObj
                }
            } else {
                Send-WebResponse $context $jsonObj
            }
        }

        if ($RequestUrl -eq '/logout.html') {
            Write-Host 'Exiting Web Server (logout)' -ForegroundColor Yellow
            try { if ($httpListener.IsListening) { $httpListener.Stop() } } catch {}
        }
    }
    catch {
        Write-Host "Worker error: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        try { $context.Response.Close() } catch {}
    }
}

# 保存正在进行的异步调用以便回收
$active = New-Object System.Collections.ArrayList

while ($script:ServerRunning -and $http.IsListening) {
    try {
        $context = $http.GetContext()

        # 清理已完成任务
        for ($i = $active.Count - 1; $i -ge 0; $i--) {
            $entry = $active[$i]
            if ($entry.Handle.IsCompleted) {
                try { $entry.PS.EndInvoke($entry.Handle) | Out-Null } catch {}
                $entry.PS.Dispose()
                $active.RemoveAt($i)
            }
        }

        $ps = [PowerShell]::Create()
        $ps.RunspacePool = $pool
        $null = $ps.AddScript($requestWorker).AddArgument($context).AddArgument($scriptPath).AddArgument($webPath).AddArgument($controllerPath).AddArgument($http)
        $handle = $ps.BeginInvoke()
        [void]$active.Add(@{ PS = $ps; Handle = $handle })
    }
    catch [System.ObjectDisposedException] { break }
    catch {
        if ($script:ServerRunning) {
            Write-Host "Accept loop error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 回收剩余任务
for ($i = $active.Count - 1; $i -ge 0; $i--) {
    $entry = $active[$i]
    try { $entry.PS.EndInvoke($entry.Handle) | Out-Null } catch {}
    $entry.PS.Dispose()
}
try { $pool.Close() } catch {}
try { $pool.Dispose() } catch {}

# ---- Cleanup ----
try {
    if ($http.IsListening) { $http.Stop() }
} catch {}
try { $http.Close() } catch {}
try { $http.Dispose() } catch {}
try { if ($script:CtrlCHandler) { [Console]::remove_CancelKeyPress($script:CtrlCHandler) } } catch {}
Write-Host "Server stopped." -ForegroundColor Green

