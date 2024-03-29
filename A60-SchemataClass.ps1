<#
    Comments Inclosed in an HTML Comment block <!--  --> 
    with the member name in ANSI quotes <!-- [Member] --> 
    are used by the New-ClassHelperMaker command to auto-generate  Schemata.html

    <!-- [Synopsis]
    Builds a catalogue of Module Functions
    -->

    <!-- [Description]
    Builds catalogue of Module Defined functions using the Abstract Syntax Tree
    -->

    <!-- [ModAnchor]
	
    <li>The base directory to start searching for module files.
    <li>If Hint is a Path, it must be subsequent to $ModAnchor.
    <li>If Hint is outside of the $ModAnchor paradigm, the process will exit.
    -->
    <!-- [ExpandCatalogue]
      -------------------------<br/>
      <i><b>Bread and Butter Method</b></i><br>
      -------------------------<br/>
      <li>Method to analyze and expand the catalog of functions.
      <li>It takes a file path ($FullPath) as input and returns<br>an array of function information.
    -->

    <!-- [Show]
Show a Formatted representation of the Catalogue
-->

<!-- [Unloaded]
Returs FullPath of Files that are not currently in memmory
-->
#>

enum BruteForceSpecificity{
	IncludePath = 1 #Module Include Path
	Accumulated = 2 #Any directories in the Discovered file path
	Untitled = 16

}

class Schemata{

	[object]
	#The property that will store information about the functions found during analysis
	$Catalogue

	[string]
	# The path to the root module file (PSM1 or PSD1).
	$RootModule

	[string]
	#Name Target Module
	$TargetModule

	[string]
	$ModAnchor = $($env:PSModulePath.Split(';') -match [regex]::Escape((Split-Path $profile)))

	[timespan]
	# The time taken to process the module files.
	$Lap

	[array]
	# Files that contain the Module's Function Definitions
	$Files

	hidden
	[BruteForceSpecificity]
	$SchemaInclusion
	[string]
	#Module Hash
	$Hash

	hidden
	[hashtable]
	$PSD

