# postData 
$p1 = $postData.p1

$response = @{
    status = "success"
    message = "你输入了参数： $p1"
}

Send-WebResponse $context $response