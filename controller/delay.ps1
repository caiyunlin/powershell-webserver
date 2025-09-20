# Simulate a slow API for concurrency testing
param()

# Allow query like /delay?ms=1500 or POST {"ms":1500}
$defaultMs = 1500
$ms = $null
try {
    # Try query string first
    if ($context.Request.Url.Query) {
        $q = [System.Web.HttpUtility]::ParseQueryString($context.Request.Url.Query)
        if ($q["ms"]) { $ms = [int]$q["ms"] }
    }
} catch {}
if (-not $ms -and $postData -and $postData.ms) { $ms = [int]$postData.ms }
if (-not $ms) { $ms = $defaultMs }
if ($ms -lt 0 -or $ms -gt 60000) { $ms = $defaultMs }

$start = Get-Date
Start-Sleep -Milliseconds $ms
$end = Get-Date

$response = @{
    status = 'success'
    delayMsRequested = $ms
    actualMs = [int]($end - $start).TotalMilliseconds
    start = $start.ToString('yyyy-MM-dd HH:mm:ss.fff')
    end = $end.ToString('yyyy-MM-dd HH:mm:ss.fff')
    threadInfo = [System.Threading.Thread]::CurrentThread.ManagedThreadId
}
Send-WebResponse $context $response
