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

# INFINITE LOOP, Used to listen for requests
while ($http.IsListening) {
    $context = $http.GetContext()
    $RequestUrl = $context.Request.Url.LocalPath
    
    Write-Host "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) : $($context.Request.Url)" -f 'mag'

    # Handle GET requests
    if ($context.Request.HttpMethod -eq 'GET') {       
        # Redirect root to index.html
        if($RequestUrl -eq "/") {
          $RequestUrl = "/index.html"
        }
        if(Test-Path "$scriptPath\$webPath\$RequestUrl"){
            $fileStream = [System.IO.File]::OpenRead( "$scriptPath\$webPath\$RequestUrl" )
            $fileStream.CopyTo( $Context.Response.OutputStream )
            $fileStream.Close()
        }
        else{
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
    # PowerShell will continue looping and listen for new requests...
    # Exit Web Server if logout page is accessed
    if($RequestUrl -eq "/logout.html"){
        Write-Host "Exiting Web Server"
        $http.Close();
        $http.Dispose();
        exit;
    }
}

