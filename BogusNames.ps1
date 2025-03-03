<#
    .AUTHORSHIP

    Creator            : Chuck Sharpe 
    Created Date       : 05-Dec-2024 11:57 PM 
    Environment        : Windows PowerShell ISE Host 
    Powershell Version : 5.1.19041.5247 
    TimeStamp          : 2024-12-14T20:56:28-05:00 
    Time Zone          : Eastern Standard Time
#>

class BogusNames{
	# Static property to store the name dataset
	# This property is shared across all instances of the class and initialized only once.
	static [string][ValidateSet('External','Local')] $Model = 'External'
	static $AllNames = (@"
#TYPE Selected.System.Management.Automation.PSCustomObject
"Last Name","First Name","Gender"
"Aawn","Carry","FM"
"Booke","Rita","F"
"Ford","Maude L. T.","F "
"Gance","Ellie","F"
"Kidding","R. U.","FM"
"Loney","Bill","M"
"O'Vera","Al","M"
"Rhodes","Dusty","FM"
"Sterdnurse","Reggie","FM"
"Uphill","March","MF"
"@ | ConvertFrom-Csv
	)

	# Static property to store the filtered names
	# This property holds the results of the last query and is updated during object construction.
	hidden [array]$Recent #[BogusNames]::AllNames.GetType()

	hidden [string]$DataFilePath
	hidden [string]$HistoryFilePath
	[string] ToString () {
		if ($this.Recent.count) { $result = "$($this.Recent.simple|Out-String)" }
		else
		{ $result = $null }
		return $result
	}
	BogusNames () { $null = $this.Initialize() }

