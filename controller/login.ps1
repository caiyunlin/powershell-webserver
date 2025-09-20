# Handle login request with postData

$response = @{
    status = "success"
    message = ""
}

if($postData.username -eq "admin" -and $postData.password -eq "admin"){
    $userName = $postData.username
    $response.message = "Welcome, $userName!"
    Send-WebResponse $context (ConvertTo-Json $response)
}
else{
    $response.message = "Invalid username or password"
    Send-WebResponse $context (ConvertTo-Json $response)
}