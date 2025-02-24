#Remove-Module (Get-PSCallStack)[0].Command
<#
    Comments Inclosed in an HTML Comment block <!--  --> 
    with the member name in ANSI quotes <!-- [Member] --> 
    are used by the New-ClassHelperMaker command to auto-generate  EZSettings.html
#>

class Setting {
	[string]$Key
	[object]$Value
	[string]$InstanceID
	[datetime]$Written
	[int]$Version = $null

	Setting ([string]$key, $value) {
		$this.key = $Key
		$this.Value = $Value
		$this.Written = (Get-Date)
		$this.Version = 1
	}
}

class EZSettings {
	<#
      <!-- [Synopsis]
      Retrives Module Settings
      -->
      
      <!-- [Description]
      Retrieves and Maintains Module settings
      -->
      
	#>
      <# Properties
      
      <!-- [Configurator]
      Full Path to Module Loader
      -->
      <!-- [FileName]
      Full Path of Settings File name
      -->
      
      <!-- [InstanceID]
      String representation of FlashID <li>Instance ID of Class Instance that wrote the setting
      -->
      
      <!-- [ModuleManifest]
      Full Path to Module Manifest
      -->
      
      <!-- [Settings]
      Specified Settings for the module
      <li>Key
      <li>Value
      <li>InstanceID - Matches InstanceID of object when settings was last written
      <li>Written - Time setting was last written or Modifed
      <li>Version
      -->
      <!-- [ModRoot]
      CurrentUser/Current Host Module Folder
      -->
      <!-- [Consumer]
      Context under which EZSettings will be Executed
      <li>Should be the same as Settings/ezProduces
      <li>If Producer and Consumer do not match, file should be reset
      -->
      
	#>

	[string] hidden $DotFolder
	[string]$InstanceID
	[string] hidden $ModuleName
	[string] hidden $ModuleHome
	hidden $Invocation
	static [string]$ModRoot = ($env:PSModulePath -split ';' -match ([environment]::UserName))
	[string]$FileName
	[array]$Settings = @()
	hidden [hashtable]$KeyExtensions = @{}
	[string]$Configurator
	[string]$ModuleManifest
	[string]
	# Full path to PowerShell module file
	$ModuleFileName
	[string]$Consumer = '{0}.{1}.{2}' -f $env:COMPUTERNAME, $env:USERDOMAIN, $env:USERNAME

	hidden static [string] FindModuleLoader ([string]$Anchor) { return [EZSettings]::FindConfigurator($anchor) }
	static [string] FindConfigurator ([string]$Anchor) {
		<#
        <!-- [FindConfigurator]
        Returns  the Path to the Module Initialization Script
        -->
		#>

		#In order of preferrence
		$mark = 'Prepper.ps1', 'Init.PS1', 'PushSettings.ps1'

		if (!($Anchor -match [regex]::Escape([EZSettings]::ModRoot))) {
			$path = (Join-Path $([EZSettings]::ModRoot) $Anchor)
		}

		else {
			$path = $Anchor
		}

		$stack = ($path -split '\\')
		$top = Join-Path $([EZSettings]::ModRoot) $stack[$stack.IndexOf('Modules') + 1]

		Write-Verbose "`$top:$($top|Out-String)"
		$target = $path
		$hook = $false
		while ($target -match [regex]::Escape($top)) {

			Write-Verbose "`$target:$($target|Out-String)"
			if (Test-Path $target) {
				$files = Get-ChildItem $target -Filter *.ps1

				foreach ($marker in $mark) {
					$hook = $files | Where-Object { $_.Name -eq $marker }
					if ($hook) {
						break
					}
				}

				Write-Verbose "`$hook$($hook|Format-Table Name,Directory|Out-String)"
				if ($hook) {
					break
				}
			}
			$target = Split-Path $target

		}

		return $hook.FullName
	}

	static [string] NormalizeKey ([string]$target) {
		<#
        <!-- [NormalizeKey]
        Modifies Key, normalizing spaces, removing non word characters and converting to Title Case
        -->
		#>
		#Remove Replace non word characters
		$Target = $Target -replace '-', ' '

		#Underscores are considred word charcters, so check no for UnderScors
		$Target = $Target -replace '_', ' '

		#Squish the String, so that there is only one space
		$Target = $Target -replace '\s+', ' '

		if ($Target -notmatch ' ') {
			$Target = $Target -creplace '(\B[A-Z])', ' $1'
		}

		$Target = (Get-Culture).TextInfo.ToTitleCase($Target)
		return $Target

	}