	[void] Initialize () {
		$CurrentFolder = (Split-Path ((Get-PSCallStack).ScriptName | Select-Object -First 1))
		$ModuleRoot = $CurrentFolder.Split('\')[0..(([SF]::ProfileFolder).Split('\').count + 1)] -join '\'

		$MiscellaneousFolder = Join-Path $ModuleRoot 'ETC'
		if (!(Test-Path $MiscellaneousFolder)) {
			$MiscellaneousFolder = $CurrentFolder
		}

		$this.DataFilePath = $(Join-Path -Path $MiscellaneousFolder -ChildPath $('{0}.dat' -f $this.GetType().Name))
		$this.HistoryFilePath = $(Join-Path -Path $MiscellaneousFolder -ChildPath $('{0}_history.dat' -f $this.GetType().Name))
		<#
		if (Test-Path -Path $this.DataFilePath) {

		}
#>
		if ([BogusNames]::Model -ne 'Local') {
			if (Test-Path -Path $this.DataFilePath) {
				[BogusNames]::AllNames = Import-Csv -Path $this.DataFilePath
			}

		}

		#[BogusNames]::AllNames = Import-Csv $dataFilePath
		if (!('simple' -in [BogusNames]::AllNames.psobject.Properties.Name)) {

			@([BogusNames]::AllNames).ForEach{
				$splat = @{
					NotePropertyName = 'Simple'
					NotePropertyValue = "$($_.'First Name') $($_.'Last Name')"
				}

				$_ | Add-Member @splat
			}
		}
		# Display the custom formatted view of the class using Format-Custom
	}
	BogusNames ($quantity) {
		$this.Initialize()
		$this.GenerateRandomNames($quantity)
	}
	BogusNames ($quantity,$genderFilter) {
		$this.Initialize()
		$this.GenerateRandomNames($quantity,$genderFilter)
	}
	[array] GenerateRandomNames () { return $($this.SelectRandomNames(1,'')) }
	[array] GenerateRandomNames ($quantity) { return $($this.SelectRandomNames($quantity,'')) }
	[array] GenerateRandomNames ($quantity,$genderFilter) { return $($this.SelectRandomNames($quantity,$genderFilter)) }

	[array] SelectRandomNames ($quantity = 1,$genderFilter) {
		# Filter dataset by gender if provided
		$filteredNames = if ($genderFilter) {
			[BogusNames]::AllNames | Where-Object -FilterScript {
				$result = $false
				Write-Verbose ($_ | Out-String)
				Write-Verbose ('Requested Gender: {0}' -f $genderFilter)
				Write-Verbose ('Recorded  Gender: {0}' -f $_.Gender)
				#If gender does not matter then $Gender should be empty
				if ($genderFilter.Length -eq 1) {
					$result = $genderFilter -in $($_.Gender.ToCharArray())
					#If gender is two characters, we assume you want only unisex names
				} else {
					if ($_.Gender.Length -gt 1) {
						if (!$result) { $result = $genderFilter -eq $_.Gender }
						#The only possibilty left is Gender is two characters but the $_.Gender is in reverse order
						if (!$result) {
							$reverse = $genderFilter.ToCharArray()
							[array]::Reverse($reverse)
							$result = (-join $reverse) -eq $_.Gender
						}
					}
				}

				$result
			}
		} else { [BogusNames]::AllNames }
		$filteredNames = $this.ExcludeRecentNames($filteredNames,$quantity)
		# Return random names
		if ($filteredNames.count -eq 0) {
			Write-Warning -Message 'No names found for the specified criteria.'
			return @() # Return an empty array if no matches
		}
		# Return a random selection of names
		$filteredNames = $filteredNames | Get-Random -Count $quantity
		$this.Recent = $filteredNames
		$this.export()
		return $filteredNames
	}
	[void] Export () {
		$Occasion = [FlashID]::Pop()
		$Hash = $null
		if (Test-Path -Path $this.DataFilePath) {
			if (Test-Path $this.HistoryFilePath) {
				$PriorHash = (Import-Csv $this.HistoryFilePath | sort ActionTime | Select-Object -Last 1).Hash
				$Hash = (Get-FileHash $this.DataFilePath).Hash
				if ($PriorHash -ne $Hash) {
					$item = Get-Item $this.DataFilePath
					$i = 1
					do {
						$backup = [io.path]::Combine($item.DirectoryName,$('{0}({1}){2}' -f $item.BaseName,$i++,$item.Extension))
						if (!(Test-Path $backup)) {
							break
						}
					} while ($true)
					Move-Item $item.FullName -Destination $backup
					[BogusNames]::AllNames | sort 'Last Name','First Name' |
					Select-Object 'Last Name','First Name','Gender' |
					Export-Csv $this.DataFilePath
					$Hash = (Get-FileHash $this.DataFilePath).Hash

				}
			}
		}

		@($this.Recent).ForEach{
			[pscustomobject]@{
				DisplayName = $_.Simple
				ActionTime = [string](Get-Date).GetDateTimeFormats('o')
				Occasion = $Occasion
				Hash = $Hash
			}
		} | Export-Csv $this.HistoryFilePath -Append

	}

	[array] ExcludeRecentNames ($Eligible,$RequestedQty) {
		$ResolvedList = @($Eligible)
		if (Test-Path $this.HistoryFilePath) {
			# Import the CSV file
			$logData = Import-Csv $this.HistoryFilePath | Where-Object -FilterScript { $_.DisplayName -in [BogusNames]::AllNames.Simple }

			$MaxShortListSize = [math]::Floor([BogusNames]::AllNames.count / 2)
			if ($RequestedQty -gt $MaxShortListSize) { $MaxShortListSize = $MaxShortListSize - ($RequestedQty - $MaxShortListSize) }

			# Group the data by DisplayName
			$Grouping = $logData | Group-Object -Property DisplayName

			# Create the shortlist by selecting the last action for each group, limited to the calculated size
			$History = ($Grouping |
				ForEach-Object -Process { $_.Group |
					Sort-Object -Property ActionTime |
					Select-Object -Last 1 }).DisplayName

			# Output the shortlist
			$PersonaNonGrata = $History | Select-Object -Last $MaxShortListSize

			$ResolvedList = @($Eligible | Where-Object -Property Simple -NotIn -Value $PersonaNonGrata)
		}
		return $ResolvedList
	}
}
<#
    # Initialize with all names
    $bogus = [BogusNames]::new()

    # Get random female names
    $femaleNames = $bogus.GenerateRandomNames(10, 'F')

    # Display as a formatted string
    Write-Host -Object "Female Names:`n$($femaleNames|Out-String)" -ForegroundColor Red

    # Access simplified names
    Write-Host -Object "Simple Names:`n$($femaleNames.Simple|Out-String)" -ForegroundColor Green
    Write-Host -Object "Total Bogus Names in Database: $($bogus::AllNames.Count)" -ForegroundColor Cyan



    $bogus = [BogusNames]::new()
    [string]$bogus
    [string]([BogusNames]::New(10))
#>

