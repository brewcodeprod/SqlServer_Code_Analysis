Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

$currentpath = Get-Location | Select -ExpandProperty Path
$scriptList = @(
    $currentpath + '\Build_Rule_Engine.ps1'
    $currentpath + '\Conf_DB_Rules.ps1'
);

foreach ($script in $scriptList) {
    & $script 
}