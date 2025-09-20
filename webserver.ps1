# PowerShell Web Server
Param(
    [parameter(Mandatory=$true)][Int]$port,
    [parameter(Mandatory=$false)][String]$webPath="wwwroot",
    [parameter(Mandatory=$false)][String]$controllerPath="controller"
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
[Console]::CancelKeyPress += {
    param($sender, $e)
    # Prevent the default hard terminate so we can clean up
    $e.Cancel = $true
    if ($script:ServerRunning) {
        Write-Host "`nCtrl+C received, stopping server..." -ForegroundColor Yellow
        $script:ServerRunning = $false
        try { if ($http.IsListening) { $http.Stop() } } catch {}
    }
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

function Get-PostData{
    $reader = new-object System.IO.StreamReader($context.Request.InputStream)
    $text = $reader.ReadToEnd()
    # $text = $text.Replace("%3D","=")
    # $text = ConvertFrom-Base64 $text
    $text = [System.Web.HttpUtility]::UrlDecode($text)
    Write-Host "$text"
    return ConvertFrom-Json $text
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

while ($script:ServerRunning -and $http.IsListening) {
    try {
        # Start async accept
        $async = $http.BeginGetContext($null, $null)
        # Wait up to 1 second so we can poll for Ctrl+C
        $signaled = $async.AsyncWaitHandle.WaitOne(1000)
        if (-not $script:ServerRunning -or -not $http.IsListening) { break }
        if (-not $signaled) { continue } # timeout – loop again

        $context = $http.EndGetContext($async)
        $RequestUrl = $context.Request.Url.LocalPath
        Write-Host "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) : $($context.Request.Url)" -f 'mag'

        # Handle GET requests
        if ($context.Request.HttpMethod -eq 'GET') {       
            # Redirect root to index.html
            if($RequestUrl -eq "/") { $RequestUrl = "/index.html" }
            if(Test-Path "$scriptPath\$webPath\$RequestUrl"){
                try {
                    $fileStream = [System.IO.File]::OpenRead( "$scriptPath\$webPath\$RequestUrl" )
                    $fileStream.CopyTo( $Context.Response.OutputStream )
                    $fileStream.Close()
                } catch {
                    Send-WebResponse $context "500 : Internal Server Error"
                }
            }
            else {
                Send-WebResponse $context "404 : Not found $RequestUrl"            
            }
            $context.Response.Close()
        }

        # Handle POST requests for APIs, processed by controllers
        if($context.Request.HttpMethod -eq "POST"){
            $controllerFile = "$scriptPath/$controllerPath/$RequestUrl.ps1"
            $jsonObj = @{
                "status" = "error"
                "message" = "Unsupported API $RequestUrl"
            }
            if(Test-Path $controllerFile){
                try{
                    $postData = Get-PostData $context           
                    . $controllerFile
                }
                catch{
                    $jsonObj.message = $_.ToString()
                    Send-WebResponse $context $jsonObj
                }
            }
            else{
                Send-WebResponse $context $jsonObj
            }
            $context.Response.Close()
        }

        # Exit Web Server if logout page is accessed
        if($RequestUrl -eq "/logout.html"){
            Write-Host "Exiting Web Server (logout)" -ForegroundColor Yellow
            $script:ServerRunning = $false
        }
    }
    catch [System.ObjectDisposedException] {
        break
    }
    catch {
        if ($script:ServerRunning) {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# ---- Cleanup ----
try {
    if ($http.IsListening) { $http.Stop() }
} catch {}
try { $http.Close() } catch {}
try { $http.Dispose() } catch {}
Write-Host "Server stopped." -ForegroundColor Green