	static [string] FindModuleHome ([string]$Anchor) {
		<#
        <!-- [FindModuleHome]
        Returns the Module Home Path
        -->
		#>
		$hook = [EZSettings]::FindModuleLoader($Anchor)
		if ($hook) {
			$hook = $(Split-Path $hook)
		}

		return $hook
	}

	static [string] RMRPath ([string]$Path) {
		<#
        <!-- [RMRPath]
        Shortens Full Mod Path to Relative to Mod Root
        <li>C:\Users\chuck.sharpe\Documents\WindowsPowerShell\Modules\OSGPSX\Classes\EZSettings.Html
        <li>becomes OSGPSX\Classes\EZSettings.Html
        -->
		#>

		return (($Path -replace [regex]::Escape([EZSettings]::ModRoot)).Substring(1)) 
	}

	[hashtable] ToHashTable () {
		<#
        <!-- [ToHashTable]
        Returns the Settings as a Setting HashTable
        -->
		#>

		$HT = @{}
		$HT.'Instance ID' = $this.InstanceID
		#$this.Refresh()
		foreach ($item in $this.settings) {
			$HT.$($item.key) = $item.Value
		}

		return $HT
	}

	[object] ReadSetting ([string]$key) {
		<#
        <!-- [ReadSetting]
        Reads an existing setting
        -->
		#>
		$this.Refresh
		$setting = $this.settings | Where-Object Key -EQ $key
		if (!$setting) {
			$KeyX = [EZSettings]::NormalizeKey($key)
			if ($KeyX -eq $key) {
				#If the key was normalized, try squishing it
				$KeyX = $key -replace '\W'
			}

			if ($KeyX -ne $key) {
				$setting = $this.settings | Where-Object Key -EQ $keyx
				if ($setting) {
					$this.KeyExtensions.$key = $keyX
				}
			}
		}

		return $setting.Value
	}

	[object] PopSetting ([string]$key, $Default) {
		<#
        <!-- [PopSetting]
        Checks Setting and returns the value
        -->
		#>
		$this.CheckSetting($key, $Default)
		return $this.ReadSetting($key)
	}

	[void] CheckSetting ([string]$key, $Default) {
		<#
        <!-- [CheckSetting]
        Checks to see if setting exists; Must provide a default value.
        <li>If setting does not exist Default value is written.  
        <li>If setting exists, no action is taken.
        -->
		#>
		$setting = $this.ReadSetting($key)
		if (!$setting) {
			$this.WriteSetting($key, $Default)
		}
	}

	[void] PushSetting ([string]$key, $value) {

		<#
        <!-- [PushSetting]
        Writes setting unconditionally
        <li>If Setting Does Not Exist then Setting is Written with the Default Value
        <li>If Value is not the Default Value, Setting is Updated
        -->
		#>
		$that = $this.settings | Where-Object Key -EQ $key

		if (!$that) {
			$this.WriteSetting($key, $Value)
		}

		if ($that) {
			if ($that.Value -ne $value) {
				$this.WriteSetting($key, $Value)
			}
		}
	}
	WriteSetting ([string]$key, $value) {
		<#
        <!-- [WriteSetting]
        Writes settings Item
        -->
		#>
		$this.Refresh()
		$hashCode = $this.ToHashTable().GetHashCode()
		$that = $this.settings | Where-Object Key -EQ $key
		if (!$that) {
			$that = $this.settings | Where-Object Key -EQ $([EZSettings]::NormalizeKey($key))
		}

		if (!$that) {
			$that = $([setting]::new($key, $value))
			$that.InstanceID = $this.InstanceID
			$this.settings += $that
			#$this.settings | Export-Clixml $this.FileName
		}

		else {
			$that.Version = $that.Version + 1
			$that.InstanceID = $this.InstanceID
			$that.Value = $value
			#$this.settings | Where-Object { !([string]::IsNullOrEmpty($_.Value)) } | Export-Clixml $this.FileName
		}

		$this.settings | Where-Object { !([string]::IsNullOrEmpty($_.Value)) } | Export-Clixml $this.FileName
		if ($hashCode -ne $this.ToHashTable().GetHashCode()) {
			#$this.ToHashTable() | Format-Table | Out-String | Set-Content $([io.path]::ChangeExtension($this.FileName,'txt'))
			$producer = $this.settings | Where-Object key -EQ 'ezProducer'
			if ($producer) {
				$producer.Value = $this.Consumer
			}

			else {
				$producer = $([setting]::new('ezProducer', $this.Consumer))
				$this.settings += $producer
			}

			$this.settings | sort Key | Select-Object Key, @{ N = 'Value'; E = { $_.Value | Out-String } } |
				Format-Table -AutoSize | Out-String |
				Set-Content $([io.path]::ChangeExtension($this.FileName, 'txt'))
		}

		$that = $this.settings | Where-Object Key -EQ $key

	}

