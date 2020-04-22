## Define variables
$fileShare = New-PSSession -ComputerName $Env:serverName

$stagingDir = $Env:stagingDirectory
$cert = (Get-ChildItem Cert:\LocalMachine\My -CodeSigningCert)
$timestampServer =  "http://timestamp.comodoca.com"

$initParams = @{}
## Uncomment the next line for debugging
## $initParams.Add("Verbose", $true)

## Set application properties
$appName = $Env:APPVEYOR_PROJECT_NAME
$appName = $appName -replace "_+"," " -replace "\-{2,}"," - " -replace "\b-+\b"," "
$install = "Deploy-Application.exe -DeploymentType `"Install`" -AllowRebootPassThru"
$uninstall = "Deploy-Application.exe -DeploymentType `"Uninstall`" -AllowRebootPassThru"

## Determine the app's author
switch ($Env:APPVEYOR_REPO_COMMIT_AUTHOR) {
  $Env:jordanGitHub { $author = $Env:jordan }
  $Env:quanGitHub { $author = $Env:quan }
  $Env:steveGitHub { $author = $Env:steve }
  $Env:truongGitHub { $author = $Env:truong }
  $Env:jamesGitHub { $author = $Env:james }
}

## Remove unneeded files from the repository before uploading to the file share
Write-Output "Cleaning up Git and CI files..."
Remove-Item -Path "$Env:APPLICATION_PATH\appveyor.yml"
Remove-Item -Path "$Env:APPLICATION_PATH\deploy.ps1"
Remove-Item -Path "$Env:APPLICATION_PATH\TestsResults.xml"
Remove-Item -Path "$Env:APPLICATION_PATH\.DS_Store" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$Env:APPLICATION_PATH\.gitignore" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$Env:APPLICATION_PATH\.gitattributes" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$Env:APPLICATION_PATH\Tests" -Recurse
Remove-Item -Path "$Env:APPLICATION_PATH\.git" -Recurse -Force

## Sign PowerShell files to allow running the script directly with a RemoteSigned execution policy
Get-ChildItem  "$Env:APPLICATION_PATH\AppDeployToolkit" `
  | Where-Object { $_.Name -like "*.ps1" } `
    | ForEach-Object `
      { Set-AuthenticodeSignature $_.FullName $cert `
        -HashAlgorithm SHA256 `
        -TimestampServer "$timestampServer" `
      }

Get-ChildItem  "$Env:APPLICATION_PATH" `
  | Where-Object { $_.Name -like "Deploy-Application.ps1" } `
    | ForEach-Object `
      { Set-AuthenticodeSignature $_.FullName $cert `
        -HashAlgorithm SHA256 `
        -TimestampServer "$timestampServer" `
      }

$contentLocation = "$Env:stagingContentLocation\$appName"

