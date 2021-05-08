# postData 

$p1 = $postData.p1
Send-WebResponse $context "{`"status`":`"error`",`"message`":`"你输入了参数： $p1`"}"


