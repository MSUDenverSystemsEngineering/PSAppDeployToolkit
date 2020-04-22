<#
.SYNOPSIS
	Displays a graphical console to browse the help for the App Deployment Toolkit functions
    # LICENSE #
    PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
    Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
    This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
    You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	Displays a graphical console to browse the help for the App Deployment Toolkit functions
.EXAMPLE
	AppDeployToolkitHelp.ps1
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>

##*===============================================
##* VARIABLE DECLARATION
##*===============================================

## Variables: Script
[string]$appDeployToolkitHelpName = 'PSAppDeployToolkitHelp'
[string]$appDeployHelpScriptFriendlyName = 'App Deploy Toolkit Help'
[version]$appDeployHelpScriptVersion = [version]'3.8.1'
[string]$appDeployHelpScriptDate = '28/03/2020'

## Variables: Environment
[string]$scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
#  Dot source the App Deploy Toolkit Functions
. "$scriptDirectory\AppDeployToolkitMain.ps1" -DisableLogging
. "$scriptDirectory\AppDeployToolkitExtensions.ps1"
##*===============================================
##* END VARIABLE DECLARATION
##*===============================================

##*===============================================
##* FUNCTION LISTINGS
##*===============================================

Function Show-HelpConsole {
	## Import the Assemblies
	Add-Type -AssemblyName 'System.Windows.Forms' -ErrorAction 'Stop'
	Add-Type -AssemblyName System.Drawing -ErrorAction 'Stop'

	## Form Objects
	$HelpForm = New-Object -TypeName 'System.Windows.Forms.Form'
	$HelpListBox = New-Object -TypeName 'System.Windows.Forms.ListBox'
	$HelpTextBox = New-Object -TypeName 'System.Windows.Forms.RichTextBox'
	$InitialFormWindowState = New-Object -TypeName 'System.Windows.Forms.FormWindowState'

	## Form Code
	$System_Drawing_Size = New-Object -TypeName 'System.Drawing.Size'
	$System_Drawing_Size.Height = 665
	$System_Drawing_Size.Width = 957
	$HelpForm.ClientSize = $System_Drawing_Size
	$HelpForm.DataBindings.DefaultDataSourceUpdateMode = 0
	$HelpForm.Name = 'HelpForm'
	$HelpForm.Text = 'PowerShell App Deployment Toolkit Help Console'
	$HelpForm.WindowState = 'Normal'
	$HelpForm.ShowInTaskbar = $true
	$HelpForm.FormBorderStyle = 'Fixed3D'
	$HelpForm.MaximizeBox = $false
	$HelpForm.Icon = New-Object -TypeName 'System.Drawing.Icon' -ArgumentList $AppDeployLogoIcon
	$HelpListBox.Anchor = 7
	$HelpListBox.BorderStyle = 1
	$HelpListBox.DataBindings.DefaultDataSourceUpdateMode = 0
	$HelpListBox.Font = New-Object -TypeName 'System.Drawing.Font' -ArgumentList ('Microsoft Sans Serif', 9.75, 1, 3, 1)
	$HelpListBox.FormattingEnabled = $true
	$HelpListBox.ItemHeight = 16
	$System_Drawing_Point = New-Object -TypeName 'System.Drawing.Point'
	$System_Drawing_Point.X = 0
	$System_Drawing_Point.Y = 0
	$HelpListBox.Location = $System_Drawing_Point
	$HelpListBox.Name = 'HelpListBox'
	$System_Drawing_Size = New-Object -TypeName 'System.Drawing.Size'
	$System_Drawing_Size.Height = 658
	$System_Drawing_Size.Width = 271
	$HelpListBox.Size = $System_Drawing_Size
	$HelpListBox.Sorted = $true
	$HelpListBox.TabIndex = 2
	$HelpListBox.add_SelectedIndexChanged({ $HelpTextBox.Text = Get-Help -Name $HelpListBox.SelectedItem -Full | Out-String })
	$helpFunctions = Get-Command -CommandType 'Function' | Where-Object { ($_.HelpUri -match 'psappdeploytoolkit') -and ($_.Definition -notmatch 'internal script function') } | Select-Object -ExpandProperty Name
	$null = $HelpListBox.Items.AddRange($helpFunctions)
	$HelpForm.Controls.Add($HelpListBox)
	$HelpTextBox.Anchor = 11
	$HelpTextBox.BorderStyle = 1
	$HelpTextBox.DataBindings.DefaultDataSourceUpdateMode = 0
	$HelpTextBox.Font = New-Object -TypeName 'System.Drawing.Font' -ArgumentList ('Microsoft Sans Serif', 8.5, 0, 3, 1)
	$HelpTextBox.ForeColor = [System.Drawing.Color]::FromArgb(255, 0, 0, 0)
	$System_Drawing_Point = New-Object -TypeName System.Drawing.Point
	$System_Drawing_Point.X = 277
	$System_Drawing_Point.Y = 0
	$HelpTextBox.Location = $System_Drawing_Point
	$HelpTextBox.Name = 'HelpTextBox'
	$HelpTextBox.ReadOnly = $True
	$System_Drawing_Size = New-Object -TypeName 'System.Drawing.Size'
	$System_Drawing_Size.Height = 658
	$System_Drawing_Size.Width = 680
	$HelpTextBox.Size = $System_Drawing_Size
	$HelpTextBox.TabIndex = 1
	$HelpTextBox.Text = ''
	$HelpForm.Controls.Add($HelpTextBox)

	## Save the initial state of the form
	$InitialFormWindowState = $HelpForm.WindowState
	## Init the OnLoad event to correct the initial state of the form
	$HelpForm.add_Load($OnLoadForm_StateCorrection)
	## Show the Form
	$null = $HelpForm.ShowDialog()
}

