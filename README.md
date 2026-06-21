# Windows Credential Provider Diagnostic Toolkit

A PowerShell toolkit for Windows sign-in context reporting and guarded credential-provider recovery.

## Existing diagnostic script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Context_Reporter.ps1
```

The existing reporter remains read-only and records operating-system, service and domain or workgroup context.

## Repair script

Preview a provider repair:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Credential_Provider_Repair_Toolkit.ps1 -ProviderGuid '00000000-0000-0000-0000-000000000000' -EnableProvider -DryRun
```

Examples:

```powershell
.\Windows_Credential_Provider_Repair_Toolkit.ps1 -ProviderGuid 'GUID-HERE' -EnableProvider
.\Windows_Credential_Provider_Repair_Toolkit.ps1 -RestoreWinlogonDefaults
.\Windows_Credential_Provider_Repair_Toolkit.ps1 -RestartIdentityServices
```

## Repair behaviour

- Enables one already registered credential provider by clearing its disabled state.
- Refuses to create a credential-provider registration that does not already exist.
- Restores the standard Winlogon `Shell` and `Userinit` values when explicitly requested.
- Starts or restarts available Vault, token broker, Windows Hello container and biometric services.
- Exports the relevant Winlogon and provider registry keys before changes.
- Captures provider, Winlogon and identity-service state before and after repair.
- Supports `-DryRun`, confirmation prompts or `-Yes`, administrator checks, logs and verification.

## Safety and exit codes

Credential-provider and Winlogon changes can affect interactive sign-in. Confirm the provider GUID and maintain an alternate administrator sign-in method. The tool does not delete credentials, reset Windows Hello, disable providers or change passwords.

Exit codes: `0` success, `2` invalid arguments, `3` unsupported platform, `4` elevation required, `10` cancelled, `20` action failure and `30` verification failure.

## Validation note

The repair script was committed and statically reviewed, but it was not runtime-tested on a Windows endpoint.

## Author

Dewald Pretorius — L2 IT Support Engineer
