#requires -Version 5.1
<#
.SYNOPSIS
    Windows Context Reporter.
.DESCRIPTION
    Read-only Windows context reporter for support review.
#>
[CmdletBinding()]
param([string]$OutputPath)
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Windows_Context_Reports' }
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
function Export-Data { param($Name,$Data) $Data | Export-Csv (Join-Path $OutputPath "$Name.csv") -NoTypeInformation -Encoding UTF8; $Data | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $OutputPath "$Name.json") -Encoding UTF8 }
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$summary = [PSCustomObject]@{Computer=$env:COMPUTERNAME;CurrentUser="$env:USERDOMAIN\$env:USERNAME";OS=$os.Caption;Build=$os.BuildNumber;LastBoot=$os.LastBootUpTime;Domain=$cs.Domain;PartOfDomain=$cs.PartOfDomain;Generated=Get-Date}
$services = Get-Service | Where-Object { $_.Name -in @('ProfSvc','SamSs','Netlogon','EventLog','Winmgmt') } | Select-Object Name,DisplayName,Status,StartType
Export-Data "context_summary_$RunStamp" @($summary)
Export-Data "key_services_$RunStamp" $services
$html = "<h1>Windows Context - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p><h2>Summary</h2>$(@($summary)|ConvertTo-Html -Fragment)<h2>Services</h2>$($services|ConvertTo-Html -Fragment)"
$html | ConvertTo-Html -Title 'Windows Context' | Set-Content (Join-Path $OutputPath "windows_context_$RunStamp.html") -Encoding UTF8
$services | Format-Table -AutoSize
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
Start-Process explorer.exe -ArgumentList "`"$OutputPath`"" -ErrorAction SilentlyContinue
