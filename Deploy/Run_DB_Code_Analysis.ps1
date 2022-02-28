Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Write-Host "Building the solution from powershell"

#importing child scripts
. .\Functions.ps1

Write-Host "Getting the values from the properties file...."
$Prop = ConvertFrom-StringData (Get-Content .\Properties.txt -raw)
$mainsolutionpath = $Prop.VsSolutionPath
$dbobjectpath = $Prop.DBProjectPath
$outputpath = $Prop.OutputPath
$sqlrulespath = $Prop.SQLRulesPath

Write-Host "Getting MSBuild.exe path..."
$msBuildExe = Get-ChildItem -Path "C:\Program Files (x86)\Microsoft Visual Studio\" -Include MSBuild.exe -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "amd64" } | %{$_.DirectoryName} | Select-Object -First 1
$msBuildExe = $msBuildExe + "\MSBuild.exe"

Write-Host "Getting DB project xml data..."
$xml = [Xml] (Get-Content $dbobjectpath)	

Write-Host "Taking DB project file backup..."
$dbobjectfile = Split-Path $dbobjectpath -leaf
$currentpath = Get-Location | Select -ExpandProperty Path
$dbobjectpath_bkp = $currentpath + "\" + $dbobjectfile
write-host $dbobjectpath_bkp
$xml.Save($dbobjectpath_bkp)
$dbdir = Get-ChildItem $dbobjectpath | %{ $_.DirectoryName }

Write-Host "Configuring the SQL rules..."
Set-SQL-Rules $sqlrulespath $dbobjectpath

#Run code analysis
Write-Host "Running SQL code analysis on the configured rules..."
& $msBuildExe /p:OutputPath=$outputpath /p:RunSqlCodeAnalysis=True $dbobjectpath	
		
Write-Host "Restoring the project file..."
Copy-Item -Path $dbobjectpath_bkp -Destination $dbdir

Write-Host "Deleting the backup project file..."
Remove-Item $dbobjectpath_bkp

#XML to CSV conversion
Write-Host "Converting XML file to CSV file..."
$datestring = (Get-Date).ToString("s").Replace(":","-")
$csvFile = $outputpath + "\" + [System.IO.Path]::GetFileNameWithoutExtension($dbobjectpath) + "_" + $datestring + ".csv"
$xmlFile = $outputpath + "\" + [System.IO.Path]::GetFileNameWithoutExtension($dbobjectpath) + ".StaticCodeAnalysis.Results.xml"

if (Test-Path $csvFile) {
  Remove-Item $csvFile
  write-host "CSVFile has been deleted"
}
else {
  Write-host "CSV file does not exist."
}

$XMLConvertedData = ConvertFrom-XMLtoCSV -Path $xmlFile -XPath "//Problem" 
#write-host "CSV data loading..."
New-Item $csvFile -ItemType File
Set-Content $csvFile $XMLConvertedData
write-host "XML to CSV convertion completed..."