## Remove previous staging toolkit files if detected, except for Files and SupportFiles
Invoke-Command -Session $fileShare -ScriptBlock {
  If (Test-Path -Path "$Using:stagingDir\$Using:appName" -PathType Container) {
    Write-Output "Removing staging PowerShell App Deployment Toolkit..."
    Remove-Item -Path "$Using:stagingDir\$Using:appName\*.*" -Force | Where-Object { ! $_.PSIsContainer }
    Remove-Item -Path "$Using:stagingDir\$Using:appName\AppDeployToolkit" -Force -Recurse | `
      Where-Object { $_.PSIsContainer }
  } Else {
    New-Item -Path $Using:stagingDir -Name $Using:appName -ItemType "directory"
  }
}

## Upload the repository to the staging directory, overwriting any remaining files or support files
Copy-Item -Path "$Env:APPLICATION_PATH\*" -Destination "$stagingDir\$appName\" -ToSession $fileShare -Force -Recurse

## Set the application name as we want it to appear in Configuration Manager
$appName = "Staging - $appName"

## Import the ConfigurationManager.psd1 module
If ($null -eq (Get-Module ConfigurationManager)) {
  Import-Module "$($Env:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
}

## Connect to the site's drive if it is not already present
If ($null -eq (Get-PSDrive -Name $Env:siteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
  New-PSDrive -Name $Env:siteCode -PSProvider CMSite -Root $Env:siteServer @initParams
}

## Set the active PSDrive to the ConfigMgr site code
Set-Location "$($Env:siteCode):\" @initParams

## Create the ConfigMgr application (if it doesn't exist) in the format "Staging - GitHub project name"
## This also adds a link to the GitHub repository in the Administrator Comments field for reference and checks the box next to "Allow this application to be installed from the Install Application task sequence action without being deployed"
## Reference: https://docs.microsoft.com/en-us/powershell/module/configurationmanager/new-cmapplication
If ((Get-CMApplication -Name $appName -ErrorAction SilentlyContinue) `
  -or (Get-CMApplication -Name "Staging - $Env:APPVEYOR_PROJECT_NAME" -ErrorAction SilentlyContinue)) {
  
    ## Rename an existing Staging application if detected
  If (Get-CMApplication -Name "Staging - $Env:APPVEYOR_PROJECT_NAME" -ErrorAction SilentlyContinue) {
    Get-CMApplication -Name "Staging - $Env:APPVEYOR_PROJECT_NAME" | Set-CMApplication -NewName $appName
  }
  ## Clear any existing owners and support contacts
  Get-CMApplication -Name $appName | Set-CMApplication -ClearOwner -ClearSupportContact
} Else {
  New-CMApplication -Name $appName
}

Get-CMApplication -Name $appName | `
  Set-CMApplication -Description "Repository: https://github.com/$Env:APPVEYOR_REPO_NAME" `
    -ReleaseDate $(Get-Date -Format d) `
    -Owner $author `
    -SupportContact 'System Engineers' `
    -AutoInstall $True

## Create a new script deployment type with standard settings for PowerShell App Deployment Toolkit
## You'll need to manually update the deployment type's detection method to find the software, make any other needed customizations to the application and deployment type, then distribute your content when ready.
## Reference: https://docs.microsoft.com/en-us/powershell/module/configurationmanager/add-cmscriptdeploymenttype
Get-CMApplication -Name $appName | `
  Add-CMScriptDeploymentType -DeploymentTypeName `
    "$appName $Env:APPVEYOR_BUILD_VERSION" `
    -InstallCommand $install `
    -ScriptLanguage "PowerShell" `
    -ScriptText "Update this application's detection method to accurately locate the application." `
    -ContentLocation $contentLocation `
    -InstallationBehaviorType "InstallForSystem" `
    -LogonRequirementType "WhetherOrNotUserLoggedOn" `
    -MaximumRuntimeMins 120 `
    -UserInteractionMode "Normal" `
    -UninstallCommand $uninstall `
    -ContentFallback `
    -Comment "Commit: https://github.com/$Env:APPVEYOR_REPO_NAME/commit/$Env:APPVEYOR_REPO_COMMIT" `
    -SlowNetworkDeploymentMode 'Download' `
    -EnableBranchCache

# SIG # Begin signature block
# MIIfLgYJKoZIhvcNAQcCoIIfHzCCHxsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAtDoe0ebtDJthM
# KNHCzpVbaRvtg2gcjjkWxg/UrlfuWaCCGhUwggSEMIIDbKADAgECAhBCGvKUCYQZ
# H1IKS8YkJqdLMA0GCSqGSIb3DQEBBQUAMG8xCzAJBgNVBAYTAlNFMRQwEgYDVQQK
# EwtBZGRUcnVzdCBBQjEmMCQGA1UECxMdQWRkVHJ1c3QgRXh0ZXJuYWwgVFRQIE5l
# dHdvcmsxIjAgBgNVBAMTGUFkZFRydXN0IEV4dGVybmFsIENBIFJvb3QwHhcNMDUw
# NjA3MDgwOTEwWhcNMjAwNTMwMTA0ODM4WjCBlTELMAkGA1UEBhMCVVMxCzAJBgNV
# BAgTAlVUMRcwFQYDVQQHEw5TYWx0IExha2UgQ2l0eTEeMBwGA1UEChMVVGhlIFVT
# RVJUUlVTVCBOZXR3b3JrMSEwHwYDVQQLExhodHRwOi8vd3d3LnVzZXJ0cnVzdC5j
# b20xHTAbBgNVBAMTFFVUTi1VU0VSRmlyc3QtT2JqZWN0MIIBIjANBgkqhkiG9w0B
# AQEFAAOCAQ8AMIIBCgKCAQEAzqqBP6OjYXiqMQBVlRGeJw8fHN86m4JoMMBKYR3x
# Lw76vnn3pSPvVVGWhM3b47luPjHYCiBnx/TZv5TrRwQ+As4qol2HBAn2MJ0Yipey
# qhz8QdKhNsv7PZG659lwNfrk55DDm6Ob0zz1Epl3sbcJ4GjmHLjzlGOIamr+C3bJ
# vvQi5Ge5qxped8GFB90NbL/uBsd3akGepw/X++6UF7f8hb6kq8QcMd3XttHk8O/f
# Fo+yUpPXodSJoQcuv+EBEkIeGuHYlTTbZHko/7ouEcLl6FuSSPtHC8Js2q0yg0Hz
# peVBcP1lkG36+lHE+b2WKxkELNNtp9zwf2+DZeJqq4eGdQIDAQABo4H0MIHxMB8G
# A1UdIwQYMBaAFK29mHo0tCb3+sQmVO8DveAky1QaMB0GA1UdDgQWBBTa7WR0FJwU
# PKvdmam9WyhNizzJ2DAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAR
# BgNVHSAECjAIMAYGBFUdIAAwRAYDVR0fBD0wOzA5oDegNYYzaHR0cDovL2NybC51
# c2VydHJ1c3QuY29tL0FkZFRydXN0RXh0ZXJuYWxDQVJvb3QuY3JsMDUGCCsGAQUF
# BwEBBCkwJzAlBggrBgEFBQcwAYYZaHR0cDovL29jc3AudXNlcnRydXN0LmNvbTAN
# BgkqhkiG9w0BAQUFAAOCAQEATUIvpsGK6weAkFhGjPgZOWYqPFosbc/U2YdVjXkL
# Eoh7QI/Vx/hLjVUWY623V9w7K73TwU8eA4dLRJvj4kBFJvMmSStqhPFUetRC2vzT
# artmfsqe6um73AfHw5JOgzyBSZ+S1TIJ6kkuoRFxmjbSxU5otssOGyUWr2zeXXbY
# H3KxkyaGF9sY3q9F6d/7mK8UGO2kXvaJlEXwVQRK3f8n3QZKQPa0vPHkD5kCu/1d
# Di4owb47Xxo/lxCEvBY+2KOcYx1my1xf2j7zDwoJNSLb28A/APnmDV1n0f2gHgMr
# 2UD3vsyHZlSApqO49Rli1dImsZgm7prLRKdFWoGVFRr1UTCCBOYwggPOoAMCAQIC
# EGJcTZCM1UL7qy6lcz/xVBkwDQYJKoZIhvcNAQEFBQAwgZUxCzAJBgNVBAYTAlVT
# MQswCQYDVQQIEwJVVDEXMBUGA1UEBxMOU2FsdCBMYWtlIENpdHkxHjAcBgNVBAoT
# FVRoZSBVU0VSVFJVU1QgTmV0d29yazEhMB8GA1UECxMYaHR0cDovL3d3dy51c2Vy
# dHJ1c3QuY29tMR0wGwYDVQQDExRVVE4tVVNFUkZpcnN0LU9iamVjdDAeFw0xMTA0
# MjcwMDAwMDBaFw0yMDA1MzAxMDQ4MzhaMHoxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# ExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGjAYBgNVBAoT
# EUNPTU9ETyBDQSBMaW1pdGVkMSAwHgYDVQQDExdDT01PRE8gVGltZSBTdGFtcGlu
# ZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKqC8YSpW9hxtdJd
# K+30EyAM+Zvp0Y90Xm7u6ylI2Mi+LOsKYWDMvZKNfN10uwqeaE6qdSRzJ6438xqC
# pW24yAlGTH6hg+niA2CkIRAnQJpZ4W2vPoKvIWlZbWPMzrH2Fpp5g5c6HQyvyX3R
# TtjDRqGlmKpgzlXUEhHzOwtsxoi6lS7voEZFOXys6eOt6FeXX/77wgmN/o6apT9Z
# RvzHLV2Eh/BvWCbD8EL8Vd5lvmc4Y7MRsaEl7ambvkjfTHfAqhkLtv1Kjyx5VbH+
# WVpabVWLHEP2sVVyKYlNQD++f0kBXTybXAj7yuJ1FQWTnQhi/7oN26r4tb8QMspy
# 6ggmzRkCAwEAAaOCAUowggFGMB8GA1UdIwQYMBaAFNrtZHQUnBQ8q92Zqb1bKE2L
# PMnYMB0GA1UdDgQWBBRkIoa2SonJBA/QBFiSK7NuPR4nbDAOBgNVHQ8BAf8EBAMC
# AQYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDCDARBgNV
# HSAECjAIMAYGBFUdIAAwQgYDVR0fBDswOTA3oDWgM4YxaHR0cDovL2NybC51c2Vy
# dHJ1c3QuY29tL1VUTi1VU0VSRmlyc3QtT2JqZWN0LmNybDB0BggrBgEFBQcBAQRo
# MGYwPQYIKwYBBQUHMAKGMWh0dHA6Ly9jcnQudXNlcnRydXN0LmNvbS9VVE5BZGRU
# cnVzdE9iamVjdF9DQS5jcnQwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0
# cnVzdC5jb20wDQYJKoZIhvcNAQEFBQADggEBABHJPeEF6DtlrMl0MQO32oM4xpK6
# /c3422ObfR6QpJjI2VhoNLXwCyFTnllG/WOF3/5HqnDkP14IlShfFPH9Iq5w5Lfx
# sLZWn7FnuGiDXqhg25g59txJXhOnkGdL427n6/BDx9Avff+WWqcD1ptUoCPTpcKg
# jvlP0bIGIf4hXSeMoK/ZsFLu/Mjtt5zxySY41qUy7UiXlF494D01tLDJWK/HWP9i
# dBaSZEHayqjriwO9wU6uH5EyuOEkO3vtFGgJhpYoyTvJbCjCJWn1SmGt4Cf4U6d1
# FbBRMbDxQf8+WiYeYH7i42o5msTq7j/mshM/VQMETQuQctTr+7yHkFGyOBkwggT+
# MIID5qADAgECAhArc9t0YxFMWlsySvIwV3JJMA0GCSqGSIb3DQEBBQUAMHoxCzAJ
# BgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcT
# B1NhbGZvcmQxGjAYBgNVBAoTEUNPTU9ETyBDQSBMaW1pdGVkMSAwHgYDVQQDExdD
# T01PRE8gVGltZSBTdGFtcGluZyBDQTAeFw0xOTA1MDIwMDAwMDBaFw0yMDA1MzAx
# MDQ4MzhaMIGDMQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBNYW5jaGVz
# dGVyMRAwDgYDVQQHDAdTYWxmb3JkMRgwFgYDVQQKDA9TZWN0aWdvIExpbWl0ZWQx
# KzApBgNVBAMMIlNlY3RpZ28gU0hBLTEgVGltZSBTdGFtcGluZyBTaWduZXIwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC/UjaCOtx0Nw141X8WUBlm7boa
# mdFjOJoMZrJA26eAUL9pLjYvCmc/QKFKimM1m9AZzHSqFxmRK7VVIBn7wBo6bco5
# m4LyupWhGtg0x7iJe3CIcFFmaex3/saUcnrPJYHtNIKa3wgVNzG0ba4cvxjVDc/+
# teHE+7FHcen67mOR7PHszlkEEXyuC2BT6irzvi8CD9BMXTETLx5pD4WbRZbCjRKL
# Z64fr2mrBpaBAN+RfJUc5p4ZZN92yGBEL0njj39gakU5E0Qhpbr7kfpBQO1NArRL
# f9/i4D24qvMa2EGDj38z7UEG4n2eP1OEjSja3XbGvfeOHjjNwMtgJAPeekyrAgMB
# AAGjggF0MIIBcDAfBgNVHSMEGDAWgBRkIoa2SonJBA/QBFiSK7NuPR4nbDAdBgNV
# HQ4EFgQUru7ZYLpe9SwBEv2OjbJVcjVGb/EwDgYDVR0PAQH/BAQDAgbAMAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwQAYDVR0gBDkwNzA1Bgwr
# BgEEAbIxAQIBAwgwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9D
# UFMwQgYDVR0fBDswOTA3oDWgM4YxaHR0cDovL2NybC5zZWN0aWdvLmNvbS9DT01P
# RE9UaW1lU3RhbXBpbmdDQV8yLmNybDByBggrBgEFBQcBAQRmMGQwPQYIKwYBBQUH
# MAKGMWh0dHA6Ly9jcnQuc2VjdGlnby5jb20vQ09NT0RPVGltZVN0YW1waW5nQ0Ff
# Mi5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqG
# SIb3DQEBBQUAA4IBAQB6f6lK0rCkHB0NnS1cxq5a3Y9FHfCeXJD2Xqxw/tPZzeQZ
# pApDdWBqg6TDmYQgMbrW/kzPE/gQ91QJfurc0i551wdMVLe1yZ2y8PIeJBTQnMfI
# Z6oLYre08Qbk5+QhSxkymTS5GWF3CjOQZ2zAiEqS9aFDAfOuom/Jlb2WOPeD9618
# KB/zON+OIchxaFMty66q4jAXgyIpGLXhjInrbvh+OLuQT7lfBzQSa5fV5juRvgAX
# IW7ibfxSee+BJbrPE9D73SvNgbZXiU7w3fMLSjTKhf8IuZZf6xET4OHFA61XHOFd
# kga+G8g8P6Ugn2nQacHFwsk+58Vy9+obluKUr4YuMIIFrjCCBJagAwIBAgIQBwNx
# 0Q95WkBxmSuUB2Kb4jANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzELMAkG
# A1UECBMCTUkxEjAQBgNVBAcTCUFubiBBcmJvcjESMBAGA1UEChMJSW50ZXJuZXQy
# MREwDwYDVQQLEwhJbkNvbW1vbjElMCMGA1UEAxMcSW5Db21tb24gUlNBIENvZGUg
# U2lnbmluZyBDQTAeFw0xODA2MjEwMDAwMDBaFw0yMTA2MjAyMzU5NTlaMIG5MQsw
# CQYDVQQGEwJVUzEOMAwGA1UEEQwFODAyMDQxCzAJBgNVBAgMAkNPMQ8wDQYDVQQH
# DAZEZW52ZXIxGDAWBgNVBAkMDzEyMDEgNXRoIFN0cmVldDEwMC4GA1UECgwnTWV0
# cm9wb2xpdGFuIFN0YXRlIFVuaXZlcnNpdHkgb2YgRGVudmVyMTAwLgYDVQQDDCdN
# ZXRyb3BvbGl0YW4gU3RhdGUgVW5pdmVyc2l0eSBvZiBEZW52ZXIwggEiMA0GCSqG
# SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDLV4koxA42DQSGF7D5xRh8Gar0uZYETUmk
# I7MsYC7BiOsiywwqWmMtwgcDdaJ+EJ2MxEKbB1fkyf9yutWb6gMYUegJ8PE41Y2g
# d5D3bSiYxFJYIlzStJw0cjFWrGcnlwC0eUk0n9UsaDLfByA3dCkwfMoTBOnsxXRc
# 8AeR3tv48jrMH2LDfp+JNkPVHGlbVoAs1rmt/Wp8Db2uzOBroDzuWZBel5Kxs0R6
# V3LVfxZOi5qj2OrEZuOZ0nJwtSkNzTf7emQR85gLYG2WuNaOfgLzXZL/U1Rektzg
# xqX96ilvJIxbfNiy2HWYtFdO5Z/kvwbQJRlDzr6npuBJGzLWeTNzAgMBAAGjggHs
# MIIB6DAfBgNVHSMEGDAWgBSuNSMX//8GPZxQ4IwkZTMecBCIojAdBgNVHQ4EFgQU
# pemIbrz5SKX18ziKvmP5pAxjmw8wDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQC
# MAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYJYIZIAYb4QgEBBAQDAgQQMGYGA1Ud
# IARfMF0wWwYMKwYBBAGuIwEEAwIBMEswSQYIKwYBBQUHAgEWPWh0dHBzOi8vd3d3
# LmluY29tbW9uLm9yZy9jZXJ0L3JlcG9zaXRvcnkvY3BzX2NvZGVfc2lnbmluZy5w
# ZGYwSQYDVR0fBEIwQDA+oDygOoY4aHR0cDovL2NybC5pbmNvbW1vbi1yc2Eub3Jn
# L0luQ29tbW9uUlNBQ29kZVNpZ25pbmdDQS5jcmwwfgYIKwYBBQUHAQEEcjBwMEQG
# CCsGAQUFBzAChjhodHRwOi8vY3J0LmluY29tbW9uLXJzYS5vcmcvSW5Db21tb25S
# U0FDb2RlU2lnbmluZ0NBLmNydDAoBggrBgEFBQcwAYYcaHR0cDovL29jc3AuaW5j
# b21tb24tcnNhLm9yZzAtBgNVHREEJjAkgSJpdHNzeXN0ZW1lbmdpbmVlcmluZ0Bt
# c3VkZW52ZXIuZWR1MA0GCSqGSIb3DQEBCwUAA4IBAQCHNj1auwWplgLo8gkDx7Bg
# g2zN4tTmOZ67gP3zrWyepib0/VCWOPutYK3By81e6KdctJ0YVeOfU6ynxyjuNrkc
# maXZx2jqAtPNHH4P9BMBSUct22AdL5FT/E3lJL1IW7XD1aHyNT/8IfWU9omFQnqz
# jgKor8VqofA7fvKEm40hoTxVsrtOG/FHM2yv/e7l3YCtMzXFwyVIzCq+gm3r3y0C
# 30IhT4s2no/tn70f42RwL8TvVtq4XejcOoBbNqtz+AhStPsgJBQi5PvcLKfkbEb0
# ZL3ViafmpzbwCjslXwo+rM+XUDwCGCMi4cvc3t7WlSpvfQ0EGVf8DfwEzw37Sxpt
# MIIF6zCCA9OgAwIBAgIQZeHi49XeUEWF8yYkgAXi1DANBgkqhkiG9w0BAQ0FADCB
# iDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0pl
# cnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNV
# BAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTQw
# OTE5MDAwMDAwWhcNMjQwOTE4MjM1OTU5WjB8MQswCQYDVQQGEwJVUzELMAkGA1UE
# CBMCTUkxEjAQBgNVBAcTCUFubiBBcmJvcjESMBAGA1UEChMJSW50ZXJuZXQyMREw
# DwYDVQQLEwhJbkNvbW1vbjElMCMGA1UEAxMcSW5Db21tb24gUlNBIENvZGUgU2ln
# bmluZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMCgL4seertq
# daz4PtyjujkiyvOjduS/fTAn5rrTmDJWI1wGhpcNgOjtooE16wv2Xn6pPmhz/Z3U
# Z3nOqupotxnbHHY6WYddXpnHobK4qYRzDMyrh0YcasfvOSW+p93aLDVwNh0iLiA7
# 3eMcDj80n+V9/lWAWwZ8gleEVfM4+/IMNqm5XrLFgUcjfRKBoMABKD4D+TiXo60C
# 8gJo/dUBq/XVUU1Q0xciRuVzGOA65Dd3UciefVKKT4DcJrnATMr8UfoQCRF6Vypz
# xOAhKmzCVL0cPoP4W6ks8frbeM/ZiZpto/8Npz9+TFYj1gm+4aUdiwfFv+PfWKrv
# pK+CywX4CgkCAwEAAaOCAVowggFWMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvA
# nfKyA2bLMB0GA1UdDgQWBBSuNSMX//8GPZxQ4IwkZTMecBCIojAOBgNVHQ8BAf8E
# BAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDAzAR
# BgNVHSAECjAIMAYGBFUdIAAwUAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51
# c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJTQUNlcnRpZmljYXRpb25BdXRob3JpdHku
# Y3JsMHYGCCsGAQUFBwEBBGowaDA/BggrBgEFBQcwAoYzaHR0cDovL2NydC51c2Vy
# dHJ1c3QuY29tL1VTRVJUcnVzdFJTQUFkZFRydXN0Q0EuY3J0MCUGCCsGAQUFBzAB
# hhlodHRwOi8vb2NzcC51c2VydHJ1c3QuY29tMA0GCSqGSIb3DQEBDQUAA4ICAQBG
# LLZ/ak4lZr2caqaq0J69D65ONfzwOCfBx50EyYI024bhE/fBlo0wRBPSNe1591dc
# k6YSV22reZfBJmTfyVzLwzaibZMjoduqMAJr6rjAhdaSokFsrgw5ZcUfTBAqesRe
# MJx9THLOFnizq0D8vguZFhOYIP+yunPRtVTcC5Jf6aPTkT5Y8SinhYT4Pfk4tycx
# yMVuy3cpY333HForjRUedfwSRwGSKlA8Ny7K3WFs4IOMdOrYDLzhH9JyE3paRU8a
# lbzLSYZzn2W6XV2UOaNU7KcX0xFTkALKdOR1DQl8oc55VS69CWjZDO3nYJOfc5nU
# 20hnTKvGbbrulcq4rzpTEj1pmsuTI78E87jaK28Ab9Ay/u3MmQaezWGaLvg6BndZ
# RWTdI1OSLECoJt/tNKZ5yeu3K3RcH8//G6tzIU4ijlhG9OBU9zmVafo872goR1i0
# PIGwjkYApWmatR92qiOyXkZFhBBKek7+FgFbK/4uy6F1O9oDm/AgMzxasCOBMXHa
# 8adCODl2xAh5Q6lOLEyJ6sJTMKH5sXjuLveNfeqiKiUJfvEspJdOlZLajLsfOCMN
# 2UCx9PCfC2iflg1MnHODo2OtSOxRsQg5G0kH956V3kRZtCAZ/Bolvk0Q5OidlyRS
# 1hLVWZoW6BZQS6FJah1AirtEDoVP/gBDqp2PfI9s0TGCBG8wggRrAgEBMIGQMHwx
# CzAJBgNVBAYTAlVTMQswCQYDVQQIEwJNSTESMBAGA1UEBxMJQW5uIEFyYm9yMRIw
# EAYDVQQKEwlJbnRlcm5ldDIxETAPBgNVBAsTCEluQ29tbW9uMSUwIwYDVQQDExxJ
# bkNvbW1vbiBSU0EgQ29kZSBTaWduaW5nIENBAhAHA3HRD3laQHGZK5QHYpviMA0G
# CWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZI
# hvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcC
# ARUwLwYJKoZIhvcNAQkEMSIEIPBYtymgEC+Bkw5FxpgyWW8/k3mWpFT26IaVX7AA
# HOtmMA0GCSqGSIb3DQEBAQUABIIBABuhJVME1C7tmmzj/eb+jFTPXsLKvJkvM6al
# W72rH+DncobgexshV+Ni2AE8sELw0IWSa3c8eQ7dIc9Kmlx+XQmd9cA8zVRgmTDX
# dwHhbZ7FaeV2FDSH3cvWojkYAenapWIUWFEMe9beeDqgxv4rjXVJylaO8QiU10Dy
# sQoxoyWD8zRUVBQucUg+31ho3QN6LwEPP8niT+A17ZzzR9iFkrQXwOT88s1iUMsR
# 9Kg93KqRNJn3p2bfBQrVJ9zExBclNY3fmRnlVc3VhzmfJEg2DyhLNZqbK3lQ2DKe
# FA6nndWrFPEXBoU6zEJqDwUY4SZyGD9MkL28SKZVP21CHm4K+COhggIoMIICJAYJ
# KoZIhvcNAQkGMYICFTCCAhECAQEwgY4wejELMAkGA1UEBhMCR0IxGzAZBgNVBAgT
# EkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMR
# Q09NT0RPIENBIExpbWl0ZWQxIDAeBgNVBAMTF0NPTU9ETyBUaW1lIFN0YW1waW5n
# IENBAhArc9t0YxFMWlsySvIwV3JJMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMx
# CwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yMDA0MjIxNTI1MDhaMCMGCSqG
# SIb3DQEJBDEWBBRqGsXK7q29NmD+1og3tBQTDJrhXjANBgkqhkiG9w0BAQEFAASC
# AQCZAphPLR3oMl/qAgXOS+bYQANDFyfugDNsnNP6rrKvOptv1frdsA53nnd3r281
# BQrA1j73JOjGML05TzgB2KpYliNUDWAhUBpVG34gwSTnxu8rT+E9saY778IXADa0
# bo/snmdgcC1HP7J1Jm4zszirDvjYAa8vg4MZpJSNMjiAq3u+3R8KRjtnhkkFIaZn
# Rkuz5i7kjfSDj7tplmTy3A0wGXryaKd4m4psZV53f3RRbc+smjGeij4y4tIirN2g
# PcYJe0M7Yco62oG072VJHRM+91FFUCgw6ActJnXubEqWyyq/T0Xr6kLi0xO9nKDZ
# wU1hYqrNxPGMwf3aTi4twYAv
# SIG # End signature block
