<#
    .PROVENANCE

       Author      : Chuck Sharpe
       User Name   : csharpe
       Created     : 18-May-24 05:40 PM
       Workstation : LAPTOP-Q4BIJNT5

#>
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
	hidden [int]$DaysInCurrentYear
	[long]$TotalDays

	hidden [datetime]$MostRecentAnniversary
	hidden [string]$StartDate
	hidden [string]$EndDate
	hidden [bool]$isFutureDate = $false
	[array]$Proximity

	# Constructor with start date and end date
	YearSpan ([datetime]$startDate,[datetime]$endDate) {
		$this.Measure($startDate,$endDate)
	}

	# Constructor with only start date
	YearSpan ([datetime]$startDate) {
		$this.Measure($startDate,(Get-Date).Date)
	}

	# Calculates the time span between two dates
	hidden Measure ([datetime]$starter,[datetime]$ender) {

		$currentDate = $starter

		# Check if start date is greater than end date
		if ($starter -gt $ender) {
			# Swap start and end dates if necessary
			$starter,$ender = $ender,$starter
			$this.IsFutureDate = $true

		}

		$comparisonDate = $starter

		# Calculate the number of complete years between the start and end dates
		while ($comparisonDate.AddYears(1) -le $ender) {
			$comparisonDate = $comparisonDate.AddYears(1)
			$this.Years++
		}

		$yearMarker = $comparisonDate

		# Calculate the number of complete months between the updated comparison date and the end date
		while ($comparisonDate.AddMonths(1) -le $ender) {
			$comparisonDate = $comparisonDate.AddMonths(1)
			$this.Months++
		}

		# Calculate the remaining days between the updated comparison date and the end date
		$this.Days = (New-TimeSpan -Start $comparisonDate -End $ender).Days
		$this.DaysInCurrentYear = (New-TimeSpan -Start $yearMarker -End $ender).Days
		$defaultDisplaySet = @('Years','Months','Days')

		# Adjust the most recent anniversary based on whether the date is in the future or past
		if ($this.IsFutureDate) {
			$this.MostRecentAnniversary = $ender.AddYears(- $this.Years).AddYears(-1)
			$defaultDisplaySet += 'isFutureDate'

		} else {
			$this.MostRecentAnniversary = $starter.AddYears($this.Years).AddYears(- $this.IsFutureDate)
		}

		# Format the start and end dates in a human-readable format
		$dateFormat = 'dddd, MMMM d, yyyy'
		$this.StartDate = (Get-Date $starter).ToString($dateFormat)
		$this.EndDate = (Get-Date $ender).ToString($dateFormat)

		# Calculate the total number of days between the start and end dates
		$this.TotalDays = (New-TimeSpan -Start $starter -End $ender).TotalDays

		# Calculate proximity to the most recent anniversary
		$this.Proximity = $this.GetProximity($this.MostRecentAnniversary.AddYears(- $this.Years))

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
		if ($this.IsFutureDate) {
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
<#Example Block
$TestDay=((Get-Date).Date).AddDays(-3).AddYears(-1).AddMonths(-2)
$TestDay
$Span=[YearSpan]::new($TestDay)
$Span|Format-Custom
$TestDay.AddYears($Span.Years).AddMonths($Span.Months).AddDays($Span.Days)
Example Block#>