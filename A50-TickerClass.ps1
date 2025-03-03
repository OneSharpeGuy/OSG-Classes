
class Stepper{

  [string]$Occasion
  [datetime]$Intiated = (Get-Date)
  [object]$Ceased = $null
  [int]$Sequence
  [string]$Caption
  [double]$Elapsed
  [Alias('Something')] [single]$Slice

  static [string] LogFileName ($thing) {
    $folder = Join-Path $env:TEMP 'Ticker'
    if (!(Test-Path $folder)) {
      New-Item $folder -ItemType Directory | Out-Null
    }
    return Join-Path $folder $('{0}-Steps.txt' -f $($thing))
  }

  static [void] Show ($Occasion) {
    $log = [Stepper]::FetchLog($Occasion)
    #region  Compute Unit of Measure
    $items = @()
    $items += @{ Caption = 'Millisecond'; Abbreviation = 'MS' }
    $items += @{ Caption = 'Second'; Abbreviation = 'Secs' }
    $items += @{ Caption = 'Minute'; Abbreviation = 'Mins' }
    $measured = $log | Measure-Object Elapsed -Average -Maximum -Sum -Verbose
    #$mrk = ($log | Measure-Object Elapsed -Average -Maximum).Maximum

    #$tag = ''
    #$multiplier = 1

    $units = foreach ($item in $items) {

      $item.Plural = "$($item.caption)s"
      $item.TicksPer = [int]([timespan]::"TicksPer$($item.caption)")
      $item.Extended = $measured.Sum / $item.TicksPer

      New-Object psobject -Property $item
    }

    $focused = $false
    $qualified = $units | Where-Object Extended -GE 1
    $qualified = foreach ($item in $qualified) {
      $result = foreach ($row in $log) {
        [string]('{0:g3}' -f [float]($row.Elapsed / $item.TicksPer))

      }
      #Write-Verbose -verbose ($result|out-string)
      if (!($result | Where-Object { $_ -cmatch 'e' })) {
        $item
      }
    }
    if (@($qualified).count -gt 1) {
      $focused = $qualified | Select-Object -First ($qualified.count - 1)
    }
    if (!$focused) {
      if ($qualified) {
        $focused = @($qualified)
      } else {
        $focused = $units | Select-Object -First 1
      }
    }

    $Cols = @()
    $Cols += 'Occasion'
    $Cols += 'Caption'
    $cols += @{ N = "$($focused.Plural)"; E = { "{0,$($focused.Plural.Length)}" -f $('{0:g3}' -f [float]($_.Elapsed / $focused.TicksPer)) } }
    $Cols += @{ N = 'Slice'; E = { [math]::Round($_.Slice) } }

    $log | Select-Object $Cols | Format-Table -AutoSize
    #endregion  Compute Unit of Measure
    #($log | Format-Table $Cols) | Out-Host
    Write-Verbose $($log | Format-Table $Cols | Out-String) -Verbose
    #"$tag elapsed: {0}" -f (($log | Measure-Object -Property Elapsed -Sum).Sum / $multiplier) | Out-Host
    if ($qualified) {
      $tops = $qualified | Select-Object -Last 1
    } else {
      $tops = $focused
    }
    Write-Verbose $("$($tops.Plural) elapsed: {0}" -f ($measured.Sum / $tops.TicksPer) | Out-String) -Verbose
  }
  static [Object[]] CloseItem ($syncSet) {
    foreach ($item in $syncSet) {
      $item.Ceased = (Get-Date)
      $item.Elapsed = ($item.Ceased.Ticks - $item.Intiated.Ticks) #/ [timespan]::TicksPersecond
    }
    return $syncSet
  }
  Stepper ([string]$Occasion) { $this.Stepper($Occasion,$null) }
  #Stepper ([string]$Occasion,$Caption) { $this.TrueStepper($Occasion,$Caption) }

