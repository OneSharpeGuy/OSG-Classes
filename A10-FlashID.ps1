<#
      .AUTHORSHIP
      
      Creator            : Chuck Sharpe 
      Created Date       : 18-Oct-23 10:21 AM 
      Environment        : Windows PowerShell ISE Host 
      Powershell Version : 5.1.19041.5129 
      TimeStamp          : 2024-11-25T17:37:54-05:00 
      Time Zone          : Eastern Standard Time
#>
#requires -Version 5.0

class FlashID {
	<#
      Comments Inclosed in an HTML Comment block <!--  --> 
      with the member name in ANSI quotes <!-- [Member] --> 
      are used by the New-ClassHelperMaker command to auto-generate  FlashID.html
      
   
   <!-- [Description]
      Generates a unique instance identifier based on elapsed time since a specified epoch, ensuring uniqueness across different systems. <br>
      <br><i>The structure of FlashID is</i>
      <br><br>4EBF-B06A-LQNO<br><br>
<table style="border: none; border-collapse: collapse; width: 80%;">
  <tr>
    <td style="border: none; vertical-align: top;"><i>HexDate</i></td><td style="border: none;"/>
    <td style="border: none; vertical-align: top;">4-character hexadecimal representation of the number of days elapsed since the specified epoch. (The default is 1/1/1970, the UNIX epoch).</td>
  </tr>
  <tr>
    <td style="border: none; vertical-align: top;"><i>Partial Day</i></td><td style="border: none;"/>
    <td style="border: none; vertical-align: top;">A time-based component representing the elapsed time in the current day.</td>
  </tr>
  <tr>
    <td style="border: none; vertical-align: top;"><i>Adjunct</i></td><td style="border: none;"/>
    <td style="border: none; vertical-align: top;">
      A 4-character random alpha string ensuring uniqueness across different installations.<br>The Adjunct string does not contain digits or characters used in hexadecimal notation (`0-9`, `A-F`).
     
    </td>
  </tr>
</table>
  
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
      4 Character hexadecimal representation <br>of Days elapsed since the DOS Epoch
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
      Part of day elapsed since midnight
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
      
      <!-- [FlashMark]
      is a fine-grained timestamp (tenths of a millisecond) ensuring uniqueness of generated IDs.
      -->
      
      <!-- [Epoch]
      defines the starting date for the time-based calculations.
      -->
      
      <!-- [LogJamCount]
      tracks how many times a duplicate FlashMark had to be regenerated.
      -->
      
	#>

	[string]$HexDate
	[string]$PartialDay
	[string]$Adjunct
	[datetime]$Initiated
	[datetime]$Zulu
	[timespan]$Span
	[int]$FlashMark
	[int]$LogJamCount = 0
	[double]$Lap

	[string] hidden $Seperator = '-'
	[ValidateRange(1, 10)] [int]$Length = 4
	[switch]$BriefMode
	[switch]$Expanded
 
	[string]$Summary
	[string]hidden $logFile = (Join-Path $env:TEMP 'FlashID-History.log')
	[String]  $Epoch = '1/1/1970' 
  
	[string] ToString () {
		$stack = @($this.HexDate, $this.PartialDay)
		if ($this.Adjunct) {
			$stack += $this.Adjunct
		}

		return $stack -join $this.Seperator
	}

	[string] hidden static juxtapose ($fudge) {
		return @($fudge.HexDate, $fudge.PartialDay, $fudge.Adjunct) -join '-'
	}

	[string] hidden static TruePluck ([int]$count) {
		#$(((@(49..57) + @(65..90) |
		return -join $(@(71..90 |
					Get-Random -Count ($count * 2)).ForEach{ [char]$_ } |
					sort { Get-Random } | Get-Random -Count $count)
	}

	[string] hidden static Pluck ([int]$count) {
		<#
        <!-- [Pluck]
        Generates a random alpha numeric string
        -->
		#>
		return [FlashID]::TruePluck($count)
	}

	[string] hidden static Pluck () {
		return [FlashID]::TruePluck(4)
	}

	[string] static Pop () {
		<#
        <!-- [pop]
        Returns string representation of FlashID
        -->
		#>
		return [FlashID]::new()
	}

	[string] static Pop ([hashtable]$options) {
		return [FlashID]::new($options)
	}

	[string] static Brief () {
		<#
        <!-- 
        [Brief]
        Default FlashID without Adjunct Section
        <UL><li>Note: Because Brief Mode is a representaion of time passed in a day, 
        unique FlashID can not be guaranteed in brief mode with a fast processor
        -->
		#>
		return [FlashID]::new('Brief')
	}

	[string] static Bare () {
		<#
        <!-- [Bare]
        12 Character FlashID without seperators
        -->
		#>

		return [FlashID]::new(@{
				'NoSeperators' = $true
			})
	}

