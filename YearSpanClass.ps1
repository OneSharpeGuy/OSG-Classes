<#
    Comments Inclosed in an HTML Comment block <!--  --> 
    with the member name in ANSI quotes <!-- [Member] --> 
    are used by the New-ClassHelperMaker command to auto-generate  YearSpan.html
#>
<#
    <!-- [Synopsis]
    Calculates the difference in years, months, and days between two dates. 
    -->

    <!-- [Description]
    Provides a convenient way to calculate and represent time spans in terms of years, months, and days.<br>

    It can be used for tasks like calculating age, tenure, or any duration between two specific events.
    -->
#>

class YearSpan{
	[int]
	<#  <!-- [Years]
      Full years passed since StartDate
  -->  #>
	$Years
	[int]

	<#<!-- [Months]
      Months Passed since most recent anniversary date
  -->#>
	$Months
	[int]
	<#<!-- [Days]
      Days passed since most recent anniversary month 
  -->#>

	$Days
	<#
<!-- [TotalDays]
Total number of days elapsed
-->
#>
	hidden [int]$DaysCurrentYear
	[long]$TotalDays

	hidden [datetime]$MostRecentAnniversary
	hidden [string]$StartDate
	hidden [string]$EndDate
	hidden [bool]$FutureDate = $false
	[array]$Proximity

	# Constructor with start date and end date
	YearSpan ([datetime]$startDate,[datetime]$endDate) {
		$this.reckon($startDate,$endDate)
	}

	# Constructor with only start date
	YearSpan ([datetime]$startDate) {
		$this.reckon($startDate,(Get-Date).Date)
	}

	# Calculates the time span between two dates
	hidden reckon ([datetime]$starter,[datetime]$ender) {
		# Check if start date is greater than end date
		$multiplier = 1
		$holder = $starter
		if ($starter -gt $ender) {
			$starter,$ender = $ender,$starter
			$this.FutureDate = $true
			$multiplier = - $multiplier
		}
		$markDate = $starter
		while ($markDate.AddYears(1) -lt $ender) {
			$markDate = $markDate.AddYears(1)
			$this.Years++

		}

		$Soy = $markDate

		while ($markDate.AddMonths(1) -lt $ender) {
			$markDate = $markDate.AddMonths(1)
			$this.Months++
			#$this.DaysCurrentYear+=[datetime]::DaysInMonth($markDate.Year,$markDate.Month)

		}
		$this.Days = (New-TimeSpan $markDate $ender).Days
		$this.DaysCurrentYear = (New-TimeSpan $soy $ender).Days

		<#
		$this.years = $ender.Year - $starter.Year
		$this.Months = $ender.Month - $starter.Month
		$this.Days = $ender.Day - $starter.Day
		if ($this.Days -lt 0) {
			$this.Months --
			$this.Days += [datetime]::DaysInMonth($starter.Year,$starter.Month)
		}
		if ($this.Months -lt 0) {
			$this.years --
			$this.Months += 12
		}
#>
		#
		if ($this.FutureDate) {
			$this.MostRecentAnniversary = $ender.AddYears(- $this.Years).AddYears(-1)
		} else {

			$this.MostRecentAnniversary = $starter.AddYears($This.Years).AddYears(- $this.FutureDate)
		}
		$mask = 'dddd, MMMM d, yyyy'
		$this.StartDate = (Get-Date $starter).ToString($mask)
		$this.EndDate = (Get-Date $ender).ToString($mask)

		$this.TotalDays = (New-TimeSpan -Start $starter -End $ender).TotalDays
		$this.Proximity = $this.GetProximity($this.MostRecentAnniversary.AddYears(- $this.Years))

		$defaultDisplaySet = @('Years','Months','Days')
		if ($this.FutureDate) {
<#
			foreach ($prop in $this.psobject.Properties | Where-Object { $_.TypeNameOfValue -match '\.int' }) {
				$this. "$($prop.name)" = $this. "$($prop.name)" * -1
			}
#>
			$defaultDisplaySet += 'FutureDate'
		}

		#Create the default property display set
		$defaultDisplayPropertySet = New-Object -TypeName System.Management.Automation.PSPropertySet -ArgumentList ('DefaultDisplayPropertySet',[string[]]$defaultDisplaySet)
		$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
		$this | Add-Member MemberSet PSStandardMembers $PSStandardMembers
	}
	hidden [string] Plurality ([int]$Count,[string]$Blurb) {

		$S = ''
		if ($Count -ne 1) {
			$S = 's'
		}
		return "$($count) $Blurb$($S)"
	}
	# Method to output YearSpan object as string

	[string] ToString () {
		$blurb = ''
		if ($this.Years) {
			$Blurb = "`n$($this.Plurality($this.Years,'Year'))"
		}
		if ($this.Months) {
			if ($blurb) {
				$blurb += ", "
			}
			$blurb += $($this.Plurality($this.Months,'Month'))
		}
		if ($this.Days) {
			if ($blurb) {
				$blurb += ", "
			}
			$blurb += $($this.Plurality($this.Days,'Day'))
		}
		$T = ''
		if (((Get-Date $this.EndDate).Date) -eq (Get-Date).Date) {
			$T = "(Today) "
		}

		return "$blurb`nfrom $($this.StartDate)`nuntil $T$($this.EndDate)"
	}
	hidden [object] GetProximity ([datetime]$starter) {
		<#
      <!-- [Proximity]
      An array of Anniversaries closest to Target Date
      <ul>
      <li>Date &nbsp; &nbsp;-  Anniversary Date
      <li>Offset &nbsp;-  days to add to anniversary date to arrive at target date
      </ul>
      Indices
      <ul>
      <li>[0] Most recent anniversary
      <li>[1] Next anniversary
      </ul>
      -->
  #>

		$thing = @()
		$thing += New-Object psObject -Property @{ Date = ((Get-Date $starter).AddYears($this.Years)) }
		$thing += New-Object psObject -Property @{ Date = ($thing[0].Date.AddYears(1)) }

		$thing.ForEach{
			$_ | Add-Member -NotePropertyName 'Offset' -NotePropertyValue $((New-TimeSpan -Start $_.Date -End $this.EndDate).Days)
			$_.Date = $_.Date.ToString('yyyy-MM-dd')
		}
		if ($this.FutureDate) {
			$thing[0].Offset = - ($thing[0].Offset)
		}

		return ($thing)

	}

	static help ()
	{
		$helpfile = ''
		$cs = (Get-PSCallStack)
		if ($cs) {

			$cfile = Get-Item $cs[0].ScriptName
			$className = ($cs[1].Position.Text -split '::')[0] -replace ']|\['
			$helpFile = Join-Path $cfile.DirectoryName "$($className).html"

		}
		if (Test-Path $helpFile) {
			Invoke-Item $helpFile
		} else {
			Write-Warning "Can't find $helpfile.  Oops.  8-|"
		}
	}
}

<#Example Block

    $mark = [datetime]((Get-Date).Date).AddDays(-(get-random 9131))
    Write-Verbose $mark -Verbose
    [string][YearSpan]::new($mark)

    [string][YearSpan]::new('9/24/1928','10/7/2017')

    [YearSpan]::new('3/5/1958')

   ([YearSpan]::new('3/5/1958')).Proximity |Out-String
    
Example Block#>
#New-ClassHelperMaker "[YearSpan]::new('3/5/1958')"


