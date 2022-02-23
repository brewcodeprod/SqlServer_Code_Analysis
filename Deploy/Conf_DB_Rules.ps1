Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Write-Host "Building the solution from powershell"

#importing child scripts
. .\Functions.ps1

Write-Host "Configuring the enabled rules...."
$Prop = ConvertFrom-StringData (Get-Content .\Properties.txt -raw)
$mainsolutionpath = $Prop.VsSolutionPath
$dbobjectpath = $Prop.DBProjectPath
$outputpath = $Prop.OutputPath
$sqlrulespath = $Prop.SQLRulesPath

Get-Rules($sqlrulespath, $dbobjectpath)