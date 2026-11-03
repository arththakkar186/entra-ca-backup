<#
.SYNOPSIS
    Backs up Entra ID Conditional Access policies to timestamped JSON.

.DESCRIPTION
    Connects to Microsoft Graph and exports every Conditional Access policy
    in the tenant to individual JSON files, plus a summary CSV listing each
    policy's name, state and last-modified date. The JSON is a full fidelity
    copy suitable for version control, change review, disaster recovery and
    audit evidence.

    Point this at a Git repo and commit after each run to keep a dated
    history of every Conditional Access change. The script is read-only and
    changes nothing in the tenant.

.PARAMETER OutputRoot
    Folder to write the backup into. A timestamped subfolder is created
    inside it. Defaults to .\ca-backup.

.EXAMPLE
    .\Backup-ConditionalAccessPolicies.ps1 -Verbose

.EXAMPLE
    .\Backup-ConditionalAccessPolicies.ps1 -OutputRoot C:\Backups\CA

.NOTES
    Author : Arth Thakkar
    Scopes : Policy.Read.All
    Modules: Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns
#>

[CmdletBinding()]
param(
    [string]$OutputRoot = ".\ca-backup"
)

$ErrorActionPreference = 'Stop'

function Connect-Tenant {
    param([string[]]$Scopes)
    $context = Get-MgContext
    if (-not $context -or ($Scopes | Where-Object { $_ -notin $context.Scopes })) {
        Connect-MgGraph -Scopes $Scopes -NoWelcome
    }
    Write-Verbose "Connected as $((Get-MgContext).Account)"
}

try {
    Connect-Tenant -Scopes @('Policy.Read.All')

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $target = Join-Path $OutputRoot $stamp
    New-Item -ItemType Directory -Path $target -Force | Out-Null

    Write-Verbose "Retrieving Conditional Access policies..."
    $policies = Get-MgIdentityConditionalAccessPolicy -All

    if (-not $policies) {
        Write-Warning "No Conditional Access policies found."
        return
    }

    $summary = foreach ($policy in $policies) {
        # Sanitize the display name so it is safe as a file name.
        $safeName = ($policy.DisplayName -replace '[\\/:*?"<>|]', '_').Trim()
        $file = Join-Path $target "$safeName.json"
        $policy | ConvertTo-Json -Depth 20 | Out-File -FilePath $file -Encoding UTF8

        [pscustomobject]@{
            DisplayName      = $policy.DisplayName
            State            = $policy.State
            CreatedDateTime  = $policy.CreatedDateTime
            ModifiedDateTime = $policy.ModifiedDateTime
            Id               = $policy.Id
        }
    }

    $summaryPath = Join-Path $target "_summary.csv"
    $summary | Sort-Object State, DisplayName |
        Export-Csv -Path $summaryPath -NoTypeInformation -Encoding UTF8

    Write-Host "Conditional Access backup complete." -ForegroundColor Green
    Write-Host "  Policies exported : $($policies.Count)"
    Write-Host "  Enabled           : $(($summary | Where-Object State -eq 'enabled').Count)"
    Write-Host "  Report-only       : $(($summary | Where-Object State -eq 'enabledForReportingButNotEnforced').Count)"
    Write-Host "  Disabled          : $(($summary | Where-Object State -eq 'disabled').Count)"
    Write-Host "  Location          : $target"
}
catch {
    Write-Error "Backup failed: $($_.Exception.Message)"
    exit 1
}
finally {
    if (Get-MgContext) {
        Disconnect-MgGraph | Out-Null
        Write-Verbose "Disconnected from Microsoft Graph."
    }
}
