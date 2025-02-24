<#
    .AUTHORSHIP
    
    Creator            : Chuck Sharpe 
    Created Date       : 01-Jan-2025 02:12 PM 
    Environment        : Windows PowerShell ISE Host 
    PowerShell Version : 5.1.19041.5247 
    TimeStamp          : 2025-01-01T14:12:50-05:00 
    Time Zone          : Eastern Standard Time
#>

# Define a class to manage and store custom streams with foreground and background colors.
class ColorSplat {
	<#
      Comments Inclosed in an HTML Comment block <!--  --> 
      with the member name in ANSI quotes <!-- [Member] --> 
      are used by the New-ClassHelperMaker command to auto-generate  ColorSplat.html
	#>
	<#
      <!-- [Synopsis]
      A PowerShell class to manage and store custom streams with foreground and background colors.
      -->
      
      <!-- [Description]
      The <i><b>
      <Font Color='DodgerBlue' Size="+1">Color</Font><Font Size="+1" Color='Red'>Splat</font>
      </b></i> class provides a mechanism to define, manage, and persist custom streams.
      These streams are associated with foreground and background colors and can be invoked to 
      create variables in the script scope.
      -->
      
	#>
	[string]
	<#
      <!-- [ConfigurationName]
      The Name of the configuration being mananged.  Duh!
      -->
	#>
	$ConfigurationName
	[hashtable]
	<#
      <!-- [DefinedStreams]
      A hashtable containing the stream definitions and their configurations.
      -->
	#>
	$DefinedStreams = @{}
	[string]
	<#
      <!-- [FileName]
      The path to the file where configurations are stored.
      -->
      
	#>
	$FileName

      <#	
      <!-- [Postfix]
      term appended to end of Invoke variable
      -->
      
	#>
	hidden [string]$Postfix = $this.GetType()

	# Overloaded method to expand multiple streams with specified configurations.
	hidden PushStreams ([array[]]$streams) {

		<#
        <!-- [PushStreams]
        Push all streams at once in an array of arrays
        -->
		#>

		foreach ($stream in $streams) {

			if ($stream.count -eq 2) {
				$stream += $null
			}

			$this.PushStream($stream[0], $stream[1], $stream[2])
		}

	}
	# Overloaded method to expand a single stream with a foreground color only.
	PushStream ([string]$stream, [string]$foreground) {
		$this.PushStream($stream, $foreground, $null)
	}

	#Stream is an array passed as 'Stream|ForeGround|BackGround'
	#There can be Several Streams Passes at the same time
	AssertFireHose ([String[]]$Ammo) {
  
		<#
        <!-- [AssertFireHose]
        <ul><li>Push multiple streams as once
        <li>Streams are of the form 'Stream|ForeGround|BackGround'
        -->
		#>
		$Salvo = @()
		foreach ($round in $Ammo) {
			$rounds = $round.split('|')
			if ($rounds.count -gt 1) {
				$salvo += , $rounds
			}

		}
		if ($Salvo) {
			$this.PushStreams($Salvo)
		}

	}
	# Expand a single stream with both foreground and background

	PushStream ([string]$stream, [string]$foreground, [string]$background) {

		<#
        <!-- [PushStream]
        Adds or updates streams with specific color configurations.
        -->
		#>

		if ([string]::IsNullOrEmpty($stream)) {
			throw 'Stream name can not be null or empty'
		}

		if ([string]::IsNullOrEmpty($foreground)) {
			throw 'foreground color can not be null or empty'
		}

		$validColors = [Enum]::GetValues([ConsoleColor])

		if ($foreground -notin $validColors) {
			throw "Invalid foreground color: $foreground. Valid options are: $($validColors -join ', ')"
		}

		if ($background -notin $validColors) {
			throw "Invalid background color: $background. Valid options are: $($validColors -join ', ')"
		}

		$validStream = $stream -replace '\s+'

		if ($validStream -match '(?<=^\$)[^a-zA-Z0-9_{]|(?<=^\$\{)[^a-zA-Z0-9 _\-}]|(?<!^\$\{)[^\w]') {
			throw 'Invalid Characters in Variable Name'
		}

		if ($stream -ne $validStream) {
			Write-Warning "'$stream' modified to $validStream"
			$stream = $validStream
		}

		# Remove the stream if it already exists in the hashtable.

		if ($this.DefinedStreams.ContainsKey($stream)) {
			$this.DefinedStreams.Remove($stream)
		}

		# Add the new stream configuration.
		$this.DefinedStreams.$stream = [ordered]@{}

		if (!([string]::IsNullOrEmpty($foreground))) {
			$this.DefinedStreams.$stream.ForegroundColor = $foreground
		}

		if (!([string]::IsNullOrEmpty($background))) {
			$this.DefinedStreams.$stream.BackgroundColor = $background
		}

		#$this.DefinedStreams.$stream.NoNewLine = $true
		# Save the updated configuration to the file.
		$this.DefinedStreams | Export-Clixml -Path $this.FileName
	}

