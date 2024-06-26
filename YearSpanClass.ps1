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
    Provides a convenient way to calculate and represent time spans in terms of years, months, and days
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

	hidden [datetime]$MostRecentAnniversary
	hidden [string]$StartDate
	hidden [string]$EndDate

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

		if ($starter -gt $ender) {
			$starter,$ender = $ender,$starter
		}
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

		$this.MostRecentAnniversary = $starter.AddYears($This.years)

		$mask = 'dddd, MMMM d, yyyy'
		$this.StartDate = (Get-Date $starter).ToString($mask)
		$this.EndDate = (Get-Date $ender).ToString($mask)

		$defaultDisplaySet = @('Years','Months','Days')

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
		if ($this.years) {
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
	[object] Proximity () {
		<#
      <!-- [Proximity]
      Anniversaries closest to Target Date
      <ul>
      <li>Date &nbsp; &nbsp;-  Anniversary Date
      <li>Offset &nbsp;-  days to add to anniversary date to arrive at target date
      </ul>
      -->
  #>

		$thing = @()
		$thing += [pscustomobject]@{
			'Date' = [string]$this.MostRecentAnniversary.Date.ToString('MM-dd-yyyy')
			'Offset' = (New-TimeSpan -Start $this.MostRecentAnniversary -End $this.EndDate).Days
		}
		$thing += [pscustomobject]@{
			'Date' = [string]($this.MostRecentAnniversary.AddYears(1)).Date.ToString('MM-dd-yyyy')
			'Offset' = (New-TimeSpan -Start $this.MostRecentAnniversary.AddYears(1) -End $this.EndDate).Days
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

<#
    $mark = [datetime]((Get-Date).Date).AddDays(-(get-random 9131))
    Write-Verbose $mark -Verbose
    [string][YearSpan]::new($mark)
    [string][YearSpan]::new('9/24/1928','10/7/2017')
    [YearSpan]::new('3/5/1958')
      $(  [YearSpan]::new('3/5/1958')).Proximity()
    New-ClassHelperMaker "[YearSpan]::new('3/5/1958')"

#>

