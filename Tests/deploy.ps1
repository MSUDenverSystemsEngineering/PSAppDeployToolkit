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
# MIIkqQYJKoZIhvcNAQcCoIIkmjCCJJYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAtDoe0ebtDJthM
# KNHCzpVbaRvtg2gcjjkWxg/UrlfuWaCCH5AwggSEMIIDbKADAgECAhBCGvKUCYQZ
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
# kga+G8g8P6Ugn2nQacHFwsk+58Vy9+obluKUr4YuMIIFdzCCBF+gAwIBAgIQE+oo
# cFv07O0MNmMJgGFDNjANBgkqhkiG9w0BAQwFADBvMQswCQYDVQQGEwJTRTEUMBIG
# A1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNVBAsTHUFkZFRydXN0IEV4dGVybmFsIFRU
# UCBOZXR3b3JrMSIwIAYDVQQDExlBZGRUcnVzdCBFeHRlcm5hbCBDQSBSb290MB4X
# DTAwMDUzMDEwNDgzOFoXDTIwMDUzMDEwNDgzOFowgYgxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UE
# ChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNB
# IENlcnRpZmljYXRpb24gQXV0aG9yaXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAgBJlFzYOw9sIs9CsVw127c0n00ytUINh4qogTQktZAnczomfzD2p
# 7PbPwdzx07HWezcoEStH2jnGvDoZtF+mvX2do2NCtnbyqTsrkfjib9DsFiCQCT7i
# 6HTJGLSR1GJk23+jBvGIGGqQIjy8/hPwhxR79uQfjtTkUcYRZ0YIUcuGFFQ/vDP+
# fmyc/xadGL1RjjWmp2bIcmfbIWax1Jt4A8BQOujM8Ny8nkz+rwWWNR9XWrf/zvk9
# tyy29lTdyOcSOk2uTIq3XJq0tyA9yn8iNK5+O2hmAUTnAU5GU5szYPeUvlM3kHND
# 8zLDU+/bqv50TmnHa4xgk97Exwzf4TKuzJM7UXiVZ4vuPVb+DNBpDxsP8yUmazNt
# 925H+nND5X4OpWaxKXwyhGNVicQNwZNUMBkTrNN9N6frXTpsNVzbQdcS2qlJC9/Y
# gIoJk2KOtWbPJYjNhLixP6Q5D9kCnusSTJV882sFqV4Wg8y4Z+LoE53MW4LTTLPt
# W//e5XOsIzstAL81VXQJSdhJWBp/kjbmUZIO8yZ9HE0XvMnsQybQv0FfQKlERPSZ
# 51eHnlAfV1SoPv10Yy+xUGUJ5lhCLkMaTLTwJUdZ+gQek9QmRkpQgbLevni3/GcV
# 4clXhB4PY9bpYrrWX1Uu6lzGKAgEJTm4Diup8kyXHAc/DVL17e8vgg8CAwEAAaOB
# 9DCB8TAfBgNVHSMEGDAWgBStvZh6NLQm9/rEJlTvA73gJMtUGjAdBgNVHQ4EFgQU
# U3m/WqorSs9UgOHYm8Cd8rIDZsswDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQF
# MAMBAf8wEQYDVR0gBAowCDAGBgRVHSAAMEQGA1UdHwQ9MDswOaA3oDWGM2h0dHA6
# Ly9jcmwudXNlcnRydXN0LmNvbS9BZGRUcnVzdEV4dGVybmFsQ0FSb290LmNybDA1
# BggrBgEFBQcBAQQpMCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVz
# dC5jb20wDQYJKoZIhvcNAQEMBQADggEBAJNl9jeDlQ9ew4IcH9Z35zyKwKoJ8OkL
# JvHgwmp1ocd5yblSYMgpEg7wrQPWCcR23+WmgZWnRtqCV6mVksW2jwMibDN3wXsy
# F24HzloUQToFJBv2FAY7qCUkDrvMKnXduXBBP3zQYzYhBx9G/2CkkeFnvN4ffhkU
# yWNnkepnB2u0j4vAbkN9w6GAbLIevFOFfdyQoaS8Le9Gclc1Bb+7RrtubTeZtv8j
# kpHGbkD4jylW6l/VXxRTrPBPYer3IsynVgviuDQfJtl7GQVoP7o81DgGotPmjw7j
# tHFtQELFhLRAlSv0ZaBIefYdgWOWnU914Ph85I6p0fKtirOMxyHNwu8wggWuMIIE
# lqADAgECAhAHA3HRD3laQHGZK5QHYpviMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNV
# BAYTAlVTMQswCQYDVQQIEwJNSTESMBAGA1UEBxMJQW5uIEFyYm9yMRIwEAYDVQQK
# EwlJbnRlcm5ldDIxETAPBgNVBAsTCEluQ29tbW9uMSUwIwYDVQQDExxJbkNvbW1v
# biBSU0EgQ29kZSBTaWduaW5nIENBMB4XDTE4MDYyMTAwMDAwMFoXDTIxMDYyMDIz
# NTk1OVowgbkxCzAJBgNVBAYTAlVTMQ4wDAYDVQQRDAU4MDIwNDELMAkGA1UECAwC
# Q08xDzANBgNVBAcMBkRlbnZlcjEYMBYGA1UECQwPMTIwMSA1dGggU3RyZWV0MTAw
# LgYDVQQKDCdNZXRyb3BvbGl0YW4gU3RhdGUgVW5pdmVyc2l0eSBvZiBEZW52ZXIx
# MDAuBgNVBAMMJ01ldHJvcG9saXRhbiBTdGF0ZSBVbml2ZXJzaXR5IG9mIERlbnZl
# cjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMtXiSjEDjYNBIYXsPnF
# GHwZqvS5lgRNSaQjsyxgLsGI6yLLDCpaYy3CBwN1on4QnYzEQpsHV+TJ/3K61Zvq
# AxhR6Anw8TjVjaB3kPdtKJjEUlgiXNK0nDRyMVasZyeXALR5STSf1SxoMt8HIDd0
# KTB8yhME6ezFdFzwB5He2/jyOswfYsN+n4k2Q9UcaVtWgCzWua39anwNva7M4Gug
# PO5ZkF6XkrGzRHpXctV/Fk6LmqPY6sRm45nScnC1KQ3NN/t6ZBHzmAtgbZa41o5+
# AvNdkv9TVF6S3ODGpf3qKW8kjFt82LLYdZi0V07ln+S/BtAlGUPOvqem4EkbMtZ5
# M3MCAwEAAaOCAewwggHoMB8GA1UdIwQYMBaAFK41Ixf//wY9nFDgjCRlMx5wEIii
# MB0GA1UdDgQWBBSl6YhuvPlIpfXzOIq+Y/mkDGObDzAOBgNVHQ8BAf8EBAMCB4Aw
# DAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzARBglghkgBhvhCAQEE
# BAMCBBAwZgYDVR0gBF8wXTBbBgwrBgEEAa4jAQQDAgEwSzBJBggrBgEFBQcCARY9
# aHR0cHM6Ly93d3cuaW5jb21tb24ub3JnL2NlcnQvcmVwb3NpdG9yeS9jcHNfY29k
# ZV9zaWduaW5nLnBkZjBJBgNVHR8EQjBAMD6gPKA6hjhodHRwOi8vY3JsLmluY29t
# bW9uLXJzYS5vcmcvSW5Db21tb25SU0FDb2RlU2lnbmluZ0NBLmNybDB+BggrBgEF
# BQcBAQRyMHAwRAYIKwYBBQUHMAKGOGh0dHA6Ly9jcnQuaW5jb21tb24tcnNhLm9y
# Zy9JbkNvbW1vblJTQUNvZGVTaWduaW5nQ0EuY3J0MCgGCCsGAQUFBzABhhxodHRw
# Oi8vb2NzcC5pbmNvbW1vbi1yc2Eub3JnMC0GA1UdEQQmMCSBIml0c3N5c3RlbWVu
# Z2luZWVyaW5nQG1zdWRlbnZlci5lZHUwDQYJKoZIhvcNAQELBQADggEBAIc2PVq7
# BamWAujyCQPHsGCDbM3i1OY5nruA/fOtbJ6mJvT9UJY4+61grcHLzV7op1y0nRhV
# 459TrKfHKO42uRyZpdnHaOoC080cfg/0EwFJRy3bYB0vkVP8TeUkvUhbtcPVofI1
# P/wh9ZT2iYVCerOOAqivxWqh8Dt+8oSbjSGhPFWyu04b8UczbK/97uXdgK0zNcXD
# JUjMKr6CbevfLQLfQiFPizaej+2fvR/jZHAvxO9W2rhd6Nw6gFs2q3P4CFK0+yAk
# FCLk+9wsp+RsRvRkvdWJp+anNvAKOyVfCj6sz5dQPAIYIyLhy9ze3taVKm99DQQZ
# V/wN/ATPDftLGm0wggXrMIID06ADAgECAhBl4eLj1d5QRYXzJiSABeLUMA0GCSqG
# SIb3DQEBDQUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3IEplcnNleTEU
# MBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VSVFJVU1QgTmV0
# d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0aW9uIEF1dGhv
# cml0eTAeFw0xNDA5MTkwMDAwMDBaFw0yNDA5MTgyMzU5NTlaMHwxCzAJBgNVBAYT
# AlVTMQswCQYDVQQIEwJNSTESMBAGA1UEBxMJQW5uIEFyYm9yMRIwEAYDVQQKEwlJ
# bnRlcm5ldDIxETAPBgNVBAsTCEluQ29tbW9uMSUwIwYDVQQDExxJbkNvbW1vbiBS
# U0EgQ29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
# AQEAwKAvix56u2p1rPg+3KO6OSLK86N25L99MCfmutOYMlYjXAaGlw2A6O2igTXr
# C/Zefqk+aHP9ndRnec6q6mi3GdscdjpZh11emcehsriphHMMzKuHRhxqx+85Jb6n
# 3dosNXA2HSIuIDvd4xwOPzSf5X3+VYBbBnyCV4RV8zj78gw2qblessWBRyN9EoGg
# wAEoPgP5OJejrQLyAmj91QGr9dVRTVDTFyJG5XMY4DrkN3dRyJ59UopPgNwmucBM
# yvxR+hAJEXpXKnPE4CEqbMJUvRw+g/hbqSzx+tt4z9mJmm2j/w2nP35MViPWCb7h
# pR2LB8W/499Yqu+kr4LLBfgKCQIDAQABo4IBWjCCAVYwHwYDVR0jBBgwFoAUU3m/
# WqorSs9UgOHYm8Cd8rIDZsswHQYDVR0OBBYEFK41Ixf//wY9nFDgjCRlMx5wEIii
# MA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMBEGA1UdIAQKMAgwBgYEVR0gADBQBgNVHR8ESTBHMEWgQ6BBhj9o
# dHRwOi8vY3JsLnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQ2VydGlmaWNhdGlv
# bkF1dGhvcml0eS5jcmwwdgYIKwYBBQUHAQEEajBoMD8GCCsGAQUFBzAChjNodHRw
# Oi8vY3J0LnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQWRkVHJ1c3RDQS5jcnQw
# JQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcN
# AQENBQADggIBAEYstn9qTiVmvZxqpqrQnr0Prk41/PA4J8HHnQTJgjTbhuET98GW
# jTBEE9I17Xn3V1yTphJXbat5l8EmZN/JXMvDNqJtkyOh26owAmvquMCF1pKiQWyu
# DDllxR9MECp6xF4wnH1Mcs4WeLOrQPy+C5kWE5gg/7K6c9G1VNwLkl/po9ORPljx
# KKeFhPg9+Ti3JzHIxW7LdyljffccWiuNFR51/BJHAZIqUDw3LsrdYWzgg4x06tgM
# vOEf0nITelpFTxqVvMtJhnOfZbpdXZQ5o1TspxfTEVOQAsp05HUNCXyhznlVLr0J
# aNkM7edgk59zmdTbSGdMq8Ztuu6VyrivOlMSPWmay5MjvwTzuNorbwBv0DL+7cyZ
# Bp7NYZou+DoGd1lFZN0jU5IsQKgm3+00pnnJ67crdFwfz/8bq3MhTiKOWEb04FT3
# OZVp+jzvaChHWLQ8gbCORgClaZq1H3aqI7JeRkWEEEp6Tv4WAVsr/i7LoXU72gOb
# 8CAzPFqwI4Excdrxp0I4OXbECHlDqU4sTInqwlMwofmxeO4u94196qIqJQl+8Syk
# l06VktqMux84Iw3ZQLH08J8LaJ+WDUycc4OjY61I7FGxCDkbSQf3npXeRFm0IBn8
# GiW+TRDk6J2XJFLWEtVZmhboFlBLoUlqHUCKu0QOhU/+AEOqnY98j2zRMYIEbzCC
# BGsCAQEwgZAwfDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAk1JMRIwEAYDVQQHEwlB
# bm4gQXJib3IxEjAQBgNVBAoTCUludGVybmV0MjERMA8GA1UECxMISW5Db21tb24x
# JTAjBgNVBAMTHEluQ29tbW9uIFJTQSBDb2RlIFNpZ25pbmcgQ0ECEAcDcdEPeVpA
# cZkrlAdim+IwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAigAoAA
# oQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4w
# DAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg8Fi3KaAQL4GTDkXGmDJZbz+T
# eZakVPbohpVfsAAc62YwDQYJKoZIhvcNAQEBBQAEggEAG6ElUwTULu2abOP95v6M
# VM9ewsq8mS8zpqVbvasf4OdyhuB7GyFX42LYATywQvDQhZJrdzx5Dt0hz0qaXH5d
# CZ31wDzNVGCZMNd3AeFtnsVp5XYUNIfdy9aiORgB6dqlYhRYUQx71t54OqDG/iuN
# dUnKVo7xCJTXQPKxCjGjJYPzNFRUFC5xSD7fWGjdA3ovAQ8/yeJP4DXtnPNH2IWS
# tBfA5PzyzWJQyxH0qD3cqpE0mfenZt8FCtUn3MTEFyU1jd+ZGeVVzdWHOZ8kSDYP
# KEs1mpsreVDYMp4UDqed1asU8RcGhTrMQmoPBRjhJnIYP0yQvbxIplU/bUIebgr4
# I6GCAigwggIkBgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB6MQswCQYDVQQGEwJH
# QjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3Jk
# MRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDEgMB4GA1UEAxMXQ09NT0RPIFRp
# bWUgU3RhbXBpbmcgQ0ECECtz23RjEUxaWzJK8jBXckkwCQYFKw4DAhoFAKBdMBgG
# CSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIwMDMxMTE2
# MTIyNFowIwYJKoZIhvcNAQkEMRYEFGoaxcrurb02YP7WiDe0FBMMmuFeMA0GCSqG
# SIb3DQEBAQUABIIBAHMEqCs9UBPpsyCX8G7B+6hjXZ0UhOXcFhdmDoE0kG76NoOB
# 7mT774NCZkE7Z+XJZdW3P4iJlbpTF2yGRXaak67DO92/oow8BzeRfOYoNqtGypF4
# 2zlTfZC2s8iBX6EfNJc3Yz60+gkUn5+aqVvXgn/LjTtEGK5brPpXXiiEoyx3zKcq
# 3VM9yhrpbBMOf+z1PrBuUj2MzhScvYCOPW9NuMjOChS1KOJEcccKelIgy+SOEo/a
# c2iiRITbIVQnUXzx4NLdyH0AwFbJSHx2bZkr3BJpem2Z0UnW5HKO10O/5StwJUBo
# 9BsJxjrtr0K5PW/AC8Byhia1oJS0vXKAigZ1Ijs=
# SIG # End signature block