	hidden [string] static qpop () {
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
	static help () {
		$helpfile = ''
		$cs = (Get-PSCallStack)
		if ($cs) {

			$cfile = Get-Item $cs[0].ScriptName
			$className = ($cs[1].Position.Text -split '::')[0] -replace ']|\['
			$helpFile = Join-Path $cfile.DirectoryName "$($className).html"

		}

		if (Test-Path $helpFile) {
			Invoke-Item $helpFile
		}

		else {
			Write-Warning "Can't find $helpfile.  Oops.  8-|"
		}
	}
  hidden Init ($options) {
    $this.Initiated = (Get-Date)
    $hold = $this.length
    if ($options) {
      if ($options.GetType().Name -eq 'Hashtable') {
        foreach ($key in $options.Keys) {
          switch ($key) {
            'Seperator' {
              $this.Seperator = $options.$_
            } {
              $_ -in 'Epoch', 'Length', 'BriefMode', 'Expanded'
            } {
              $this.$key = $options.$_
            } {
              $_ -match 'NoSeperator'
            } {
              $this.Seperator = ''
            }

            'Initiated' {
              $this.Initiated = (Get-Date -Date $options.$_)
            }

            default {
              $this.$_ = $options.$_
            }
          }
        }
      }
      else {
        switch ($options) {
          { $_ -match 'Brief' } { $this.BriefMode = $true }
          { $_ -match 'NoSeperator' } { $this.Seperator = '' }
				
        }
      }
    }
    $this.Zulu = $this.Initiated.ToUniversalTime()

    if (!($this.Expanded -or $this.BriefMode)) {
      if ($this.length -eq $hold) {
        if ($this.length -lt 4) {
          $this.length = 4
        }
      }
    }
    $this.Expanded = !$this.BriefMode

    $this.span = (New-TimeSpan -Start (Get-Date -Date $this.Epoch) -End $this.Zulu)
    $this.HexDate = '{0:X4}' -f $this.span.Days
    #$this.span=$this.Span
    #$this.Adjunct = [FlashID]::Pluck()

    $max = ([math]::Pow(16, ($this.length))) - 1
    #Configure a default display set
    $defaultDisplaySet = @('HexDate', 'PartialDay', 'Adjunct')

    #Create the default property display set
    $defaultDisplayPropertySet = New-Object -TypeName System.Management.Automation.PSPropertySet -ArgumentList ('DefaultDisplayPropertySet', [string[]]$defaultDisplaySet)
    $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
    $this | Add-Member MemberSet PSStandardMembers $PSStandardMembers
    $log = @()
    if (Test-Path $this.logFile) {
      $log += Import-Csv $this.logFile | sort Zulu
    }

    $priorFlashMark = ($log | select -Last 1).FlashMark
    #This loop ensure partial date is unique on a really really fast computer
    
    do {

      [int]$this.FlashMark = $((Get-Date).ToUniversalTime().TimeOfDay.TotalMilliseconds) / 10
      $this.LogJamCount++
	
    } while ($this.FlashMark -eq $priorFlashMark)
    $this.LogJamCount--
    #$Global:FlashMark = $FlashMark
    $tocks = [int64]([math]::Floor(($this.span.TotalDays - $this.span.Days) * $max))
    $this.PartialDay = "{0:X$($this.Length)}" -f $tocks

    if (!($this.BriefMode)) {
      $this.Adjunct = [FlashID]::Pluck()
    }

    $this.Summary = $this.ToString()

    #>
    $this.Lap = '{0:g3}' -f (New-TimeSpan -Start $this.Initiated).TotalMilliseconds
    $logItem = $this.psObject.Copy()
    
    [array]$Cols = @($logItem.psObject.Properties.Name).ForEach{
      $_
    }
    $immediateScript=(Get-PSCallStack)[0].ScriptName
    $logItem|Add-Member -NotePropertyName Inceptor -NotePropertyValue $($($i=1;@(@(Get-PSCallStack).ForEach{if($_.ScriptName -ne $immediateScript){'({0}) {1}' -f $i++,$_.Location}}) -join '|'))
    $Cols+='Inceptor'
    $srt=@()
    $srt+='Zulu'
    $srt+='FlashMark'
    $log | sort $srt | select -Last 1000 | select $Cols | Export-Csv $this.logFile -NoTypeInformation
    #So this is weird behavior that I can not override
    #Powershell regcognizes the time to be the GMT offset.  This could present a problem if I try to get the
    #retrive the time in zulu (because it has a Z suffix, it will be converted to local time
    #This is probably more trouble that its worth, but just to keep the two times different, I'm removing
    #the trailing Z
    $Cols[$cols.IndexOf('Zulu')] = @{Name = 'Zulu'; Expression = {[string] (Get-Date $_.Zulu -Format o) -replace 'Z$'} }
    
    $this | select $Cols | Export-Csv $this.logFile -Append -NoTypeInformation

   
  }

	<#
      <!-- [TempFile]
      Creates a new Temporary file with a FlashID style FileName
      -->
	#>

	static [io.FileInfo] TempFile ($Extension) {
		# Ensure the extension starts with a period
		if ($Extension.Substring(0, 1) -ne '.') {
			$Extension = ".$Extension"
		}

		# Remove any invalid path characters from the extension
		$CleanedExtension = -join ($Extension.ToCharArray() | Where-Object { $_ -notin [IO.Path]::InvalidPathChars })

		$TargetName = "{0}{1}" -f [string][FlashID]::new(@{ length = '1'; Seperator = '' }), $CleanedExtension
		$tempFile = New-Item -ItemType File -Path (Join-Path $env:TEMP $TargetName)
		return $tempFile

	}

	static [io.FileInfo] TempFile () {
		return ([FlashID]::TempFile('.ps1'))
	}

	FlashID () {
		$this.Init($null)
	}

	FlashID ($options) {
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

  