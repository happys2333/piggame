#Requires -Version 5.1

[CmdletBinding(DefaultParameterSetName = "Launch")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Launch")]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$ExecutablePath,

    [Parameter(Mandatory = $true, ParameterSetName = "Attach")]
    [ValidateRange(1, 2147483647)]
    [int]$ProcessId,

    [ValidateSet("main-room", "desktop-active", "desktop-idle")]
    [string]$Scenario = "main-room",

    [ValidateRange(10, 86400)]
    [int]$DurationSeconds = 120,

    [ValidateRange(0, 600)]
    [int]$WarmupSeconds = 15,

    [ValidateRange(1, 10)]
    [int]$SampleIntervalSeconds = 1,

    [ValidatePattern("^[0-9a-fA-F]{64}$")]
    [string]$ExpectedSha256,

    [ValidateRange(1, 9223372036854775807)]
    [long]$ExpectedSizeBytes,

    [string]$OutputPath,

    [switch]$KeepRunning
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RequiredProcess {
    param([int]$Id)

    $candidate = Get-Process -Id $Id -ErrorAction Stop
    if ($candidate.HasExited) {
        throw "Process $Id has already exited."
    }
    return $candidate
}

function Stop-ProbeProcess {
    param([System.Diagnostics.Process]$Process)

    if ($null -eq $Process -or $Process.HasExited) {
        return
    }
    if ($Process.CloseMainWindow()) {
        $null = $Process.WaitForExit(5000)
    }
    if (-not $Process.HasExited) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    }
}

$launchedByProbe = $false
$probeProcess = $null
$qaProfileRoot = $null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

