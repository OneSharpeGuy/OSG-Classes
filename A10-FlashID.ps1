#requires -Version 5.0
class FlashID{
	<#
      Comments Inclosed in an HTML Comment block <!--  --> 
      with the member name in ANSI quotes <!-- [Member] --> 
      are used by the New-ClassHelperMaker command to auto-generate  FlashID.html



      <!-- [Description]
      Generates a unique Instance ID based on time eLapsed since the DOS Epoch<br>  4B1C-2738-PQNJ<br><br>  The first Section is a 4 character Hexidecimal representation of the Days eLapsed since 1/1/1970<br>  The second section is a representation of the time passed in the current day.  <br>The third section is a 4 Character (Adjunct) Alpha string, which will insure that the FlashID is unique across different installations. <br>(Adjunct string will not include and digits or characters used in Hexidecimal notation, [0-9][A-F])<br>
      <br>Note also, [FlashID] is based on GMT

      -->


      <!-- [Synopsis]
      Generates a unique Instance ID
      -->
	
      #Properties

      <!-- [Adjunct]
      4 Character Random Alpha String
      -->

      <!-- [BriefMode]
      Supress Adjunct section
      -->

      <!-- [Expanded]
      Include Adjunct String
      -->

      <!-- [HexDate]
      4 Character hexadecimal representation of Days eLapsed since the DOS Epoch
      -->

      <!-- [Initiated]
      Date and Time (local) the FlashID was created
      -->

      <!-- [Lap]
      Milliseconds ELapsed in creation
      -->

      <!-- [Length]
      Number of Characters in Partial Date string
      -->

      <!-- [PartialDay]
      Part of day eLapsed since midnight
      -->

      <!-- [Summary]
      String Representation of FlashID
      -->

      <!-- [Zulu]
      Date and Time the FlashID was created, GMT
      -->

      <!-- [Span]
      TimeSpan (Since Epcoh)
      -->

  #>

	[string]$HexDate
	[string]$PartialDay
	[string]$Adjunct
	[datetime]$Initiated
	[datetime]$Zulu
	[timespan]$Span

	[double]$Lap

	[string] hidden $Seperator = '-'
	[ValidateRange(1,10)] [int]$Length = 4
	[switch]$BriefMode
	[switch]$Expanded
	[string]$Summary

	[string] hidden $Epoch = '1/1/1970'