	[array]
	<#  
      -------------------------<br/>
      <i><b>Bread and Butter Method</b></i><br>
      -------------------------<br/>
      <li>Method to analyze and expand the catalog of functions.
      <li>It takes a file path ($FullPath) as input and returns an array of function information.
  #>
	ExpandCatalogue ($FullPath) {

		Write-Verbose $FullPath
		$fudge = Get-Item $FullPath
		if ($fudge.GetType().Name -eq 'FileInfo') {

			# Let PowerShell build the Abstract Syntax Tree (AST) for the script file.
			$category = $(switch (Split-Path -Leaf (Split-Path $FullPath)) {
					# Determine the category based on the file name (Export or Private).
					{ $_ -in 'Export','Private' } { $_ }
					Default { 'Unknown' }
				})

			# Get the AST for the script file.
			$MyScriptBlock = Get-Command $FullPath
			$scriptAST = $MyScriptBlock.ScriptBlock.Ast

			# Search the AST for function definitions.
			$MyFunctions = foreach ($item in $scriptAST.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] },$false)) {
				# Create an object to store function information.
				$Info = [pscustomobject]@{
					Name = $item.Name
					Type = 'Function'
					IsFilter = $item.IsFilter
					#Extent=$item.extent
					StartingLineNumber = $item.Extent.StartLineNumber
					EndingLineNumber = $item.Extent.EndLineNumber
					Parameters = @()
					Category = $category
					Features = @($item.Name)
					File = $item.Extent.File
					text = $item.Extent.text
				}

				# Search each function for parameters.
				$MyParameters = $item.Body.FindAll({ $args[0] -is [System.Management.Automation.Language.ParameterAst] },$false)

				foreach ($B in $MyParameters) {
					# Add parameter information to the function object.
					$Info.Parameters += [pscustomobject]@{
						Name = $B.Name.VariablePath
						Type = @($B.Attributes.Extent.text)
					}

					# Add a feature to the function object by combining function name and parameter name.
					$info.Features += ('{0}:{1}' -f $Item.Name,($B.Name -replace '\$'))
				}

				# Search for Alias attributes in the function and add them to the AKA property.
				$aliasAST = $item.FindAll({
						$args[0] -is [System.Management.Automation.Language.AttributeAst] -and
						$args[0].TypeName.Name -eq 'Alias'
					},$true)

				$aliasAST.positionalArguments.ForEach{
					if ($info.psObject.Properties.Name.IndexOf('AKA') -lt 0) {
						$info | Add-Member -NotePropertyName 'AKA' -NotePropertyValue @()
					}
					$info.AKA += $_
				}

				# Output the function information.
				$Info
			}

			# Return the array of function information.
			$AllMyFunctions += $MyFunctions
		}
		else {
			$AllMyFunctions = $null
		}

		return $AllMyFunctions

	}

	# Constructor for the Schemata class.
	Schemata ([string]$Hint) {
		# Initialize the class properties.
		$this.TargetModule = $Hint

		$This.Init()
	}
	Schemata ([string]$Hint,[string]$ModAnchor) {
		# Initialize the class properties.
		$this.TargetModule = $Hint
		$this.ModAnchor = $ModAnchor
		$This.Init()
	}
	Schemata ([string]$Hint,[string]$ModAnchor,[BruteForceSpecificity]$CollectionMode) {
		# Initialize the class properties.
		$this.TargetModule = $Hint
		$this.ModAnchor = $ModAnchor
		$this.SchemaInclusion = $this.SchemaInclusion -bor $CollectionMode
		$This.Init()
	}

	Schemata ([string]$Hint,[hashtable]$Options) {
		# Initialize the class properties.
		$this.TargetModule = $Hint
		if ($Options.BruteForceSpecificity) {
			$this.SchemaInclusion = $this.SchemaInclusion -bor $Options.BruteForceSpecificity
		}
		$This.Init()
	}

	# Hidden method to initialize the class properties based on the provided hint.
	hidden Init () {
		# Hint can either be:
		# - The full path to the module PSM1 or PSD1 file.
		# - The module home directory.
		# - The name of the module (If only the module name is given, it is assumed to be in the Current User's PSModulePath).

		# Record the start time to measure the processing time later.
		$markTime = [datetime]::Now

		# Initialize the RootModule property to null.
		$this.RootModule = $null

		# Check if the provided hint is a valid path to a module file.
		#if ((Test-Path $this.TargetModule) -and ((split-path $this.TargetModule) -eq '')) {
		$fudge = $false
		if (Test-Path (Join-Path $this.ModAnchor $this.TargetModule)) {
			$Fudge = Get-Item (Join-Path $this.ModAnchor $this.TargetModule)
		}
		if ($Fudge) {
			if ($Fudge.Extension -eq '.PSM1') {
				$this.RootModule = $this.TargetModule
			}
			# If the RootModule is not set yet and the hint is a PSD1 file, try to get the RootModule from the PSD1 file.
			if (!$this.RootModule) {
				if ($Fudge.Extension -eq '.PSD1') {
					$this.RootModule = Join-Path (Split-Path $this.TargetModule) (Import-PowerShellDataFile $this.TargetModule).RootModule
				}
			}
		}

		# If the RootModule is still not set, try to find it in the ModAnchor directory using the provided hint.
		if (!$this.RootModule) {
			$folder = Join-Path $this.ModAnchor $this.TargetModule
			$fudge = @()
			if (Test-Path $folder) {
				Write-Verbose $folder
				$Fudge = (Get-ChildItem $folder -Filter *.psm1 | Sort LastWriteTime | Select-Object -Last 1)
				if ($fudge) {
					$This.RootModule = $fudge.FullName
				}
			}
		}

		# If the RootModule is still not set, display a warning message and return.
		if (!$this.RootModule) {
			Write-Warning 'The RootModule cannot be determined.'
			Write-Warning 'Please provide the full path name of the root module.'
			return
		}

		# Get the content of the RootModule file and identify "dot-sourced" files.
		$DotSourcedFiles = ((Get-Content $this.RootModule).Trim() -match '^\.' -replace [regex]::Escape('$PSSCRIPTROOT'),(Split-Path $this.RootModule) -replace '^\.' -replace '"').Trim()

		# If bruteForce is enabled, also search for .ps1 files in the RootModule directory and subdirectories.
		if (([bool]$this.SchemaInclusion)) {
			[array]$DotSourcedFiles += (Get-ChildItem (Join-Path ([io.path]::GetDirectoryName($this.RootModule)) Include) -Recurse -File *.ps1).FullName
			if (([BruteForceSpecificity]$this.SchemaInclusion).HasFlag([BruteForceSpecificity]::Accumulated)) {
				$folders = $DotSourcedFiles.ForEach{ (Get-Item $_).DirectoryName } |
				Select-Object -Unique
				Where-Object { $_.DirectoryName -ne (Split-Path $this.RootModule) }
				$mofiles = foreach ($folder in $folders) {
					if ($folder -ne (Split-Path $this.RootModule)) {
						(Get-ChildItem $folder -Filter .ps1 -Recurse).FullName
					}
				}

				$DotSourcedFiles += $mofiles | Where-Object BaseName -NotMatch '^Untitled'
			}

		}

		# Remove duplicates from the list of dot-sourced files.
		$DotSourcedFiles = $DotSourcedFiles | Select-Object -Unique

		$Data = Import-PowerShellDataFile $([io.path]::ChangeExtension($this.RootModule,'PSD1'))
		$DotSourcedFiles += @($data.ScriptsToProcess).ForEach{
			Get-Item (Join-Path ([io.path]::GetDirectoryName($this.RootModule)) $_)
		}
		$this.PSD = $Data
		# Initialize the Catalogue property as an empty array.
		$this.Catalogue = @()

		# Iterate through each dot-sourced file and expand the catalog using the $ColExpandCatalogue method.
		foreach ($file in $DotSourcedFiles) {

			$This.Catalogue += $this.ExpandCatalogue($file)
		}

		# Get the unique module file paths from the catalog and convert them into FileInfo objects.
		$this.Files = @($this.Catalogue.File | Select-Object -Unique).ForEach{

			Get-Item $_
		}
		$this.hash = $this.SchemaHash()
		$this.ButchUp()

		# Calculate the processing time and store it in the Lap property.
		$this.Lap = New-TimeSpan $markTime
	}

	[string[]]
	#Returs FullPath of Files that are not currently in memmory
	Unloaded () {

		# Get the currently loaded functions and create a hash table for faster lookups
		$Defined = Get-ChildItem 'function:' | Group-Object Name -AsString -AsHashTable

		$pile = $this.Catalogue.ForEach{
			if ($_.File) {
				$Focus = $Defined["$($_.Name)"]

				[pscustomobject]@{

					Loaded = ($Focus.Source -eq $this.TargetModule)
					File = $_.File

				}
			}

			#if (![bool]$Defined["$($_.Name)"]) { $_.File }
		}
		return ($pile | Where-Object Loaded -EQ $False).File | Sort -Unique

	}

	[void]
	#Show a Formatted representation of the Catalogue
	Show () {
		$Cols = @()
		$Cols += 'Category'
		$Cols += @{ N = 'Type'; E = { if ($_.IsFilter) { 'Filter' } else { $_.'Type' } } }
		$Cols += 'Name'
		$Cols += @{ N = 'Alias'; E = 'AKA' }

		$this.Catalogue | Select-Object $Cols | Sort Name | Out-Host
		$this.Files | Out-Host

	}
	[string[]]

	<#