##*===============================================
##* END FUNCTION LISTINGS
##*===============================================

##*===============================================
##* SCRIPT BODY
##*===============================================

Write-Log -Message "Load [$appDeployHelpScriptFriendlyName] console..." -Source $appDeployToolkitHelpName

## Show the help console
Show-HelpConsole

Write-Log -Message "[$appDeployHelpScriptFriendlyName] console closed." -Source $appDeployToolkitHelpName

##*===============================================
##* END SCRIPT BODY
##*===============================================

# SIG # Begin signature block
# MIIfLgYJKoZIhvcNAQcCoIIfHzCCHxsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAgpVdCqWcDjcoX
# DNqh6em+CQ7xu+QRfJ9KIpkA57aGkqCCGhUwggSEMIIDbKADAgECAhBCGvKUCYQZ
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
# ARUwLwYJKoZIhvcNAQkEMSIEILY5N7jI3LAQ1Z8n6E/0GETo+3Nd9yWXQQPNVaGa
# YQynMA0GCSqGSIb3DQEBAQUABIIBAIQ2n8shEC+YZdAUQhaKt0jpCt8iyA1v2lct
# S5PtKz948phtLBfHzEtAhiOeXLFAflxmw6yomAoC7vzghHWiiUvKGtdeFVqi8vyy
# RI6lZorGPg1gtB2AA/P4LqcKTmRQ3ZY6wsiGwnqe5rjYvQynSoHPjzsH+h/XNJP7
# DFgkUx3iBkZO2o3OAcloqbMiLWgmiVwn6J4uMlVHdcIHt9TlHpDp7bLg3wyD4H8p
# a8WRFn2cFxwyrJdz1iw9zocVYIcYl0knXDJeh6gW0xCkpU9VDHttDTKsirERQ8Jh
# hVWfZmu76/l9fOpEE6roCzrtSc4j/oenQmZBN6r2YBHIgk9k5WWhggIoMIICJAYJ
# KoZIhvcNAQkGMYICFTCCAhECAQEwgY4wejELMAkGA1UEBhMCR0IxGzAZBgNVBAgT
# EkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMR
# Q09NT0RPIENBIExpbWl0ZWQxIDAeBgNVBAMTF0NPTU9ETyBUaW1lIFN0YW1waW5n
# IENBAhArc9t0YxFMWlsySvIwV3JJMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMx
# CwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yMDA0MjIxNTI1MDJaMCMGCSqG
# SIb3DQEJBDEWBBRbACwXsWFD053nwmZhvrBxcGsvKDANBgkqhkiG9w0BAQEFAASC
# AQAceSO6VmRIGXH3942bGeCU0OPjoLfH7Iqglq5LmdgG8mQ2ckld0DeFfZisgXnf
# OUyerCZKQP+Jb7VXDS2tGzXZQJ3mJbyzjN7Zi4zsVRvpyHqYRpv+x1y4NsmLEaNV
# lLRkz44FaEkVT3IqJ/WU1v8HlEolfdFdk2Z80e+sW2lFJC5mJ6WqADZ9UUxMdS8L
# T64UYcruSVPWzouKs756Q2grCsxcLCbnn11PngShW7e9tnrXTAlDIsE+ereDqXzT
# IqZQzmRJUBAOxJBdSAL+65mcxHQ05PrNSnmtXu9dwGziY+rlv39l5Jks931xCjTC
# zLZRBoC/AzMA/+DCUdmtajY1
# SIG # End signature block
