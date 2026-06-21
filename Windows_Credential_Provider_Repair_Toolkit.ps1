[CmdletBinding()]
param(
    [string]$ProviderGuid,
    [switch]$EnableProvider,
    [switch]$RestoreWinlogonDefaults,
    [switch]$RestartIdentityServices,
    [switch]$DryRun,
    [switch]$Yes,
    [string]$OutputPath = (Join-Path $env:ProgramData 'CredentialProviderRepair')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:VerificationFailures = 0
$script:Actions = 0

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($env:OS -ne 'Windows_NT') { Write-Error 'This tool requires Windows.'; exit 3 }
if (-not ($EnableProvider -or $RestoreWinlogonDefaults -or $RestartIdentityServices)) { Write-Error 'Choose at least one repair action.'; exit 2 }
$providerPath = $null
if ($EnableProvider) {
    $guidValue = [guid]::Empty
    if ([string]::IsNullOrWhiteSpace($ProviderGuid) -or -not [guid]::TryParse($ProviderGuid,[ref]$guidValue)) { Write-Error '-ProviderGuid must be a valid GUID.'; exit 2 }
    $providerPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{$($guidValue.ToString())}"
    if (-not (Test-Path $providerPath)) { Write-Error 'The credential provider is not registered on this computer.'; exit 2 }
}
if (-not $DryRun -and -not (Test-Administrator)) { Write-Error 'Run from an elevated PowerShell session.'; exit 4 }

$winlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$runPath = Join-Path $OutputPath (Get-Date -Format 'yyyyMMdd_HHmmss')
$backupPath = Join-Path $runPath 'backup'
New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
$logPath = Join-Path $runPath 'repair.log'
$beforePath = Join-Path $runPath 'before.json'
$afterPath = Join-Path $runPath 'after.json'

function Write-Log([string]$Message) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" | Tee-Object -FilePath $logPath -Append }
function Invoke-RepairAction([string]$Description,[scriptblock]$Script) {
    $script:Actions++
    Write-Log "ACTION: $Description"
    if ($DryRun) { Write-Log "DRY-RUN: $Description"; return }
    try {
        $result = & $Script 2>&1
        if ($null -ne $result) { $result | Out-String | Add-Content $logPath }
        Write-Log "SUCCESS: $Description"
    } catch {
        $script:Failures++
        Write-Log "FAILED: $Description - $($_.Exception.Message)"
    }
}
function Get-ProviderState {
    if (-not $providerPath) { return $null }
    $item = Get-Item $providerPath
    $properties = Get-ItemProperty $providerPath
    [pscustomobject]@{ Guid=$ProviderGuid; Name=$item.GetValue(''); Disabled=$properties.Disabled }
}
function Get-RepairState {
    $winlogon = Get-ItemProperty $winlogonPath
    [pscustomobject]@{
        Collected = Get-Date
        Provider = Get-ProviderState
        Winlogon = [pscustomobject]@{ Shell=$winlogon.Shell; Userinit=$winlogon.Userinit }
        Services = @(Get-Service VaultSvc,TokenBroker,NgcCtnrSvc,WbioSrvc -ErrorAction SilentlyContinue | Select-Object Name,Status,StartType)
    }
}

Get-RepairState | ConvertTo-Json -Depth 8 | Set-Content $beforePath -Encoding UTF8
& reg.exe export 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' (Join-Path $backupPath 'Winlogon.reg') /y | Out-Null
if ($providerPath) {
    $nativeProviderKey = $providerPath -replace '^HKLM:\\','HKLM\'
    & reg.exe export $nativeProviderKey (Join-Path $backupPath 'CredentialProvider.reg') /y | Out-Null
}

if (-not $DryRun -and -not $Yes) {
    if ((Read-Host 'Apply the selected credential-provider repairs? Type YES') -cne 'YES') { Write-Log 'Repair cancelled.'; exit 10 }
}

if ($EnableProvider) {
    Invoke-RepairAction "Enabling credential provider $ProviderGuid" { New-ItemProperty -Path $providerPath -Name Disabled -Value 0 -PropertyType DWord -Force | Out-Null }
}
if ($RestoreWinlogonDefaults) {
    Invoke-RepairAction 'Restoring standard Winlogon Shell and Userinit values' {
        Set-ItemProperty -Path $winlogonPath -Name Shell -Value 'explorer.exe'
        Set-ItemProperty -Path $winlogonPath -Name Userinit -Value "$env:SystemRoot\system32\userinit.exe,"
    }
}
if ($RestartIdentityServices) {
    foreach ($serviceName in 'VaultSvc','TokenBroker','NgcCtnrSvc','WbioSrvc') {
        if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
            Invoke-RepairAction "Restarting identity service $serviceName" {
                $service = Get-Service $serviceName
                if ($service.Status -eq 'Running') { Restart-Service $serviceName -Force } else { Start-Service $serviceName }
            }
        }
    }
}

if (-not $DryRun) { Start-Sleep -Seconds 2 }
$after = Get-RepairState
$after | ConvertTo-Json -Depth 8 | Set-Content $afterPath -Encoding UTF8
if ($EnableProvider -and (Get-ItemProperty $providerPath).Disabled -ne 0) { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: credential provider remains disabled.' }
if ($RestoreWinlogonDefaults) {
    $values = Get-ItemProperty $winlogonPath
    if ($values.Shell -ne 'explorer.exe' -or $values.Userinit -ne "$env:SystemRoot\system32\userinit.exe,") { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: Winlogon defaults do not match expected values.' }
}
if ($RestartIdentityServices) {
    foreach ($serviceName in 'VaultSvc','TokenBroker','NgcCtnrSvc','WbioSrvc') {
        $service = Get-Service $serviceName -ErrorAction SilentlyContinue
        if ($service -and $service.Status -ne 'Running') { $script:VerificationFailures++; Write-Log "VERIFY FAILED: $serviceName is not running." }
    }
}

if ($script:Failures -gt 0) { exit 20 }
if ($script:VerificationFailures -gt 0) { exit 30 }
Write-Log "Repair completed. Actions: $script:Actions"
exit 0