<!-- [Features]
List of Module Features

-->
#>
	Features () {
		return $this.Catalogue.Features
	}
	<#
      <!-- [Persist]
      Save a copy of the catalog version to disk
      -->
  #>
	Persist () {

		$folder = Join-Path ([io.path]::GetDirectoryName($this.RootModule)) 'ETC'
		$pat = "$($this.TargetModule)-$($this.PSD.ModuleVersion -replace '\.','~')"
		if (!(Test-Path $folder)) {
			New-Item $folder -ItemType Directory
		}
		#Persisted Catalogue Summary
		$pcs = [pscustomobject]@{
			Module = $this.TargetModule
			Version = $this.PSD.ModuleVersion
			hash = $this.hash
			Catalogue = $this.Catalogue
		}
		$pcs | Export-Clixml -Path (Join-Path $folder "$($pat)-$('{0:x15}' -f (Get-date).Ticks).pcs")
	}

	hidden [string] Reconnoiter ([string]$Version) {
		$folder = Join-Path ([io.path]::GetDirectoryName($this.RootModule)) 'ETC'
		if (!$version) {
			$version = $this.PSD.ModuleVersion
		}
		$pat = "$($this.TargetModule)-$( $version -replace '\.','~')"

		$Persisted = $null
		if (Test-Path $folder) {
			$Persisted = Get-ChildItem $folder |
			Where-Object Name -Match ([regex]::Escape($pat)) |
			Sort LastWriteTime -Descending |
			Sort Name -Descending |
			Select-Object -First 1
		}
		$Alpha,$bravo,$fudge = $null
		if ($Persisted) {
			$fudge = Import-Clixml $Persisted.FullName
			if ($fudge) {
				$Alpha = $Fudge.Catalogue.Features | Sort -Unique
			}
			$bravo = $this.Catalogue.Features | Sort -Unique
		}

		$changes = Compare-Object $Alpha $bravo
		$missing = $changes | Where-Object SideIndicator -EQ '<='
		$enhancement = $changes | Where-Object SideIndicator -EQ '=>'

		$v = $Version.Split('.')

		if ($missing) {
			[int]$v[1] += 1
		} else {
			if ($enhancement) {
				[int]$v[2] += 1
			}
			else {
				if ($this.hash -ne $fudge.hash) {
					[int]$v[3] += 1
				}
			}
		}

		return $($v -join '.')
	}

	[string]
	<#
      <!-- [Reversion]
      Calculate the Modified Symantic Version number
      -->
  #>

	Reversion () {

		return $($this.Reconnoiter($null))
	}
	[string] Reversion ([string]$Version)
	{
		return $($this.Reconnoiter($Version))
	}
	[void] static help ()
	{

		$CallStack = Get-PSCallStack
		$line = $callStack[0].InvocationInfo.Line
		$pattern = '(?<=\[).+?(?=\])'
		$BaseName = [regex]::Matches($line,$pattern).Value

		$HelpFile = Get-ChildItem (Split-Path $CallStack[0].ScriptName) |
		Where-Object { $_.BaseName -eq $BaseName } |
		Where-Object { $_.Extension -eq '.html' }
		if ($HelpFile) {
			$HelpFile | Invoke-Item
		}
	}
	hidden [void] ButchUp () {
		$TTN = $this.GetType().Name
		$this.psTypeNames.Add($TTN)

		if (!(Get-FormatData -TypeName $TTN -PowerShellVersion $global:PSVersionTable.PSVersion)) {
			$FormatFile = Join-Path $PSScriptRoot ('{0}.Format.ps1Xml' -f $TTN)
			if (Test-Path $FormatFile) {
				Update-FormatData $FormatFile
			}
		}

	}
	[string] ToString () {

		$Missing = $this.Unloaded()
		$Alpha = $this.Catalogue | Group-Object File
		$E = [regex]::Escape("$($this.ModAnchor)\")

		$Bravo = foreach ($item in $Alpha) {
			[pscustomobject]@{ Name = ($item.Name -replace $E)
				IsLoaded = ![bool]($item.Name -in $Missing)
				Command = $item.Group.Name
			}

		}

		$Msg = @(($Bravo | Format-Table | Out-String).Trim())
		$Msg += ([pscustomobject]@{
				'Module Name' = $this.TargetModule
				'Root Module' = $this.RootModule
				'Lap' = $this.Lap } |
			Format-List |
			Out-String)

		return ($msg)
	}
	hidden [string] SchemaHash () {

		$blob = foreach ($file in $this.Files) {
			([io.file]::ReadAllText($file.FullName)).Trim()
		}
		$tempFile = New-TemporaryFile
		$blob | Out-File $tempFile

		$Result = $(Get-FileHash $tempFile)
		Remove-Item $tempFile
		return $Result.hash
	}

}
<#
    New-ClassHelperMaker "[Schemata]::new('PSSWD')" -Install
