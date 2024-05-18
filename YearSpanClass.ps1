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
	<#
      <!-- [AnniversaryOffsetDays]
      Stores the number of days until the next and previous anniversary.
      -->
  #>
	$AnniversaryOffsetDays
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

		$Anniversary = $starter.AddYears($This.years)
		$This.AnniversaryOffsetDays = [pscustomobject]@{
			Prior = (New-TimeSpan -Start $Anniversary -End $ender).Days
			Next = (New-TimeSpan -Start $ender -End $Anniversary.AddYears(1)).Days
		}

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
		return "$blurb`nfrom $($this.StartDate)`nuntil $($this.EndDate)"
	}
	static help ()
	{
		$helpfile = ''
		$cs = (Get-PSCallStack)
		if ($cs) {

			$cfile = Get-Item $cs[0].ScriptName
			$className = ($cs[1].Position.text -split '::')[0] -replace ']|\['
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

#>

