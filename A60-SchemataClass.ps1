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

#>

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
  <#
      <li>The base directory to start searching for module files.
      <li>If Hint is a Path, it must be subsequent to $ModAnchor.
      <li>If Hint is outside of the $ModAnchor paradigm, the process will exit.
  #>
  $ModAnchor = $($env:PSModulePath.Split(';') -match [regex]::Escape((Split-Path $profile)))

  [timespan]
  # The time taken to process the module files.
  $Lap

  [array]
  # Files that contain the Module's Function Definitions
  $Files

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
    if (Test-Path $this.TargetModule) {
      $Fudge = Get-Item $this.TargetModule
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
      if (Test-Path $folder) {
        $This.RootModule = (Get-ChildItem $folder -Filter *.psm1 | sort LastWriteTime | Select-Object -Last 1).FullName
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
    if ($this.bruteForce) {
      [array]$DotSourcedFiles += (Get-ChildItem (Join-Path ([io.path]::GetDirectoryName($this.RootModule)) Include) -Recurse -File *.ps1).FullName
    }

    # Remove duplicates from the list of dot-sourced files.
    $DotSourcedFiles = $DotSourcedFiles | Select-Object -Unique

    # Initialize the Catalogue property as an empty array.
    $this.Catalogue = @()

    # Iterate through each dot-sourced file and expand the catalog using the $ColExpandCatalogue method.
    foreach ($file in $DotSourcedFiles) {
      $This.Catalogue += $this.ExpandCatalogue($file)
    }

    # Get the unique module file paths from the catalog and convert them into FileInfo objects.
    $this.Files = @($this.Catalogue.File | Select-Object -Unique).ForEach{ Get-Item $_ }

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
    return ($pile | Where-Object Loaded -EQ $False).File | sort -Unique

  }

  [void]
  #Show a Formatted representation of the Catalogue
  Show () {
    $Cols = @()
    $Cols += 'Category'
    $Cols += @{ N = 'Type'; E = { if ($_.IsFilter) { 'Filter' } else { $_.'Type' } } }
    $Cols += 'Name'
    $Cols += @{ N = 'Alias'; E = 'AKA' }

    $this.Catalogue | Select-Object $Cols | sort Name | Out-Host
    $this.Files | Out-Host

  }
  [string[]]
  #List of Module Features
  Features () {
    return $this.Catalogue.Features
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

    #Remove-TypeData 'OSG.FlashID'
    #Remove-TypeDate 'FlashID'
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
    [array]$Msg = [pscustomobject]@{ 'Module Name' = $this.TargetModule; 'Root Module' = $this.RootModule; 'Lap' = $this.Lap } | Format-List | Out-String
    $Msg += $Bravo | Format-Table | Out-String

    return ($msg)
  }

}

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

#New-ClassHelperMaker "[Schemata]::new('OSGPSX')" -Install
#Remove-Module $((Get-Item (Get-PSCallStack).ScriptName).BaseName)
<#
$C = [Schemata]::new('OSGPSX')
$C.Unloaded()
#>


