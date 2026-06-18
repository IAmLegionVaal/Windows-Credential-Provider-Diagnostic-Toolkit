# Windows Credential Provider Diagnostic Toolkit

A read-only PowerShell toolkit for Windows sign-in provider and authentication context review.

## Features

- Sign-in related service context
- Windows Hello related context
- Recent authentication event summary
- dsregcmd status export
- CSV, TXT, and HTML reports

## How to run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Credential_Provider_Diagnostic_Toolkit.ps1
```

## Safety

Diagnostic-only. It does not read secrets or change sign-in settings.