	ColorSplat ([string]$Command) {
		$this.Chain($Command, $false)
	}

	ColorSplat ([string]$Command, [bool]$validate) {
		$this.Chain($Command, $validate)
	}

	# Constructor to initialize the class with a command name.
	hidden Chain ([string]$Command, [bool]$validate) {

		try {

			# Verify if the provided command exists in the current session.
			$FatCommand = Get-Command $Command

			if ($FatCommand.ResolvedCommand) {
				$this.ConfigurationName = $FatCommand.ResolvedCommandName
			}

			else {

				if ($FatCommand.Name) {
					$this.ConfigurationName = $FatCommand.Name
				}

				else {
					$this.ConfigurationName = $Command
				}

			}
		}
		catch {

			if ($validate) {
				Write-Warning -Message "Command '$Command' not found."
			}

			else {
				$this.ConfigurationName = $Command
			}

		}

		if ($this.ConfigurationName) {
			$this.Initialize()
		}

		else {
			throw 'No valid configuration name'
		}

	}
	# Initialize the class by creating necessary directories and loading existing configurations.
	[void] hidden Initialize () {

		<#
        <!-- [Initialize]
        Prepares the environment by creating necessary directories and loading existing configurations from disk.
        -->
		#>

		# Define the directory path for storing configurations.
		$targetTree = @((Split-Path $global:profile), 'ETC', 'ColorSplat')

		for ($i = 1; $i -lt $targetTree.count; $i++) {

			$path = $targetTree[0..$i] -join '\'
			# Create the directory if it does not exist.

			if (!(Test-Path $path)) {
				New-Item $path -ItemType Directory
			}

			# Define the file name for storing stream configurations.
			$this.FileName = Join-Path -Path ($targetTree -join '\') -ChildPath "$($this.ConfigurationName)_colors.dat"
			# Load existing configurations if the file exists.
		}

		if (Test-Path -Path $this.FileName) {
			$this.DefinedStreams = Import-Clixml -Path $this.FileName
		}

	}
	# Custom string representation of the class for displaying stream configurations.
	[string] ToString () {

		# Return an empty string if no streams are defined.

		if ([string]::IsNullOrEmpty($this.DefinedStreams.Keys)) {
			return ''
		}

		$streams = $this.DefinedStreams
		# Calculate the maximum width of stream names for alignment.
		$MaxStreamWidth = $streams.Keys.ForEach{ $_.Length } |
			Sort-Object |
			Select-Object -Last 1
		$result = @()
		# Add headers to the output.
		$result += "{0,-$MaxStreamWidth} {1,-11} {2,-11} " -f @('Name', 'ForegroundColor', 'BackgroundColor')
		$result += "{0,-$MaxStreamWidth} {1,-15} {2,-15} " -f $(@(''.PadLeft($MaxStreamWidth), 'ForegroundColor', 'BackgroundColor').ForEach{ ''.PadLeft($_.Length, '-') })

		foreach ($key in $streams.Keys | sort) {

			# Add each stream's configuration to the output.
			$result += "{0,-$MaxStreamWidth} {1,15} {2,15}" -f $key, $streams.$key.ForegroundColor, $streams.$key.BackgroundColor
		}

		return $result -join "`n"
	}

	# Reset the configuration by deleting the file and clearing the hashtable.
	[void] Reset () {
		<#
        <!-- [Reset]
        Reset the configuration by deleting the file and clearing the hashtable.
        -->
		#>

		if (Test-Path -Path $this.FileName) {
			Remove-Item -Path $this.FileName -Verbose
		}

		$this.DefinedStreams = @{}
	}
	static help () {

		$helpfile = ''
		$cs = (Get-PSCallStack)

		if ($cs) {
			$cfile = Get-Item -Path $cs[0].ScriptName
			$className = ($cs[1].Position.Text -split '::')[0] -replace ']|\['
			$helpfile = Join-Path -Path $cfile.DirectoryName -ChildPath "$($className).html"
		}

		if (Test-Path $helpfile) {
			Invoke-Item $helpfile 
		}

		else {
			Write-Warning -Message "Can't find $helpfile.  Oops.  8-|"
		}

	}
	Reveal () {
		$this.Reveal($true, $false)
	}

	Reveal ([bool]$Brief) {
		$this.Reveal($Brief, $false)
	}

	hidden ToNotePad () {
		$this.Reveal($true, $true)
	}

	Reveal ([bool]$Brief, [bool]$notePad) {

		<#
        <!-- [Reveal]
        <ul><li>Show The Names of the Variables exported by the .Invoke() Method in the specified splat colors
        <li>If Brief is True (the default) only the variable name is shown, otherwise the values of the hash table are shown as well
        <li>If notePad is True, a text file is opened in Notepad revealing the results
        -->
		#>
		if ($this.DefinedStreams.Count -eq 0) {
			Write-Warning 'There are currently no defined streams'
			return
		}

		$streams = $this.DefinedStreams
		$wide = ($this.DefinedStreams.Keys.ForEach{ ([string]$_).Length } | sort | select -Last 1) + $this.Postfix.Length + 2
   
		$splatters = [ColorSplat]::new('ColorSplat')
		$splatters.Invoke()
		$tag = '{0:X7}' -f [int]((Get-Date).TimeOfDay.TotalMilliseconds)
		$transcriptFile = $null
		do {
			$transcriptFile = (Join-Path -Path $env:TEMP -ChildPath $(("$($this.gettype().name)_{0}.TXT") -f $tag))
		} while (Test-Path $transcriptFile)
		Start-Transcript -Path $transcriptFile

		$ArrayPieces = @()
		$FlatPieces = @()
		@($streams.GetEnumerator() | sort Name).ForEach{
			$StreamDetails = @() # Array to store details of the current stream
			$StreamDetails += $_.Name # Add the stream name
			$StreamProperties = $_.Value # Retrieve the hashtable of stream properties

			# Iterate over the keys in the hashtable and add their values to the array
			@('ForegroundColor', 'BackgroundColor').ForEach{
				$StreamDetails += $($StreamProperties."$_")
			}

			# Convert each element in the array to a quoted string and join them with commas
			$StreamDetails = $StreamDetails.ForEach{
       
				if (![string]::IsNullOrEmpty($_)) {
					"$_" 
				}

			}
			$ArrayPieces += "@($($StreamDetails.ForEach{"'$_'"} -join ','))"
			$FlatPieces += $StreamDetails -join '|'
		}

		$className = $this.GetType().Name
		Write-Host
		Write-Host '#Create ColorStream:'
		Write-Host $("`${0} = [{0}]::New('{1}')" -f $className, $this.ConfigurationName)
    
		foreach ($piece in $ArrayPieces) {
			Write-Host $('${0}.PushStream({1})' -f $className, $($piece -replace '@\(|\)'))
		}

		Write-Host

		Write-Host
		Write-Host 'Array for PushStreams Method:' @global:Header_ColorSplat
		$Alpha = "@($($ArrayPieces -join ','))"
		Write-Host $Alpha @global:Normal_ColorSplat

		Write-Host
		Write-Host 'One Liner:' @global:Header_ColorSplat
		$oneLiner = "[ColorSplat]::new('$($this.ConfigurationName)').PushStreams($alpha)"
		Write-Host $oneLiner @global:Normal_ColorSplat
    
		Write-Host
		Write-Host 'Array for AssertFirehose Method:' @global:Header_ColorSplat
		$Bravo = "@($($FlatPieces.ForEach{"'$_'"}  -join ','))"
		Write-Host $Bravo @global:Normal_ColorSplat

		Write-Host
		Write-Host 'AssertFirehose One Liner:' @global:Header_ColorSplat
		$oneLiner = "[ColorSplat]::new('$($this.ConfigurationName)').AssertFirehose($Bravo)"
		Write-Host $oneLiner @global:Normal_ColorSplat
    
		Write-Host "Configuration file: '$($this.FileName)'" @global:Normal_ColorSplat
		Write-Host
		Write-Host 'Defined Streams: ' @global:Header_ColorSplat
		Write-Host ([string]$this) @global:Normal_ColorSplat

		Write-Host
		Write-Host '#Stream Variables:' @global:Header_ColorSplat

		$Colors = foreach ($key in $streams.keys) {
			$streams.$key.ForegroundColor
			$streams.$key.BackgroundColor
		}

		$widestColor = ($colors | select -Unique | select Length | sort Length | select -Last 1).Length + 2
    
		foreach ($key in $streams.Keys | sort) {

			$splat = $streams."$key"

			#Write-Verbose "@$($key)Colors $([psCustomObject]$streams.$key)" -Verbose
			if (!$Brief -or $notePad) {
				$Value = '@{'
				$value += $(
					@($streams.$key.Keys).ForEach{ "{0} = {1}" -f $_, $("`'$($streams.$key.$_)`'".PadRight($widestColor)) } -join '; '
				)
				$value += '}'
				#Write-Host "`$$($key)_$($this.Postfix)$(" = $Value")" @splat
				Write-Host "$("`$$($key)_$($this.Postfix)".PadRight($wide))$(" = $Value")" @splat

				$Brief = $false
			}

			if ($Brief) {
				Write-Host "@$($key)_$($this.Postfix)" @splat
			}

		}
		if ($notePad) {
			Write-Host
			Write-Host '#Color Stream Test:'  @global:Header_ColorSplat
			Write-Host $("`${0} = [{0}]::New('{1}')" -f $className, $this.ConfigurationName)
			Write-Host "`$$classname.Reset()"
       
			Write-Host "`$$classname.AssertFirehose($bravo)"
			Write-Host "`$$classname.Invoke()"
	
			foreach ($key in $streams.Keys | sort) {
				Write-Host "'$($key)_$($this.Postfix)'|Write-host @$($($key))_$($this.Postfix)"
			}
		}

		Stop-Transcript

		if ($notePad) {
			#$this.ToNotePad($clip)
			$content = Get-Content $transcriptFile
			Remove-Item $transcriptFile
			$contentString = $content -join "`n"
			$stars = [regex]::Escape($content[0])
			$breaks = [regex]::Matches($content, $stars)
			$start = $breaks[1].Index + $breaks[1].Length + 1
			$Length = $breaks[2].Index - $start
			$contentString.Substring($start, $Length) | Set-Content $transcriptFile
      
			do {
				Start-Sleep -Milliseconds 10
			} until (Test-Path $transcriptFile)
			Invoke-Item $transcriptFile
		}

	}
	<#
      <!-- [ShowCase]
      Interactive method to display and select color combinations for foreground and background
      -->
	#>
	static [void] ShowCase () {
		[colorsplat]::ShowCase($false)
	}

	hidden static [void] Browse () {
		[colorsplat]::ShowCase($true)
	}

	static [void] ShowCase ([bool]$propmt) {

		# Retrieve and sort ConsoleColor names
		$Colors = [Enum]::GetNames('ConsoleColor') |
			Where-Object -FilterScript { $_ -notmatch 'Dark' } |
			Sort-Object
		$Colors += [Enum]::GetNames('ConsoleColor') |
			Where-Object -FilterScript { $_ -match 'Dark' } |
			Sort-Object
		$i = 1
		# Generate combinations of colors
		$Combos = @()

		foreach ($fgcolor in $Colors) {

			# Foreground-only combinations
			$Combos += [pscustomobject]@{
				ID         = $i++
				Caption    = $fgcolor
				FG         = $fgcolor
				ColorSplat = @{ ForegroundColor = $fgcolor }
			}
		}

		foreach ($bgColor in $Colors) {

			foreach ($fgcolor in $Colors) {

				if ($bgColor -eq $fgcolor) {
					continue
				}

				# Foreground and background combinations
				$Combos += [pscustomobject]@{
					ID         = $i++
					Caption    = '{0}|{1}' -f $fgcolor, $bgColor
					FG         = $fgcolor
					BG         = $bgColor
					ColorSplat = @{ ForegroundColor = $fgcolor; BackgroundColor = $bgColor }
				}
			}
		}
		# Determine the maximum width of the Caption field for alignment
		$Wide = ($Combos.Caption | Measure-Object -Property Length -Maximum).Maximum + 2
		$mask = "{1,3} {0,-$Wide}"

		# Initialize layout variables
		$i = 0
		$LastBG = [string]::Empty
		[int]$Columns = 5

		# Display combinations
		foreach ($combo in $Combos) {

			$splat = $combo.ColorSplat
			$bgColor = [string]$combo.ColorSplat.BackgroundColor

			if ($LastBG -ne $bgColor) {

				if (!($i % $Columns -eq 0)) {
					Write-Host
				}

				$i = 0
				$LastBG = $bgColor
			}

			Write-Host ($mask -f $combo.Caption, $combo.ID) @splat -NoNewline

			if ($i++ % $Columns -eq ($Columns - 1)) {
				Write-Host
			}

		}

		if ($propmt) {

			$Choice = Read-Host -Prompt 'Combo ID: '

			if ($Choice -in $Combos.ID) {

				$combo = $Combos | Where-Object -Property ID -EQ -Value $Choice
				$splat = $combo.ColorSplat
				Write-Host ($combo.Caption) @splat
				@($combo.FG, $combo.BG).ForEach{ if (![string]::IsNullOrEmpty($_)) {
						"'{0}'" -f $_ 
					} 

				} -join ',' | Set-Clipboard
			}

		}
	}
	[void] hidden Export () {
		$this.Invoke() 
	}

	Invoke () {

		<#
        <!-- [Invoke]
        Invoke the stream configurations by setting them as variables in the script scope.
        -->
		#>
		$tail = "_$($this.Postfix)"
		$streams = $this.DefinedStreams
		<#
        foreach ($key in $streams.Keys) {
        
        Set-Variable -Name "$($key)$tail" -Value $($streams.$key) -Scope global -Description "$($this.ConfigurationName) Color Stream (for write-host)"
        #Write-Verbose "@$($key)Colors $([psCustomObject]$streams.$key)" -Verbose
        }
        
        $streams = $this.DefinedStreams
		#>
		$NumericScope = (Get-PSCallStack).Count - 1
		foreach ($key in $streams.Keys) {
			$splat = [Ordered]@{}
			$splat.Name = "$($key)$($tail)"
			$splat.Value = $($streams.$key)
			$splat.Scope = $NumericScope
			Set-Variable @splat
		}

	}
	Rescind() {
  <#
<!-- [Rescind]
Erase the varilables created in the Invoke method
-->
  #>
		$tail = "_$($this.Postfix)"
		$streams = $this.DefinedStreams
    
		$NumericScope = (Get-PSCallStack).Count - 1
		foreach ($key in $streams.Keys) {
			$splat = [Ordered]@{}
			$splat.Name = "$($key)$($tail)"
			$splat.Scope = $NumericScope
			Remove-Variable @splat
		}

	}
}
    <#Example Block
    
    # Example usage of the ColorSplat class.
    $MyStreams = [ColorSplat]::new('Example')
    
    # Define various streams with specific colors.
    $MyStreams.PushStream('Alpha','White','Red')
    $MyStreams.PushStream('Bravo','White','Blue')
    $MyStreams.PushStream('Charlie','Blue','White')
    $MyStreams.PushStream('Delta','White','Green')
    
    # Display the current stream configurations.
    
    $MyStreams.Invoke()
    $MyStreams.Reveal()
    #Example Block#>
    <#Example Block
    [ColorSplat]::new('Example').Reveal($true)
    [colorsplat]::ShowCase()
    #Example Block#>
    <#Example Block
    [ColorSplat]::new('Example').AssertFirehose(@('Alpha|Red', 'Bravo|White', 'Charlie|Blue', 'Delta|Red|White', 'Echo|Red|Blue', 'Foxtrot|White|Red', 'Golf|White|Blue', 'Hotel|Blue|Red', 'India|Blue|White'))
    #Example Block#>
    <#Example Block
    $ColorSplat=[ColorSplat]::New('Example')
    $ColorSplat.AssertFireHose(@('Alpha|Blue|White','Bravo|White|Blue','Charlie|Red|Blue','Delta|Blue|Red','Echo|Red|White','Foxtrot|White|Red'))
    $ColorSplat.Reveal($true,$true)
    #Example Block>
    
    <#Example Block
    $ColorSplat = [ColorSplat]::new('Example')
    $Quick = @(@('Alpha', 'White', 'Red'), @('Bravo', 'White', 'Blue'), @('Charlie', 'Blue', 'White'), @('Delta', 'White', 'Green'))
    
    $ColorSplat.PushStreams($quick)
    $ColorSplat.Reveal($true, $true)
    #Example Block#>
<#
    $ColorSplat = [ColorSplat]::new('ColorSplat')
    $ColorSplat.Reset()
    $ColorSplat.PushStream('Header','DarkGray')
    $ColorSplat.PushStream('Normal','Gray')
    
    $ColorSplat.Reveal($false,$true)
#>

<#
    New-ClassHelperMaker -ConstructorString "[ColorSplat]::new('Example')" -ClassPath $psISE.CurrentFile.FullPath -Install
    
#>
<#
    $ColorSplat = [ColorSplat]::new('Example')
    $ColorSplat.Reset()
    $Quick = @(@('Alpha', 'White', 'Red'), @('Bravo', 'White', 'Blue'), @('Charlie', 'Blue', 'White'), @('Delta', 'White', 'Green'))
    
    $ColorSplat.PushStreams($quick)
    $ColorSplat.Reveal($true, $true)
#>
<#
    if (Get-Module OSGPSX) {
    Remove-Module OSGPSX -Force
    }
    
    $ColorSplat = [ColorSplat]::new('Example')
    $colorsplat.AssertFireHose('Red|Red','White|White|Red','Blue|Blue')
    $ColorSplat.toNotePad()
#>
    <#Example Block
    
    $Colors = [Enum]::GetNames('ConsoleColor') |
    Where-Object { $_ -notmatch 'Dark' } |
    Sort-Object
    $Colors += [Enum]::GetNames('ConsoleColor') |
    Where-Object { $_ -match 'Dark' } |
    Sort-Object
    
    # Generate color combinations
    $Combos = foreach ($bgColor in $Colors) {
    foreach ($fgColor in $Colors) {
    if ($bgColor -ne $fgColor) {
    "'{0}','{1}'" -f $fgColor, $bgColor
    }
    }
    }
    
    # Foreground-only combinations
    $Combos += $Colors | ForEach-Object { "'$_'" }
    
    # Initialize ColorSplat object
    $colorSplat = [ColorSplat]::new('Sample')
    $colorSplat.Reset()
    
    foreach ($label in @('First', 'Second', 'Third')) {
    $colors = $Combos | Get-Random
    $stream = "'$label',$colors"
    
    Invoke-Expression   $("`$ColorSplat.PushStream($stream)"  )  
    $colorArray = $colors -split ','
    
    if ($colorArray.Count -gt 1) {
    $reverseLabel = "${label}Flipped"
    $reverseStream = "'$reverseLabel',{0},{1}" -f $colorArray[1], $colorArray[0]
    
    Invoke-Expression   $("`$ColorSplat.PushStream($reverseStream)"  )  
    }
    }
    
    $colorSplat.Reveal()
    
    #Example Block#>
