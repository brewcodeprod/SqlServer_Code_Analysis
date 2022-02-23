Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

$Prop = ConvertFrom-StringData (Get-Content .\Properties.txt -raw)
$mainsolutionpath = $Prop.VsSolutionPath
$dbobjectpath = $Prop.DBProjectPath
$outputpath = $Prop.OutputPath
$sqlrulespath = $Prop.SQLRulesPath

$msBuildExe = Get-ChildItem -Path "C:\Program Files (x86)\Microsoft Visual Studio\" -Include msbuild.exe -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "amd64" } | %{$_.DirectoryName}
$msBuildExe = $msBuildExe + "\msbuild.exe"
		
Write-Host "Running DB code analysis...."
& $msBuildExe /p:OutputPath=$outputpath /p:RunSqlCodeAnalysis=True $dbobjectpath