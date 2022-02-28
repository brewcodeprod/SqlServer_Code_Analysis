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
		$msBuildExe = Get-ChildItem -Path "C:\Program Files (x86)\Microsoft Visual Studio\" -Include MSBuild.exe -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "amd64" } | %{$_.DirectoryName} | Select-Object -First 1
		$msBuildExe = $msBuildExe + "\MSBuild.exe"

        if ($nuget) {
            Write-Host "Restoring NuGet packages" -foregroundcolor green
            #nuget restore "$($path)"
			& "$($msBuildExe)" "$($path)" /t:restore /m
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
	#Commented by Kishan on 2022-02-25. It is returning the firt node. We need all nodes.
    #$node = $XmlDocument.SelectSingleNode($fullyQualifiedNodePath, $xmlNsManager)
	$nodes = $XmlDocument.SelectNodes($fullyQualifiedNodePath, $xmlNsManager)
    return $nodes
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

function Upsert-SQL-Rules([xml]$XmlDocument, [string]$ElementPath, [string]$Element, [string]$ElementValue, [string]$NamespaceURI = "", [string]$NodeSeparatorCharacter = '.') {
    $node = Get-XmlNode -XmlDocument $XmlDocument -NodePath $ElementPath -NamespaceURI $NamespaceURI -NodeSeparatorCharacter $NodeSeparatorCharacter

	$parentNode = Get-XmlNode -XmlDocument $XmlDocument -NodePath "Project.PropertyGroup" -NamespaceURI $NamespaceURI -NodeSeparatorCharacter $NodeSeparatorCharacter
	
    if ($node)
    {
		Write-Host "Node already exists. Updating the node text value."
		foreach ($n in $parentNode) {
			if ($n.$Element) {
				$n.$Element = $ElementValue
			}
		}
    }	
	else {
	
	Write-Host "Creating a new node."
	foreach ($n in $parentNode) {
		$createNode = $XmlDocument.CreateElement($Element)		
		$createNode.InnerText = $ElementValue		
		$n.AppendChild($createNode) | Out-Null		
	}
	}				

}

function Set-SQL-Rules($sqlrulespath, $dbobjectpath) {
	
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

		$SqlCodeAnalysisRulesNode = "SqlCodeAnalysisRules"
		$SqlCodeAnalysisRules = $exclusion.Substring(0,$exclusion.Length-1)		
		
		$RunSqlCodeAnalysisNode = "RunSqlCodeAnalysis"		
		$RunSqlCodeAnalysis = "True"		
		
		$xml = [Xml] (Get-Content $dbobjectpath)	
		
		Upsert-SQL-Rules -XmlDocument $xml -ElementPath "Project.PropertyGroup.SqlCodeAnalysisRules" -Element $RunSqlCodeAnalysisNode -ElementValue $RunSqlCodeAnalysis		
		Upsert-SQL-Rules -XmlDocument $xml -ElementPath "Project.PropertyGroup.RunSqlCodeAnalysis" -Element $SqlCodeAnalysisRulesNode -ElementValue $SqlCodeAnalysisRules		

		$xml = [xml] $xml.OuterXml.Replace(" xmlns=`"`"", "")
		$xml.Save($dbobjectpath)				
}	

Function ConvertFrom-XMLtoCSV {
    [CmdletBinding()]
    <#
    .Synopsis
       Convert a uniform XML file to CSV with element names as headers
    .DESCRIPTION
       Takes a uniformed XML tree and converts it to CSV based on the XPath given.

       For example, assume a structure like this:
       <root>
           <item>
               <element1>Content1</element1>
               <element2>Content2</element2>
           </item>
           <item>
               <element1>Content1</element1>
               <element2>Content2</element2>
           </item>
       <root>

    .PARAMETER Path
        The path to the XML File

    .PARAMETER XPath
        The XPath query to the items that should be converted

    .EXAMPLE
       ConvertFrom-XMLtoCSV -Path .\file.xml -XPath "//item" 
    #> 
    Param (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][String] $Path,
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=1)][String] $XPath
    )
    Begin {
        if (Test-Path $Path) {
            [XML] $XML = Get-Content $Path -Raw
        } else {
            Throw [System.IO.FileNotFoundException] "XML file was not found at the given path"
        }
        $NodeCount = $XML.SelectNodes($XPath).Count
        $FileHeaders = [System.String]::Join(",",$($XML.SelectNodes("$XPath[1]/node()") | ForEach-Object { $_.ToString()}))
        $Content = @()
    }
    Process {
        $Content += $FileHeaders
        For ($i = 1; $i -le $NodeCount; $i++) { 
            $Content += [System.String]::Join(",",$($xml.SelectNodes("$XPath[$i]/node()") | ForEach-Object {$_."#text"}))
        }

        return $Content		
    }
}