  Stepper ([string]$Occasion,$Caption) {
    $this.Occasion = $Occasion
    [stepper]::CleanUp($Occasion)
    $logfile = [Stepper]::LogFileName($this.Occasion)
    $log = @()
    $prior = @()
    if (Test-Path $logfile) {
      $log += Import-Clixml $logfile
    }
    if ($log) { $prior = $log | Where-Object { [string]::IsNullOrEmpty($_.Ceased) } | sort Initiated }

    $syncSet = [stepper]::closeItem($prior)
    $this.Intiated = (Get-Date)
    $this.sequence = $log.count + 1
    if ($Caption) {
      $this.Caption = $Caption
    } else {
      $this.Caption = 'Step {0}' -f $this.sequence
    }
    $log += $this

    $log | Export-Clixml $logfile
    [Stepper]::Evaluate($Occasion)
  }
  static Evaluate ($Occasion) {
    [array]$log = [Stepper]::FetchLog($Occasion)
    $sv = ($log | Out-String).Trim()
    $measured = ($log | Measure-Object -Sum Elapsed)
    foreach ($item in $log | Where-Object { $_.Ceased }) {
      $item.Slice = '{0:g3}' -f (($item.Elapsed / $measured.Sum) * 100)
    }
    if (($log | Out-String).Trim() -ne $sv) {
      $log | Export-Clixml $([Stepper]::LogFileName($Occasion))
    }

  }
  static [object] FetchLog ($Occasion) {
    $logfile = [Stepper]::LogFileName($Occasion)
    $log = @()
    if (Test-Path $logfile) {
      $log += Import-Clixml $logfile
    }
    return $log
  }

  static Complete ($Occasion) {
    <#<!-- [Complete]
        Stops and closes the bar
    -->#>
    $log = [Stepper]::FetchLog($Occasion)

    $Bottom = $log | sort Squence | Select-Object -Last 1
    <#if ([string]::IsNullOrEmpty($Bottom.Ceased)) {
        $Bottom.Ceased = (Get-Date)
        $Bottom.Elapsed = ($Bottom.Ceased.Ticks - $Bottom.Intiated.Ticks) #/ [timespan]::TicksPersecond
    }#>
    $Bottom = [stepper]::closeItem($Bottom)
    $log | Export-Clixml $([Stepper]::LogFileName($Occasion))
    [Stepper]::Evaluate($Occasion)

  }
  static CleanUp ($Occasion) { [Stepper]::CleanUp($Occasion,60) }
  static CleanUp ($Occasion,$expiry) {

    $logfile = $([Stepper]::LogFileName($Occasion))
    $files = Get-ChildItem (Split-Path $logfile) |
    Where-Object { (New-TimeSpan $_.LastWriteTime).TotalMinutes -gt $this.expiry } |
    Where-Object { $_.FullName -ne $logfile }
  }
}
[flags()] enum RecapMethod{
  Properties = 1
  StepDetail = 2
  ISE_Only = 0x100
}
class Ticker{
  <#
      <!-- [Synopsis]
      QND Progress Bar
      -->

      <!-- [Description]
      Wrapper Class for Write-Progress to easily display a progress bar
      -->

  #>
  <# Properties

      <!-- [Activity]
      Name of the progress bar
      -->

      <!-- [ID]
      identifier for the progress bar
      -->

      <!-- [Max]
      is the Upper Limit; The count at which the Progress is Completed
      -->

      <!-- [Ocassion]
      Instance ID
      -->

      <!-- [ParentID]
      established hierarchical order of multiple progress bars
      -->

      <!-- [Recapitualtion]
      Display Details of Steps Processed 
      <li>Properties - Shows write-Progress Summary Properites
      <li>StepDetail - Displays Time each step took and Percentage of the whole
      -->

      <!-- [Segments]
      Number of Segments included in progess bar
      -->

