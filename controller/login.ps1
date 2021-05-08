# postData 

if($postData.username -eq "admin" -and $postData.password -eq "admin"){
    $userName = $postData.username
    Send-WebResponse $context "{`"status`":`"success`",`"message`":`"欢迎你 $userName`"}"
}
else{
    Send-WebResponse $context "{`"status`":`"error`",`"message`":`"无效的用户名或密码`"}"
}