	[string] ToString ()
	{
		$stack = @($this.HexDate,$this.PartialDay)
		if ($this.Adjunct)
		{
			$stack += $this.Adjunct
		}
		return $stack -join $this.Seperator
	}
	[string] hidden static juxtapose ($fudge)
	{
		return @($fudge.HexDate,$fudge.PartialDay,$fudge.Adjunct) -join '-'
	}
	[string] hidden static TruePluck ([int]$count)
	{
		#$(((@(49..57) + @(65..90) |
		return -join $(@(71..90 |
				Get-Random -Count ($count * 2)).ForEach{ [char]$_ } |
			sort { Get-Random } | Get-Random -Count $count)
	}
	[string] hidden static Pluck ([int]$count)
	{
		<#
        <!-- [Pluck]
        Generates a random alpha numeric string
        -->
    #>
		return [FlashID]::TruePluck($count)
	}
	[string] hidden static Pluck ()
	{
		return [FlashID]::TruePluck(4)
	}
	[string] static Pop ()
	{
		<#
        <!-- [pop]
        Returns string representation of FlashID
        -->
    #>
		return [FlashID]::new()
	}
	[string] static Pop ([hashtable]$options)
	{
		return [FlashID]::new($options)
	}
	[string] static Brief ()
	{
		<#
        <!-- 
        [Brief]
        Default FlashID without Adjunct Section
        * Note: Because Brief Mode is a representaion of time passed in a day, 
          unique FlashID can not be guaranteed in brief mode with a fast processor
        -->
    #>
		return [FlashID]::new('Brief')
	}
	[string] static Bare ()
	{
		<#
        <!-- [Bare]
        12 Character FlashID without seperators
        -->
    #>

		return [FlashID]::new(@{
				'NoSeperators' = $true
			})
	}
	hidden [string] static qpop ()
	{
		return [FlashID]::Brief()
	}
	<#
	[void] static help ()
	{
		(Get-ChildItem (Join-Path -Path ($env:PSModulePath -split ';' -match $env:USERNAME) -ChildPath 'OSGPSX') -Recurse |
			Where-Object -Property Name -EQ -Value 'FlashID.html').FullName |
		Invoke-Item
	}
#>
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
	hidden Init ($options)
	{
		$this.Initiated = (Get-Date)
		$hold = $this.length
		if ($options)
		{
			if ($options.GetType().Name -eq 'Hashtable')
			{
				foreach ($key in $options.Keys)
				{
					switch ($key) {
						'Seperator'
						{
							$this.Seperator = $options.$_
						}
						{
							$_ -in 'Epoch','Length','BriefMode','Expanded'
						}
						{
							$this.$key = $options.$_
						}
						{
							$_ -match 'NoSeperator'
						}
						{
							$this.Seperator = ''
						}
						'Initiated'
						{
							$this.Initiated = (Get-Date -Date $options.$_)
						}
						default
						{
							$this.$_ = $options.$_
						}
					}
				}
			}
			else
			{
				switch ($options) {
					{
						$_ -match 'Brief'
					}
					{
						$this.BriefMode = $true
					}
					{
						$_ -match 'NoSeperator'
					}
					{
						$this.Seperator = ''
					}
				}
			}
		}
		$this.Zulu = $this.Initiated.ToUniversalTime()

		if (!($this.Expanded -or $this.BriefMode))
		{
			if ($this.length -eq $hold)
			{
				if ($this.length -lt 4)
				{
					$this.length = 4
				}
			}
		}
		$this.Expanded = !$this.BriefMode

		$this.span = (New-TimeSpan -Start (Get-Date -Date $this.Epoch) -End $this.Zulu)
		$this.HexDate = '{0:X4}' -f $this.span.Days
		#$this.span=$this.Span
		#$this.Adjunct = [FlashID]::Pluck()

		$max = ([math]::Pow(16,($this.length))) - 1
		#Configure a default display set
		$defaultDisplaySet = @('HexDate','PartialDay','Adjunct')

		#Create the default property display set
		$defaultDisplayPropertySet = New-Object -TypeName System.Management.Automation.PSPropertySet -ArgumentList ('DefaultDisplayPropertySet',[string[]]$defaultDisplaySet)
		$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
		$this | Add-Member MemberSet PSStandardMembers $PSStandardMembers

		$FlashMark = 0
		#This loop ensure partial date is unique on a really reall fast computer
		do {

			[int]$FlashMark = $((Get-Date).ToUniversalTime().TimeOfDay.TotalMilliseconds) / 10

		} while ($FlashMark -eq $Global:FlashMark)
		$Global:FlashMark = $FlashMark
		$tocks = [int64]([math]::Floor(($this.span.TotalDays - $this.span.Days) * $max))
		$this.PartialDay = "{0:X$($this.Length)}" -f $tocks

		if (!($this.BriefMode))
		{
			$this.Adjunct = [FlashID]::Pluck()
		}

		$this.Summary = $this.ToString()

		#>
		$this.Lap = '{0:g3}' -f (New-TimeSpan -Start $this.Initiated).TotalMilliseconds
		$Global:LastFlashID = $this

	}
	FlashID ()
	{
		$this.Init($null)
	}
	FlashID ($options)
	{
		$this.Init($options)
	}
}
<#
    [string][FlashID]::new($null)
    [string]([FlashID]::new(@{ Length = '4'; BriefMode = $false; Seperator = ':' }))
    [FlashID]::new($null) | Select-Object * | Format-List
    [string][FlashID]::new(@{ BriefMode = $true })

    [string][FlashID]::new(@{ Length = '1' })
    [FlashID]::Brief()
    [FlashID]::Pop()
    [FlashID]::new()
    [FlashID]::new().ToString()
    [string][FlashID]::new(@{ BriefMode = $true; Epoch = '1/1/1900' })
    [string][FlashID]::new(@{ Epoch = '1/1/1950' })
    [string][FlashID]::new(@{ Epoch = '1/1/2000' })
    [string][FlashID]::new(@{ Epoch = '1/20/2009' })
    [string][FlashID]::new(@{ Epoch = '1/20/2021' })
    [FlashID]::Pop()

    (1..10).ForEach{[FlashID]::bare()}
    (1..10).ForEach{[FlashID]::brief()}
    (1..10).ForEach{[FlashID]::pop()}

    New-ClassHelperMaker "[FlashID]::new()" -Install -ShowFile
#>