try {
    if ($PSCmdlet.ParameterSetName -eq "Launch") {
        $resolvedExecutable = (Resolve-Path -LiteralPath $ExecutablePath).Path
        $qaProfileRoot = Join-Path $env:TEMP "PiggyDidNothingToday-QA\$timestamp"
        $qaRoaming = Join-Path $qaProfileRoot "AppData\Roaming"
        $qaLocal = Join-Path $qaProfileRoot "AppData\Local"
        $null = New-Item -ItemType Directory -Path $qaRoaming, $qaLocal -Force
        $previousAppData = $env:APPDATA
        $previousLocalAppData = $env:LOCALAPPDATA
        try {
            $env:APPDATA = $qaRoaming
            $env:LOCALAPPDATA = $qaLocal
            $probeProcess = Start-Process -FilePath $resolvedExecutable -PassThru
        }
        finally {
            $env:APPDATA = $previousAppData
            $env:LOCALAPPDATA = $previousLocalAppData
        }
        $launchedByProbe = $true
        Write-Host "Launched isolated QA process $($probeProcess.Id). Configure '$Scenario' during the warm-up window if needed."
    }
    else {
        $probeProcess = Get-RequiredProcess -Id $ProcessId
        Write-Host "Attached to process $($probeProcess.Id). Ensure it is already in '$Scenario'."
    }

    $probeProcess = Get-RequiredProcess -Id $probeProcess.Id
    $processStartedUtc = $probeProcess.StartTime.ToUniversalTime().ToString("o")
    $candidatePath = $probeProcess.MainModule.FileName
    $candidateFile = Get-Item -LiteralPath $candidatePath
    $candidateHash = (Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash.ToLowerInvariant()

    if ($ExpectedSha256 -and $candidateHash -ne $ExpectedSha256.ToLowerInvariant()) {
        throw "Candidate SHA-256 mismatch. Expected $ExpectedSha256, got $candidateHash."
    }
    if ($ExpectedSizeBytes -gt 0 -and $candidateFile.Length -ne $ExpectedSizeBytes) {
        throw "Candidate size mismatch. Expected $ExpectedSizeBytes bytes, got $($candidateFile.Length)."
    }

    if (-not $OutputPath) {
        $outputDirectory = Join-Path (Get-Location) "build\validation\windows"
        $OutputPath = Join-Path $outputDirectory "$($env:COMPUTERNAME)-$Scenario-$timestamp.json"
    }
    $resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    $outputParent = Split-Path -Parent $resolvedOutputPath
    $null = New-Item -ItemType Directory -Path $outputParent -Force

    if ($WarmupSeconds -gt 0) {
        Start-Sleep -Seconds $WarmupSeconds
    }

    $samples = @()
    $sampleCount = [Math]::Ceiling($DurationSeconds / [double]$SampleIntervalSeconds)
    $logicalProcessors = [Environment]::ProcessorCount
    $probeStartedUtc = (Get-Date).ToUniversalTime().ToString("o")

    for ($index = 0; $index -lt $sampleCount; $index++) {
        $probeProcess = Get-RequiredProcess -Id $probeProcess.Id
        $cpuBefore = $probeProcess.TotalProcessorTime.TotalSeconds
        $sampleStarted = Get-Date
        Start-Sleep -Seconds $SampleIntervalSeconds
        $probeProcess = Get-RequiredProcess -Id $probeProcess.Id
        $elapsed = ((Get-Date) - $sampleStarted).TotalSeconds
        $cpuSeconds = $probeProcess.TotalProcessorTime.TotalSeconds - $cpuBefore
        $cpuPercent = ($cpuSeconds / [Math]::Max($elapsed, 0.001) / $logicalProcessors) * 100.0
        $samples += [ordered]@{
            offsetSeconds = [Math]::Round(($index + 1) * $SampleIntervalSeconds, 3)
            cpuPercent = [Math]::Round($cpuPercent, 3)
            workingSetMiB = [Math]::Round($probeProcess.WorkingSet64 / 1MB, 3)
            privateMemoryMiB = [Math]::Round($probeProcess.PrivateMemorySize64 / 1MB, 3)
            threadCount = $probeProcess.Threads.Count
            handleCount = $probeProcess.HandleCount
        }
    }

    $cpuValues = @($samples | ForEach-Object { [double]$_.cpuPercent })
    $workingSetValues = @($samples | ForEach-Object { [double]$_.workingSetMiB })
    $privateValues = @($samples | ForEach-Object { [double]$_.privateMemoryMiB })
    $sortedCpu = @($cpuValues | Sort-Object)
    $p95Index = [Math]::Min($sortedCpu.Count - 1, [Math]::Floor(($sortedCpu.Count - 1) * 0.95))
    $averageCpu = ($cpuValues | Measure-Object -Average).Average
    $peakWorkingSet = ($workingSetValues | Measure-Object -Maximum).Maximum
    $peakPrivate = ($privateValues | Measure-Object -Maximum).Maximum
    $cpuBudget = switch ($Scenario) {
        "desktop-idle" { 2.0 }
        "desktop-active" { 5.0 }
        default { $null }
    }
    $cpuUnderBudget = if ($null -eq $cpuBudget) { $null } else { $averageCpu -lt $cpuBudget }
    $memoryUnderBudget = $peakWorkingSet -lt 300.0

    $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem
    $processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $videoControllers = @(Get-CimInstance -ClassName Win32_VideoController | ForEach-Object {
        [ordered]@{
            name = $_.Name
            driverVersion = $_.DriverVersion
        }
    })

    $result = [ordered]@{
        schemaVersion = 1
        probe = "piggy-windows-runtime"
        audioExpectedSilent = $true
        scenario = $Scenario
        candidate = [ordered]@{
            path = $candidatePath
            fileName = $candidateFile.Name
            sizeBytes = $candidateFile.Length
            sha256 = $candidateHash
            fileVersion = $candidateFile.VersionInfo.FileVersion
            productVersion = $candidateFile.VersionInfo.ProductVersion
        }
        environment = [ordered]@{
            computerName = $env:COMPUTERNAME
            operatingSystem = $operatingSystem.Caption
            osVersion = $operatingSystem.Version
            osBuild = $operatingSystem.BuildNumber
            architecture = $operatingSystem.OSArchitecture
            is64BitOperatingSystem = [Environment]::Is64BitOperatingSystem
            processor = $processor.Name
            logicalProcessors = $logicalProcessors
            totalMemoryMiB = [Math]::Round($operatingSystem.TotalVisibleMemorySize / 1024.0, 1)
            videoControllers = $videoControllers
            qaProfileRoot = $qaProfileRoot
        }
        timing = [ordered]@{
            processStartedUtc = $processStartedUtc
            probeStartedUtc = $probeStartedUtc
            probeFinishedUtc = (Get-Date).ToUniversalTime().ToString("o")
            warmupSeconds = $WarmupSeconds
            requestedDurationSeconds = $DurationSeconds
            sampleIntervalSeconds = $SampleIntervalSeconds
            sampleCount = $samples.Count
        }
        metrics = [ordered]@{
            averageCpuPercent = [Math]::Round($averageCpu, 3)
            p95CpuPercent = [Math]::Round($sortedCpu[$p95Index], 3)
            peakWorkingSetMiB = [Math]::Round($peakWorkingSet, 3)
            peakPrivateMemoryMiB = [Math]::Round($peakPrivate, 3)
        }
        budgets = [ordered]@{
            cpuPercent = $cpuBudget
            workingSetMiB = 300.0
        }
        verdicts = [ordered]@{
            cpuUnderBudget = $cpuUnderBudget
            memoryUnderBudget = $memoryUnderBudget
        }
        samples = $samples
    }

    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8
    Write-Host "Windows runtime evidence: $resolvedOutputPath"
    Write-Host ("Average CPU: {0:N3}% | P95 CPU: {1:N3}% | Peak working set: {2:N3} MiB" -f $averageCpu, $sortedCpu[$p95Index], $peakWorkingSet)
    if ($null -ne $cpuBudget) {
        Write-Host "CPU budget (<$cpuBudget%): $cpuUnderBudget"
    }
    Write-Host "Memory budget (<300 MiB): $memoryUnderBudget"
}
finally {
    if ($launchedByProbe -and -not $KeepRunning) {
        Stop-ProbeProcess -Process $probeProcess
    }
}
