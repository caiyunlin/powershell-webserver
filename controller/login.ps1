# postData 

$response = @{
    status = "success"
    message = ""
}

if($postData.username -eq "admin" -and $postData.password -eq "admin"){
    $userName = $postData.username
    $response.message = "欢迎你 $userName"
    Send-WebResponse $context (ConvertTo-Json $response)
}
else{
    $response.message = "无效的用户名或密码"
    Send-WebResponse $context (ConvertTo-Json $response)
}