      <!-- [Steps]
      Detials of Steps for Step Method
      -->
      <!-- [CountSteps]
      Counts Number of time the Step Method is called in Calling Script
      And sets the $This.Max to the corresponding number of calls
      -->
  #>
  #>
  [string]$Activity
  hidden [string]$Blurb
  hidden [int]$Counter = 1
  hidden [double]$Done
  hidden [int]$Incr
  hidden [int]$Mark
  [int]$Max = 0
  hidden [int]$OverHead = 0
  hidden [int]$NextUpdate = 0
  [int]$Segments = 150
  hidden [Diagnostics.Stopwatch]$StopWatch
  hidden [double]$Togo
  hidden [int]$Updates = 0
  hidden [bool]$Updated
  [int]$ID = 0
  [int]$ParentID = -1
  hidden [string]$Mode
  hidden [bool]$Completed = $false
  hidden [string]$spinchars = '\|/---'
  hidden [array]
  #Only hiding to make .Step method more identifiable
  $Steps = @()
  [string]$Ocassion = $this.GenInstanceID()
  [RecapMethod]$Recapitualtion = [RecapMethod]::ISE_Only
  hidden [bool]$Recap
  hidden [string]$ElapsedString
  hidden [string] GenInstanceID () {

    <#
        .SYNOPSIS
        Generates a unique instance ID based on the current date and time.
    
        .DESCRIPTION
        This function creates a unique instance ID consting of
        * The days passed since 1/1/1970 (in hexidecimal format)
        * Centiseconds since the start of the current day (in hexidecimal format)
        * Random 4 character code to insure ID is unique
     
    #>

    $epoch = Get-Date '1/1/1970'
    $count = 4
    $D = Get-Date

    $years = 0
    $currentDate = $epoch

    while ($currentDate.AddYears(1) -le $D) {
      $years++
      $currentDate = $currentDate.AddYears(1)
    }

    # Calculate remaining days after full years
    $remainingDays = ($D - $currentDate).Days

    $places = 6
    $top = [math]::Pow(16,$places) - 1

    return @(
      '{0:X2}{1:X3}' -f $Years,$remainingDays
      "{0:X$places}" -f [int]((($D.TimeOfDay.TotalSeconds * 100) / 8640000) * $top)
      -join (((48..57) + (65..90)) | Get-Random -Count $count | ForEach-Object { [char]$_ })
    ) -join '-'

  }
  hidden Setup ([hashtable]$Options)
  {

    if ($Options)
    {
      if ($Options.GetType().Name -eq 'Hashtable')
      {
        foreach ($key in $Options.Keys)
        {
          switch ($key) {
            { $_ -in 'Activity','Segments','Max','ID','ParentID' }
            { $this.$key = $Options.$_ }
          }
        }
      }
    }
    if (!$this.Activity)
    { $this.Activity = 'Unknown Activity' }

    if (!$this.Segments)
    { $this.Segments = $this.Max }
    $this.SetIncr()
    $this.StopWatch = [Diagnostics.Stopwatch]::new()
    <#
        $x = ($this.Max) / 25
        $this.spinchars = "$(''.PadRight($x,'-'))$(''.PadRight($x,'\'))$(''.PadRight($x,'|'))$(''.PadRight($x,'/'))"
    #>
    $this.SetSpinCars()
    if ($this.StopWatch.ElapsedTicks -ne 0)
    {
      $this.StopWatch.Stop()
      $this.StopWatch.Reset()
    }
  }
  hidden SetSpinCars () {
    $x = ($this.Max) / 25
    $this.spinchars = "$(''.PadRight($x,'-'))$(''.PadRight($x,'\'))$(''.PadRight($x,'|'))$(''.PadRight($x,'/'))"
  }
  hidden SetIncr ()
  {
    if ($this.Max -ge $this.Segments)
    { $this.Incr = [math]::Ceiling($this.Max / $this.Segments) }
    else
    { $this.Incr = 1 }
  }
  hidden TrueTick ($Options)
  {
    $Status = $null
    $this.Mode = $null
    if ($Options)
    {
      if ($Options.GetType().Name -eq 'Hashtable')
      {
        foreach ($key in $Options.Keys)
        {
          switch ($key) {
            {
              $_ -in 'CurrentOperation','Mode'
            }
            {
              $this.$key = $Options.$_
            }

          }
        }
      }
    }
    if ($this.Mode -eq 'Spin')
    {
      if ($this.Max -lt 25) {
        Write-Error 'Max must be at least 25 in spin mode' -ErrorAction Stop
      }

    }
    if (!$this.StopWatch.IsRunning)
    {
      $this.StopWatch.Start()
    }
    $this.Updated = $false
    if ($this.counter -ge $this.NextUpdate)
    {
      [int]$this.mark = $this.StopWatch.ElapsedMilliseconds
      if ($this.Mode -eq 'Step') {
        $offset = -1
      } else {
        $offset = 0

      }
      if ($this.counter -le $this.Max)
      {
        <# Elimination the offset feature
            $this.done = (($this.counter + $offset) / $this.Max) * 100
        #>
        $this.done = ($this.counter / $this.Max) * 100
        $this.togo = (($this.StopWatch.ElapsedMilliseconds / $this.counter) * ($this.Max - $this.counter)) / 1000
      }
      else
      {
        if ($this.Mode -eq 'Spin')
        {
          $this.done = 0
          $this.togo = 100
          $this.counter = 1

        }
        else
        {

          $this.done = 100
          $this.togo = 0
          $this.counter = $this.Max
          $this.Incr = $this.Max

        }
      }
      $this.ElapsedString = 'Elapsed Time: {0:HH:mm:ss}' -f ([datetime]$this.StopWatch.ElapsedTicks)
      $paging = "$(if ($this.mode -eq 'Step'){'step '})$($this.counter) of $($this.Max)"
      $splat = @{
        ID = $this.ID
        ParentID = $this.ParentID
        Activity = $this.Activity
        PercentComplete = $this.done
        Status = $this.ElapsedString
        #CurrentOperation = $this.CurrentOperation
        #Completed = $this.Completed
        #SecondsRemaining = $this.togo

      }
      if ($this.Mode -eq 'Tick') {
        $splat.SecondsRemaining = $this.togo
      }
      if ($Options.Message)
      {
        $splat.CurrentOperation = "$(if($this.Mode -eq 'Step'){"($Paging) "})$($Options.Message)"
      }
      if ([string]::IsNullOrEmpty($splat.CurrentOperation)) {
        if ($this.Mode -ne 'Spin') {
          $splat.CurrentOperation = $paging

        }
      }
      if ($this.Mode -eq 'Spin') {
        $splat.Activity = '{1} {0}' -f $($this.spinchars.Substring(($this.counter % ($this.spinchars.Length)),1)),$this.Activity
      }
      Write-Progress @splat
      Start-Sleep -Milliseconds 1
      $this.NextUpdate = $this.counter + $this.Incr
      $this.Updates++
      [int]$this.Overhead = $this.Overhead + ($this.StopWatch.ElapsedMilliseconds - $this.mark)
      $this.Updated = $true
    }
    $this.counter++
  }
  [void] Tick ()
  {
    <#
        <!-- [Tick]
        Shows the bar and does all the work
        -->
    #>
    $this.TrueTick(@{ Mode = 'Tick' })
  }
  [void] Tick ($Message)
  { $this.TrueTick(@{ Mode = 'Tick'; 'Message' = $Message }) }
  [void] Step () {
    #-- Increments the bar. You can also update the Activity with each step
    $this.TrueTick(@{ Mode = 'Step' })
  }
  [void] step ($Message) {
    <#
        <!-- [Step]
        Increments the bar. You can also update the Activity with each step
        -->
    #>
    $this.TrueTick(@{ Mode = 'Step'; 'Message' = $Message })
    $this.Steps += [Stepper]::new($this.Ocassion,$message)
  }
  [void] Spin ($Message) {
    <#
        <!-- [Spin]
        Used when then endpoint of the progress bar is unknown. Increments the bar
        -->
    #>
    if (!$this.Completed) {
      $this.Incr = 1
      $splatter = @{ Mode = 'Spin' }
      if (!([string]::IsNullOrEmpty($Message))) {
        #$splatter.Status = $message
        $splatter.'Message' = $Message
      }
      $this.TrueTick($splatter)
    }

  }
  [void] Spin () {
    $this.Spin($null)

  }
  Ticker ([string]$Activity,[int]$Max)
  { $this.Setup(@{ Activity = $Activity; Max = $Max }) }
  Ticker ([string]$Activity,[int]$Max,[int]$ID)
  { $this.Setup(@{ Activity = $Activity; Max = $Max; ID = $ID }) }
  Ticker ([string]$Activity,[int]$Max,[int]$ID,[int]$ParentID)
  { $this.Setup(@{ Activity = $Activity; Max = $Max; ID = $ID; ParentID = $ParentID }) }
  Ticker ([string]$Activity,[int]$Max,[int]$ID,[int]$ParentID,[int]$Segments)
  { $this.Setup(@{ Activity = $Activity; Max = $Max; ID = $ID; ParentID = $ParentID; Segments = $Segments }) }
  Ticker ([hashtable]$Options)
  {
    #-- $Options Passed as a Hash Table can set any known properties
    $this.Setup($Options)
  }
  Complete ([RecapMethod]$Method) { $this.Recapitualtion = ($this.Recapitualtion -bor $Method); $this.Complete() }
  Complete () {

    <#
        <!-- [Complete]
        Stops and closes the bar
        -->
    #>

    $this.StopWatch.Stop()
    $this.Completed = $true
    Write-Progress -Activity $this.Activity -Completed -Id $this.ID -PercentComplete 100
    if (!$this.Recapitualtion) {
      if ($this.Recap) {
        $this.Recapitualtion = [RecapMethod]::Properties -bor [RecapMethod]::StepDetail
      }

    }
    if (([RecapMethod]$this.Recapitualtion).HasFlag([RecapMethod]::ISE_Only)) {
      if ($global:host.Name -notmatch 'PowerShell ISE') {
        $this.Recapitualtion = 0
      }
    }

    if ($this.Recapitualtion) {
      if ($this.Recapitualtion.HasFlag([RecapMethod]::Properties)) {
        $props = ([ticker]::new('',1,1) | Get-Member -Force -MemberType Property).Name
        $Wide = ($props | Select-Object * | Measure-Object Length -Maximum).Maximum
        foreach ($prop in $props) {
          Write-Host $("{0,-$Wide} : {1}" -f $prop,$this. "$($prop)")
        }
      }
      if ($this.Recapitualtion.HasFlag([RecapMethod]::StepDetail)) {

        if ($this.Steps) {
          [Stepper]::Complete($this.Ocassion)
          #[stepper]::Evaluate($this.Ocassion)
          [Stepper]::Show($this.Ocassion)
          [Stepper]::CleanUp($this.Ocassion)

        }
      }
    }
    Write-Progress -Activity $this.Activity -Completed -Id $this.ID # -PercentComplete 100

    [System.GC]::Collect()
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    Start-Sleep -Milliseconds 1

  }
  Restart ()
  {
    <#
        <!-- [Restart]
        Resets all Class Properties to Thier Initial Values
        -->
    #>
    $this.counter = 1
    $this.NextUpdate = 0
    $this.Updates = 0
    $this.togo = 100
    $this.done = 0
    $this.StopWatch.Stop()
    $this.StopWatch.Reset()
    $this.SetIncr()
    $this.mark = 0
  }
  static help ()
  {
    $helpFile = Join-Path $PSScriptRoot 'Ticker.html'
    if (Test-Path $helpFile) {
      Invoke-Item $helpFile
    } else {
      Write-Warning "Can't find $helpfile.  Oops.  8-|"
    }
  }
  CountSteps () {
    $callStack = (Get-PSCallStack)[1]
    $content = Get-Content $callStack.ScriptName
    $target = $callStack.Position.Text

    $searcher = '{0}.Step(' -f ($target.Substring(0,$target.IndexOf('.')))
    $this.Max = ($content -match [regex]::Escape($searcher)).count
  }
}
<#Example Block
    if (Get-Module 'C-TickerClass') {
    Remove-Module 'C-TickerClass'
    }
    $Ticker = [Ticker]::new('Alpha',5)
    $Spinner = [Ticker]::new('Spinner',25,1,0)
    $Stepper = [Ticker]::new('Stepper',$ticker.Max * 5,2,1)
    for ($i = 0; $i -lt 25; $i++) {
    $Ticker.Step("Step $i")
    for ($j = 0; $j -lt 25; $j++) {
    $Spinner.Spin($("Stepping $j"))
    $Stepper.Step()
    #Start-Sleep -Milliseconds 5
    }
    }
#Example Block#>
<#
    if (Get-Module 'A50-TickerClass') {
    Remove-Module 'A50-TickerClass'
    }
#>
<#Example Block

<#Example Block
$myColors = [enum]::GetNames([ConsoleColor]) | Get-Random -Count ((Get-Random 11) + 5)
$Stepper = [Ticker]::new('Recap Enhancement',$myColors.count)
foreach ($color in $myColors) {
  $Stepper.Step($color)
  Start-Sleep -Milliseconds 1
}

$Stepper.Complete([RecapMethod]::StepDetail)
#Example Block#>

# New-ClassHelperMaker "[Ticker]::new('Ticker Example',1)" -ClassPath $psISE.CurrentFile.FullPath -Install
    

