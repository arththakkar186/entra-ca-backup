# Conditional Access Backup (Microsoft Graph + PowerShell)

A read-only PowerShell tool that backs up every Entra ID Conditional Access policy to timestamped JSON, with a summary CSV. Built for version control, change review, disaster recovery and audit evidence.

## What it does

- Exports each Conditional Access policy to its own full-fidelity JSON file
- Writes a `_summary.csv` listing every policy's name, state and last-modified date
- Organizes output into a timestamped folder so runs never overwrite each other

Commit the output to a Git repo after each run and you get a dated history of every Conditional Access change, which makes drift obvious and gives auditors a clean trail.

## Why it exists

Conditional Access is one of the highest-impact and least-backed-up parts of a tenant. A single bad change can lock out users or open a hole. This captures the full state in seconds so you can diff, review and restore.

## Usage

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns -Scope CurrentUser

# Back up to the default .\ca-backup folder
.\Backup-ConditionalAccessPolicies.ps1 -Verbose

# Back up to a specific location
.\Backup-ConditionalAccessPolicies.ps1 -OutputRoot C:\Backups\CA
```

## Permissions

Delegated, read-only scope requested at run time: `Policy.Read.All`

## Notes

The script changes nothing in the tenant. It reads, writes local files, and disconnects.
