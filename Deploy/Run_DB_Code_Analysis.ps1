Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Write-Host "Building the solution from powershell"

#importing child scripts
. .\Functions.ps1

Write-Host "Get the values from the properties file...."
$Prop = ConvertFrom-StringData (Get-Content .\Properties.txt -raw)
$mainsolutionpath = $Prop.VsSolutionPath
$dbobjectpath = $Prop.DBProjectPath
$outputpath = $Prop.OutputPath
$sqlrulespath = $Prop.SQLRulesPath

Write-Host "Get MSBuild.exe path..."
$msBuildExe = Get-ChildItem -Path "C:\Program Files (x86)\Microsoft Visual Studio\" -Include MSBuild.exe -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "amd64" } | %{$_.DirectoryName}
$msBuildExe = $msBuildExe + "\MSBuild.exe"

Write-Host "Get DB project xml data..."
$xml = [Xml] (Get-Content $dbobjectpath)	

Write-Host "Taking DB project file backup..."
$dbobjectfile = Split-Path $dbobjectpath -leaf
$currentpath = Get-Location | Select -ExpandProperty Path
$dbobjectpath_bkp = $currentpath + "\" + $dbobjectfile
write-host $dbobjectpath_bkp
$xml.Save($dbobjectpath_bkp)
$dbdir = Get-ChildItem $dbobjectpath | %{ $_.DirectoryName }

Write-Host "Configuring the SQL rules..."
Get-Rules $sqlrulespath $dbobjectpath $msBuildExe $outputpath

#Run code analysis
Write-Host "Running SQL code analysis on the configured rules..."
& $msBuildExe /p:OutputPath=$outputpath /p:RunSqlCodeAnalysis=True $dbobjectpath	
		
Write-Host "Restoring the project file..."
Copy-Item -Path $dbobjectpath_bkp -Destination $dbdir

Write-Host "Deleting the backup project file..."
Remove-Item $dbobjectpath_bkp