#>
#Remove-Module $((Get-Item (Get-PSCallStack).ScriptName).BaseName)
<#
    $C = [Schemata]::new('OSGPSX')
    $C.Unloaded()
#>

<#
    #Example Block - Start
    
    .EXAMPLE
    
    # Create an instance of the Schemata class with the module name 'OSGCredentials'.
    # The Init method will be called to initialize the properties and perform the analysis.
    $S = [Schemata]::new('OSGPSX')

    # Call the Unloaded method to get the unloaded functions from the catalog.
    $S.Unloaded().ForEach{
    Write-Verbose "Dotsourcing '$_'" -Verbose
    . "$_"

    }
    $S.Show()
    $S.Unloaded()
    $S
    #Example Block - End
#>
<#
    $A = [schemata]::new('OSGPSX')
    $A.Persist()

    $A.Reversion()

#>
<#
    $splat=@{
    ConstructorString="[Schemata]::new('OSGPSX')"
    ClassPath= $((Get-PSCallStack)[0].ScriptName)
    }


    New-ClassHelperMaker  @Splat
#>

<#
$Splat=@{}
$splat.ConstructorString="[Schemata]::new('OSGPSX')"

$S=Invoke-Expression $splat.ConstructorString

$Splat.ClassPath=(
  $S.Files|
  Where {$_.Name -Match $S.GetType().Name}|
  Where {$_.Name -match 'Class'}).FullName
  
New-ClassHelperMaker @Splat
#>