	hidden refresh () {
		<#
        <!-- [refresh]
        Syncs Object instance with Values in Settings File
        -->
		#>
		return
		if (Test-Path $this.FileName) {
			[array]$wtf = (Import-Clixml $this.FileName).settings

          <#foreach ($item in $wtf) {
          $focus = $this.settings | Where-Object Key -EQ $item.key
          
          if (!$focus) {
          $this.settings += $item
          }
          if ($item.Written -gt $focus.Written) {
          #Overwrite existing item
          $focus.InstanceID = $item.InstanceID
          $focus.Value = $item.Value
          $focus.Version = $item.Version
          $focus.Written = $item.Written
          }
          
          }#>
		}
	}

	Show () {
		<#
        <!-- [Show]
        Returns a formatted view of the EZSetting object
        -->
		#>
		Write-Host ''
		# $this.Refresh()

		$Props = ($this | Get-Member -MemberType Properties | Where-Object Definition -Match 'string' | Where-Object Name -NotIn 'Settings').Name
		$Width = ($Props | Select-Object Length | Measure-Object Length -Maximum).Maximum
		foreach ($key in $Props) {
			"{0,-$Width}: {1}" -f $key, $this.$($key) | Out-Host
		}

		$this.settings | sort Key | Format-Table Key, @{ N = 'Value'; E = 'Value'; A = 'Left' } | Out-Host
	}

	[string] ToString () {

		return $this.FileName 
	}

	<#
      <!-- [Retrieve]
      Alternative factory method, sort of an Alias for [EZSettings]::new()<br>
      (New sort of implies to me, you're creating a new configuration,<br>
      retrive makes it clear that the configuration, is by default, already be defined)
      -->
	#>
	static [EZSettings] Retrieve ($pathHint) {
		Return [EZSettings]::new($pathHint)
	}

	static [EZSettings] Load ($pathHint) {
		Return [EZSettings]::new($pathHint)
	}

	EZSettings ([string]$pathHint) { $this.Init($pathHint, $false) }
	EZSettings ([string]$pathHint, [bool]$reset) { $this.Init($pathHint, $reset) }
	hidden Init ([string]$path, [bool]$reset) {
		$this.DotFolder = $path
		$this.Invocation = $MyInvocation
		if ($this.Invocation.CommandOrigin -ne 'Internal') {
			if (!(Test-Path $path)) {
				$this.DotFolder = (Split-Path $this.Invocation.InvocationName)
			}
		}
		if (!(Test-Path $this.DotFolder) -or ($env:PSModulePath.Split(';') -match [regex]::Escape($this.DotFolder))) {
			$this.DotFolder = (Join-Path ([EZSettings]::ModRoot) $path)
			if (!(Test-Path $this.DotFolder)) {
				Write-Error "Specified path [$($path)] does not yield a valid folder [$($this.DotFolder)]"
			}

			if (!($this.DotFolder = ([EZSettings]::ModRoot))) {
				Write-Error "Specified path can not be [$([EZSettings]::ModRoot)]"
			}

			if (!($this.DotFolder -match [regex]::Escape([EZSettings]::ModRoot))) {
				Write-Error "Specified path must be within the [$([EZSettings]::ModRoot)] tree"

			}
		}

		$this.ModuleHome = [EZSettings]::FindModuleHome($path)
		if (!$this.ModuleHome) {
			$this.ModuleHome = Join-Path ([EZSettings]::ModRoot) (Split-Path $path -Leaf)
		}

		$this.ModuleName = (Split-Path $This.ModuleHome -Leaf)

		$this.Configurator = [EZSettings]::FindConfigurator($this.ModuleHome)
		$this.FileName = Join-Path $This.ModuleHome 'ezSettings.xml'
		#$this.ModuleManifest = (Get-ChildItem $this.ModuleHome -Filter '*.psd1' | Where-Object Name -EQ $this.ModuleName).FullName
		$this.ModuleManifest = (Get-ChildItem $this.ModuleHome -Filter '*.psd1' | Where-Object BaseName -EQ $this.ModuleName).FullName
		$this.ModuleFileName = (Import-PowerShellDataFile $this.ModuleManifest).RootModule
		if ($this.ModuleFileName.Split('\').Count -eq 1) {
			$this.ModuleFileName = Join-Path $this.ModuleHome $this.ModuleFileName
		}

		if ($reset) {
			if (Test-Path $this.FileName) {
				Remove-Item $this.FileName -Force
			}
		}

		if (Test-Path $this.FileName) {
			$this.settings += Import-Clixml $this.FileName

		}

		$this.InstanceID = [FlashID]::pop()
		$this.CheckSetting('Module Home', $this.ModuleHome)
		$this.CheckSetting('Module Name', $this.ModuleName)

		$this.CheckSetting('Module Include Folder', (Join-Path $this.ModuleHome 'Include'))
		$this.CheckSetting('Module Public Folder', (Join-Path $this.ReadSetting('Module Include Folder') Export))
		$this.CheckSetting('Module Private Folder', (Join-Path $this.ReadSetting('Module Include Folder') Private))
		$this.CheckSetting('Module Limited Access Folder', (Join-Path $this.ReadSetting('Module Home') Local))

	}

	[void] static help () {
    (Get-ChildItem (Join-Path ($env:PSModulePath -split ';' -match $env:USERNAME) 'OSGPSX') -Recurse |
			Where-Object Name -EQ 'EZSettings.html').FullName |
    Invoke-Item
	}

	ZapSetting ($key) {
		<#
        <!-- [ZapSetting]
        Permanently Removes Setting 
        -->
		#>
		$keepers = $this.settings | Where-Object Key -NE $key
		$keepers | Export-Clixml $this.FileName
		$this.Refresh()

	}

	hidden KeyNote () { $this.ListKeys() }
	hidden NotePad () { $this.NotePad() }
	ToNotepad () { $this.ListKeys() }
	<#
      <!-- [ToNotepad]
      <li>Lists all Keys and settings values and opens in Notepad
      <li>Simply for assisting in programming
      -->
	#>

	hidden ListKeys () {
        <#<!-- [ListKeys] 
        Generates a list of Keys and outputs list to notepad 
        -->#>

		$Alpha = @()
		$Alpha += '+-------------+'
		$Alpha += '| Simple Keys |'
		$Alpha += '+-------------+'
		$bravo = @()
		$Bravo += '+--------------------+'
		$Bravo += '| Settings Variables |'
		$Bravo += '+--------------------+'
		$Charlie = @()
		$Charlie += '+--------+'
		$Charlie += '| Values |'
		$Charlie += '+--------+'
		$wide = (($this.settings | Select-Object Key).key | sort Length -Descending | Select-Object -First 1).Length + 2
		foreach ($S in $this.settings | sort Key) {
			if ($S.Value) {
				$Q = $(if ($s.key -match '\W') { "'" } else { '' })
				$key = "$Q$($s.Key)$Q"
				$Alpha += $key
				$bravo += "`$Settings.$key"
				$charlie += "{0,-$wide} : {1}" -f $S.key, $(($S.Value | Out-String).Trim())
			}
		}
		$tempFile = (Join-Path $env:TEMP "$($this.ModuleName)-Settings Keys Helper.txt")
		$Bravo + @('') + $Alpha + @('') + $Charlie | Set-Content $tempFile
		do { Start-Sleep -Milliseconds 10 } until (Test-Path $tempFile)
		notepad $tempFile
		Start-Sleep -Milliseconds 500
		Remove-Item $tempFile

	}

}
<#
    New-ClassHelperMaker "[EZSettings]::Retrieve('OSGPSX')"
#>
