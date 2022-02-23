Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Write-Host "Building the solution from powershell"

#importing child scripts
. .\Functions.ps1

Write-Host "Setting the parameter values from properties file"
$Prop = ConvertFrom-StringData (Get-Content .\Properties.txt -raw)
$mainsolutionpath = $Prop.VsSolutionPath
$dbobjectpath = $Prop.DBProjectPath
$outputpath = $Prop.OutputPath
$sqlrulespath = $Prop.SQLRulesPath
Write-Host "Completed: Setting the parameter values from properties file"

Write-Host "Master solution build started...."
buildVS $mainsolutionpath
Write-Host "Build completed"

#Move the required files to the visual studio extension folders
$d1 = Get-ChildItem "C:\Program Files (x86)\Microsoft Visual Studio\" -Recurse | Where-Object { $_.Name -match '^[0-9]*DAC' } | %{ $_.FullName }
$d = Get-ChildItem $d1[0] -Recurse | Where-Object { $_.Name -match '^[0-9]*Extensions' } | %{ $_.FullName }

Write-Host "Move the dll and pdb files to the required visual studio folders...."
foreach ($files in $d) 
{ 
	Copy-Item -Path $mainsolutionpath\SqlServer.Rules\bin\Debug\SqlServer.Rules.dll -Destination $files
	Copy-Item -Path $mainsolutionpath\SqlServer.Rules\bin\Debug\SqlServer.Rules.pdb -Destination $files
	Copy-Item -Path $mainsolutionpath\SqlServer.Rules\bin\Debug\SqlServer.Dac.dll -Destination $files
	Copy-Item -Path $mainsolutionpath\SqlServer.Rules\bin\Debug\SqlServer.Dac.pdb -Destination $files
}

Get-Rules($sqlrulespath, $dbobjectpath)
