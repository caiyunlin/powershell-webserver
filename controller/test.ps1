# Handle test request with postData
$p1 = $postData.p1

$response = @{
    status = "success"
    message = "You entered parameter: $p1"
}

Send-WebResponse $context $response