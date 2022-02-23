function buildVS
{
    param
    (
        [parameter(Mandatory=$true)]
        [String] $path,

        [parameter(Mandatory=$false)]
        [bool] $nuget = $true,
        
        [parameter(Mandatory=$false)]
        [bool] $clean = $true
    )
    process
    {
		$msBuildExe = Get-ChildItem -Path "C:\Program Files (x86)\Microsoft Visual Studio\" -Include msbuild.exe -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "amd64" } | %{$_.DirectoryName}
		$msBuildExe = $msBuildExe + "\msbuild.exe"

        if ($nuget) {
            Write-Host "Restoring NuGet packages" -foregroundcolor green
            nuget restore "$($path)"
        }

        if ($clean) {
            Write-Host "Cleaning $($path)" -foregroundcolor green
            & "$($msBuildExe)" "$($path)" /t:Clean /m
        }

        Write-Host "Building $($path)" -foregroundcolor green
        & "$($msBuildExe)" "$($path)" /t:Build /m
    }
}

function Get-XmlNode([ xml ]$XmlDocument, [string]$NodePath, [string]$NamespaceURI = "", [string]$NodeSeparatorCharacter = '.')
{
    # If a Namespace URI was not given, use the Xml document's default namespace.
    if ([string]::IsNullOrEmpty($NamespaceURI)) { $NamespaceURI = $XmlDocument.DocumentElement.NamespaceURI }

    # In order for SelectSingleNode() to actually work, we need to use the fully qualified node path along with an Xml Namespace Manager, so set them up.
    $xmlNsManager = New-Object System.Xml.XmlNamespaceManager($XmlDocument.NameTable)
    $xmlNsManager.AddNamespace("ns", $NamespaceURI)
    $fullyQualifiedNodePath = "/ns:$($NodePath.Replace($($NodeSeparatorCharacter), '/ns:'))"

    # Try and get the node, then return it. Returns $null if the node was not found.
    $node = $XmlDocument.SelectSingleNode($fullyQualifiedNodePath, $xmlNsManager)
    return $node
}

function Set-XmlElementsTextValue([ xml ]$XmlDocument, [string]$ElementPath, [string]$TextValue, [string]$NamespaceURI = "", [string]$NodeSeparatorCharacter = '.')
{
    # Try and get the node.
    $node = Get-XmlNode -XmlDocument $XmlDocument -NodePath $ElementPath -NamespaceURI $NamespaceURI -NodeSeparatorCharacter $NodeSeparatorCharacter

    # If the node already exists, update its value.
    if ($node)
    {
        $node.InnerText = $TextValue
    }
    # Else the node doesn't exist yet, so create it with the given value.
    else
    {
        # Create the new element with the given value.
        $elementName = $ElementPath.SubString($ElementPath.LastIndexOf($NodeSeparatorCharacter) + 1)
         $element = $XmlDocument.CreateElement($elementName, $XmlDocument.DocumentElement.NamespaceURI)
        $textNode = $XmlDocument.CreateTextNode($TextValue)
        $element.AppendChild($textNode) > $null

        # Try and get the parent node.
        $parentNodePath = $ElementPath.SubString(0, $ElementPath.LastIndexOf($NodeSeparatorCharacter))
        $parentNode = Get-XmlNode -XmlDocument $XmlDocument -NodePath $parentNodePath -NamespaceURI $NamespaceURI -NodeSeparatorCharacter $NodeSeparatorCharacter

        if ($parentNode)
        {
            $parentNode.AppendChild($element) > $null
        }
        else
        {
            throw "$parentNodePath does not exist in the xml."
        }
    }
}

function Get-Rules($sqlrulespath, $dbobjectpath) {
	$Prop = ConvertFrom-StringData (Get-Content .\Properties.txt -raw)
	$dbobjectpath = $Prop.DBProjectPath

	$currentpath = Get-Location | Select -ExpandProperty Path
	$rules = Import-Csv $sqlrulespath

	$exclusion = "-Microsoft.Rules.Data.SR0001;-Microsoft.Rules.Data.SR0004;-Microsoft.Rules.Data.SR0005;-Microsoft.Rules.Data.SR0006;-Microsoft.Rules.Data.SR0007;-Microsoft.Rules.Data.SR0008;-Microsoft.Rules.Data.SR0009;-Microsoft.Rules.Data.SR0010;-Microsoft.Rules.Data.SR0011;-Microsoft.Rules.Data.SR0012;-Microsoft.Rules.Data.SR0013;-Microsoft.Rules.Data.SR0014;-Microsoft.Rules.Data.SR0015;-Microsoft.Rules.Data.SR0016;"

	foreach($line in $rules)
		{
			#"The ID: $($line.Rule), Name: $($line.Type), the Age: $($line.Enable)"
			if ($line.Enable -eq 'N')
			{
				$exclusion = $exclusion + "-Rules." + $line.Rule + ";"
			}
		}

		$exclusion = $exclusion.Substring(0,$exclusion.Length-1)

		$xml = [Xml] (Get-Content $dbobjectpath)

		Set-XmlElementsTextValue -XmlDocument $xml -ElementPath "Project.PropertyGroup.SqlCodeAnalysisRules" -TextValue $exclusion
		$xml.Save($dbobjectpath)	
	}	