#Requires -Version 7.0
<#
.SYNOPSIS


.DESCRIPTION


.PARAMETER


.PARAMETER


.EXAMPLE
    PS C:\>

.EXAMPLE
    PS C:\>

.NOTES
    AUTHOR: Marc-Antoine ROBIN (Metsys)
    CREATION:
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [String]$Config,

    [Parameter(HelpMessage = 'DebugMode, same as -WhatIf. Default is true')]
    [bool]$DebugMode = $true
)

# Exit if running as a managed identity in PowerShell 7.2 due to bugs connecting to MgGraph https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/3151
if ($env:IDENTITY_ENDPOINT -and $env:IDENTITY_HEADER -and $PSVersionTable.PSVersion -eq [version]'7.2.0') {
    Write-Error 'Error, This script cannot run as a managed identity in PowerShell 7.2. Please use a different version of PowerShell.'
    exit 1
}

#region variables
[string]$scriptAction = '[Intune] Primary users management' # Action name for logging

# Log Analytics Workspace used to capture output
if ($outputToLogAnalytics -eq $true) {
    $logAnalyticsLogName = '' # Name of the custom Log Analytics log table that will be used to store a log of changes performed by the script
    $customerID = '' # Replace with your Log Analytics Workspace ID
    $sharedKey = ''  # Replace with your Primary Key for the Log Analytics Workspace
}
if ('AzureAutomation/' -eq $env:AZUREPS_HOST_ENVIRONMENT) {
    $AzureAutomation = $true
    $customerId = Get-AutomationVariable 'customerID'
    $sharedKey = Get-AutomationVariable 'sharedKey'
    $tenantID = Get-AutomationVariable 'tenantid'
}
else {
    $AzureAutomation = $false
}

$Error.Clear()
# Required API permissions
[String[]]$RequiredScopes = @('AuditLog.Read.All','Device.Read.All','DeviceManagementManagedDevices.ReadWrite.All','Group.Read.All','User.Read.All')

# Required PowerShell modules
[String[]]$RequiredModules = @('Logging', 'MSGraphAPI', 'Microsoft.Graph.Authentication')

# Import every module in the specified list
foreach ($moduleName in $requiredModules) {
    try {
        Import-Module $moduleName -Scope Global -EA Stop -Force -Verbose:$false
        Write-Verbose -Message "Successfully imported module '$moduleName'"
    }
    catch {
        Write-Error -Message "Failed to import a required module '$moduleName': $($_.Exception.Message)"
        throw # Stop script if any essential module fails
    }
}

#region Logging/reporting
$Today = Get-Date
$ScriptContext = Get-ScriptContext
$ScriptUser = $ScriptContext.User
$PSScriptParentPath = $ScriptContext.ParentFolder

# Read the configuration file
$ConfigFile = "$PSScriptParentPath\ScriptParameters.xml"
if (! (Test-Path -Path $ConfigFile)) {
    throw "Could not find the configuration file [$ConfigFile]"
}
try {
    [xml]$XmlConfig = Get-Content -Path $ConfigFile -Raw -EA Stop
}
catch {
    throw "Could not parse the configuration file [$ConfigFile]: $($_.Exception.Message)"
}
$ScriptConfig = $XmlConfig.SelectNodes('//Config') | Where-Object -Property Name -EQ $Config
if ($null -eq $ScriptConfig) {
    throw "Failed to find the Config node named [$Config] in [$ConfigFile]"
}
elseif (($ScriptConfig | Measure-Object).Count -gt 1) {
    throw "More than one parameter set is named [$Config] in [$ConfigFile]"
}

$LogFolder = "$PSScriptParentPath\Logs"
$Log = New-LogFile -Path $LogFolder -Suffix $Config -DateTimeFormat 'yyyy-MM-dd' -Verbose
$LogFile = $Log.Path
$PSScriptName = $Log.ScriptName

# Backup and remove last month's logs
Backup-Log -Path $LogFolder -Name $PSScriptName -Before ([datetime]::new($Today.Year, $Today.Month, 1)) -Verbose

$AuditFlag = ''
if ($DebugMode -eq $true) {
    $AuditFlag = '[AUDIT] '
}
#endregion Logging/reporting

$PSDefaultParameterValues.Clear()
$Global:PSDefaultParameterValues.Clear()
$Global:PSDefaultParameterValues['Write-Log:CMTrace'] = $true
$Global:PSDefaultParameterValues['Write-Log:Component'] = "$($AuditFlag)$PSScriptName"
$Global:PSDefaultParameterValues['Write-Log:LogFile'] = $LogFile
$Global:PSDefaultParameterValues['Write-Log:DebugMode'] = ($WhatIfPreference -eq $true) -or ($DebugMode -eq $true)

# Main variables used by the script
$DevicePropertyList = ('id','accountEnabled','deviceid','displayName')

Write-Log -Message ('=' * 80)
Write-Log -Message ('[{0}] started [{1}] using PowerShell {2}' -f $ScriptUser, $ScriptContext.ScriptPath, "$($PSVersionTable.PSVersion)")

# Output the script parameters to the log and create the variables
Write-Log -Message "[ScriptParameter] Using the [$Config] parameter set in [$ConfigFile]"
try {
    foreach ($Param in $ScriptConfig.Param) {
        [String]$VarName = "$($Param.Name)".Trim()
        [String]$VarValue = "$($Param.InnerText)".Trim()
        if (("$VarValue" -eq '') -and ($Param.Type -in ('int','string'))) { continue }
        Write-Log -Message "[ScriptParameter] $VarName = [$VarValue]"
        switch -Regex ($Param.Type) {
            'int' {
                New-Variable -Name $VarName -Value ([int]$VarValue) -Force
                break
            }
            'bool' {
                if ("$VarValue" -eq '') { $VarValue = 'false' }
                New-Variable -Name $VarName -Value ([bool]::Parse($VarValue)) -Force
                break
            }
            'array' {
                # Split the array using a comma and trim the blank spaces before and after each item
                New-Variable -Name $VarName -Value ([String[]]($VarValue -replace '\s*,\s*',',' -split ',' | Where-Object { "$_".Trim() -ne '' })) -Force
                break
            }
            'scriptblock' {
                New-Variable -Name $VarName -Value ([scriptblock]::Create($varvalue))
            }
            Default {
                New-Variable -Name $VarName -Value ([String]$VarValue) -Force
            }
        }
    }
}
catch {
    throw "Failed to validate the script parameters: $($_.Exception.Message)"
}

# Output the LogAnalytics parameters to the log and create the variables
foreach ($Type in ('Intune','EntraId')) {
    if ($null -ne $ScriptConfig.LogAnalytics.$Type) {
        foreach ($VarName in ('SubscriptionId', 'ResourceGroupName', 'workspaceName', 'worskpaceId')) {
            [String]$VarValue = "$($ScriptConfig.LogAnalytics.$Type.$VarName)".Trim()
            Write-Log -Message "[LogAnalytics-$Type] ${VarName}${Type} = [$VarValue]"
            if ($VarValue -eq '') { continue }
            # Variables are named with the attribute name followed by the type (Intune, EntraId)
            # Ex: SubscriptionIdEntraId, SubscriptionIdIntune, ResourceGroupNameIntune, ...
            New-Variable -Name "${VarName}${Type}" -Value $VarValue -Force
        }
    }
}

$Global:PSDefaultParameterValues['Invoke-MgGraphRequestBatch:BatchSize'] = $BatchSize
$Global:PSDefaultParameterValues['Invoke-MgGraphRequestBatch:WaitTime'] = $WaitTime
$Global:PSDefaultParameterValues['Invoke-MgGraphRequestBatch:MaxRetry'] = $MaxRetry
$Global:PSDefaultParameterValues['Invoke-MgGraphRequestSingle:WaitTime'] = $WaitTime
$Global:PSDefaultParameterValues['Invoke-MgGraphRequestSingle:MaxRetry'] = $MaxRetry
#endregion variables


#region functions
. "$PSScriptParentPath\..\Invoke-ScriptReport.ps1" # Import the report function
#endregion functions


#region main
$StartTime = [datetime]::Now

try {
    #region connection
    #Sign in to Graph
    try {
        $ConnectParams = @{
            ConnectAzAccount = $true
            ErrorAction      = 'Stop'
        }
        if ("$CertificateThumbprint".Trim() -ne '') {
            # Connect to MS Graph application using a certificate
            $ConnectParams.TenantId = $TenantId
            $ConnectParams.ApplicationId = $ApplicationId
            $ConnectParams.CertificateThumbprint = $CertificateThumbprint
        }
        elseif (("$TenantId".Trim() -ne '') -and ("$ApplicationId".Trim() -ne '')) {
            # Connect to MS Graph application using a secret
            $ConnectParams.TenantId = $TenantId
            $ConnectParams.ApplicationId = $ApplicationId
        }
        Connect-MgGraphApplication @ConnectParams
        Write-Log -Message 'Success to get Access Token to Graph and Azure'
    }
    catch {
        throw ('Failed to get Access Token to Graph and Azure with error: {0}' -f $_.Exception.Message)
    }

    if ((Test-GraphRequiredScope -Scope $RequiredScopes) -eq $false) {
        throw "You don't have the necessary permissions to run the script: $($RequiredScopes -join ', ')"
    }
    #endregion connection

    # Log rotation timer (checks every 3min if the log size is greater than $LogMaxSize and renames it if so)
    $LogTimer = Register-LogRotationScript -LogFile $LogFile -Delay 3 -LogMaxSize $LogMaxSize -Verbose
    $LogTimer.Start()

    if ($GroupMembershipInclude.Count -gt 0) {
        Write-Log -Message ('Retrieving members of the following groups to build the inclusion list: {0}' -f ($GroupMembershipInclude -join ', '))
        $DirectoryDeviceListInclude = Get-EntraIdGroupMembership -Name $GroupMembershipInclude -Type Device -PropertyList $DevicePropertyList
        Write-Log -Message ('Found {0} devices in {1} groups' -f ($DirectoryDeviceListInclude | Measure-Object).Count, ($DirectoryDeviceListInclude | Select-Object -ExpandProperty GroupName -Unique | Measure-Object).Count)
    }
    if ($GroupMembershipExclude.Count -gt 0) {
        Write-Log -Message ('Retrieving members of the following groups to build the exclusion list: {0}' -f ($GroupMembershipExclude -join ', '))
        $DirectoryDeviceListExclude = Get-EntraIdGroupMembership -Name $GroupMembershipExclude -Type Device -PropertyList $DevicePropertyList
        Write-Log -Message ('Found {0} devices in {1} groups' -f ($DirectoryDeviceListExclude | Measure-Object).Count, ($DirectoryDeviceListExclude | Select-Object -ExpandProperty GroupName -Unique | Measure-Object).Count)
    }

    #region Log Analytics query
    # Build the KQL query
    if ($IncludedNames.Count -gt 0) {
        $deviceNameInclusionKustoString = "| where $(($IncludedNames | Where-Object {"$_".Trim() -ne ''} | ForEach-Object {"DeviceName contains '$("$_".Trim())'"}) -join ' or ')"
    }

    if ($ExcludedNames.Count -gt 0) {
        $deviceNameExclusionKustoString = "| where $(($ExcludedNames | Where-Object {"$_".Trim() -ne ''} | ForEach-Object {"DeviceName !contains '$("$_".Trim())'"}) -join ' and ')"
    }

    if ($ExcludeDeviceModel.Count -gt 0) {
        $deviceModelExclusionKustoString = "| where $(($ExcludeDeviceModel | Where-Object {"$_".Trim() -ne ''} | ForEach-Object {"Model !contains '$("$_".Trim())'"}) -join ' and ')"
    }

    if ($ExcludeExistingUser.Count -gt 0) {
        $userNameExistingExclusionKustoString = "| where $(($ExcludeExistingUser | Where-Object {"$_".Trim() -ne ''} | ForEach-Object {"UPN !contains '$("$_".Trim())'"}) -join ' and ')"
    }

    if ($ExcludeTargetUser.Count -gt 0) {
        $userNameTargetExclusionKustoString = "| where $(($ExcludeTargetUser | Where-Object {"$_".Trim() -ne ''} | ForEach-Object {"UserPrincipalName !contains '$("$_".Trim())'"}) -join ' and ')"
    }

    if ($excludeDevicesWithNoPrimaryUser) {
        $excludeDevicesWithNoPrimaryUserKustoString = '| where isnotempty(UPN)'
    }

    #$DeviceFilterString = "OS contains 'Windows' and Ownership == 'Corporate' and ManagedBy == 'Intune'"
    $DeviceFilterString = "OS contains 'Windows'"

    #$SignInLogsFilter = "| where AppDisplayName == 'Windows Sign In' and UserType == 'Member'"
    $SignInLogsFilter = "| where AppDisplayName == 'Windows Sign In'"

    $kqlQuery = "
set notruncation; // Do not trunc the results
workspace('/subscriptions/$subscriptionIDIntune/resourcegroups/$ResourceGroupNameIntune/providers/microsoft.operationalinsights/workspaces/$workspaceNameIntune').IntuneDevices
| where TimeGenerated >= ago($($IntuneDeviceActivityTimespan)d) and $DeviceFilterString
| where todatetime(CreatedDate) <= ago($($minDeviceAgeDays)d)
$deviceNameInclusionKustoString
$deviceNameExclusionKustoString
$deviceModelExclusionKustoString
$userNameExistingExclusionKustoString
$excludeDevicesWithNoPrimaryUserKustoString
| summarize arg_max(TimeGenerated, *) by DeviceId
| extend ExistingPrimaryUser = UPN, ExistingPrimaryUserID = PrimaryUser, AzureADDeviceID = ReferenceId, IntuneDeviceID = DeviceId
| project DeviceName, IntuneDeviceID, AzureADDeviceID, ExistingPrimaryUser, ExistingPrimaryUserID
| join kind=inner (
    workspace('/subscriptions/$subscriptionIDEntraId/resourcegroups/$ResourceGroupNameEntraId/providers/microsoft.operationalinsights/workspaces/$workspaceNameEntraId').SigninLogs
    | where TimeGenerated >= ago($($SignInsTimeSpan)d)
    $SignInLogsFilter
    $userNameTargetExclusionKustoString
    | extend DeviceName = tostring(DeviceDetail.displayName),DeviceId = tostring(DeviceDetail.deviceId)
    | summarize UserSignInCount = count(UserId) by DeviceId,DeviceName,UserPrincipalName,UserId // Count how many times each user has logged in to a device
    | where UserSignInCount >= $($minUserSignIns)
    | summarize arg_max(UserSignInCount,*) by DeviceId,DeviceName // Get the top user with most sign ins on the device
    | extend AzureADDeviceID = DeviceId, NewPrimaryUser = UserPrincipalName, NewPrimaryUserID = UserId
    | project DeviceName,AzureADDeviceID,NewPrimaryUser,NewPrimaryUserID,UserSignInCount
)
on `$left.AzureADDeviceID==`$right.AzureADDeviceID // Join the tables on the Azure AD Device ID
| where isnotempty(NewPrimaryUser)
| where ExistingPrimaryUserID !~ NewPrimaryUserID
| project DeviceName, IntuneDeviceID, AzureADDeviceID, ExistingPrimaryUser, ExistingPrimaryUserID, NewPrimaryUser, NewPrimaryUserID, UserSignInCount // Return the IntuneDeviceID required to update the Primary user in Graph
" -creplace '(?m)^\s*\r?\n' # Trim any blank lines where the exclusion variables are empty

    Write-Log -Message 'Running Log Analytics Query to retrieve Intune devices and existing primary users and compare with Azure AD Sign-In Logs to identify the user most frequently signed in to each device with KQL Query'
    # Add a Status property to the output
    $ReportResults = Invoke-LogAnalyticsQuery -tenantId $tenantID -subscriptionID $subscriptionIDIntune -ResourceGroupName $ResourceGroupNameIntune -workspaceName $workspaceNameIntune -query $kqlQuery | Select-Object -Property *, Status

    [int]$primaryUserUpdatesCount = ($ReportResults | Measure-Object).Count
    #endregion Log Analytics query

    $ErrorActionPreference = 'continue'

    Write-Log -Message "Total Primary User updates required: [$($PrimaryUserUpdatesCount)]"

    # Process the primary user changes
    if ($primaryUserUpdatesCount -gt 0) {
        Write-Log -Message ('List the current primary users for {0} Intune devices' -f $primaryUserUpdatesCount)
        $IntuneDeviceInfo = Invoke-MgGraphRequestBatch -Resource 'deviceManagement/manageddevices' -ObjectList $ReportResults.IntuneDeviceID -Select 'userprincipalName','userid'

        [String[]]$UniqueUserList = $ReportResults | Select-Object -ExpandProperty NewPrimaryUserID -Unique
        Write-Log -Message ('List the licence info for {0} users. It will be used to check whether the user has an Intune licence assigned.' -f $UniqueUserList.Count)
        $IntuneLicenceInfo = Invoke-MgGraphRequestBatch -Resource 'users' -ObjectList $UniqueUserList -Query 'licenseDetails' -Select 'servicePlans'

        Write-Log -Message 'Processing Primary User changes using Graph.'
        $i = 0
        foreach ($update in $ReportResults) {
            $i++
            if ($AzureAutomation) {
                Write-Output -Message "Processing Intune device [$($update.DeviceName)|$($update.IntuneDeviceID)] [$($i)/$($primarUserUpdatesCount)]. Overall status: [$(($i/$($PrimaryUserUpdatesCount)*100))%] completed"
            }
            else {
                Write-Log -Message "[$i/$PrimaryUserUpdatesCount] Processing Intune device [$($update.DeviceName)|$($update.IntuneDeviceID)]: [$($update.ExistingPrimaryUser -replace '^$','{Empty}')] => [$($Update.NewPrimaryUser)] (Sign-in count: $($update.UserSignInCount))"
            }

            if ((($DirectoryDeviceListExclude | Measure-Object).Count -gt 0) -and ($Update.DeviceName -in $DirectoryDeviceListExclude.displayname)) {
                # Filter out devices if excluded devicenames are provided
                Write-Log -Message ('Skipping the device because it belongs to one of the exclusion groups: {0}' -f ($GroupMembershipExclude -join ', ')) -Type Warning
                $update.Status = 'Skipped: Excluded'
                continue
            }

            if ((($DirectoryDeviceListInclude | Measure-Object).Count -gt 0) -and (($Update.DeviceName -notin $DirectoryDeviceListInclude.displayname))) {
                # Filter in devices if included devicenames are provided
                Write-Log -Message ('Skipping the device because it does not belong to one of the inclusion groups: {0}' -f ($GroupMembershipInclude -join ', ')) -Type Warning
                $update.Status = 'Skipped: Not included'
                continue
            }

            # Users need an Intune licence to be set as primary user of devices
            $UserLicences = ($IntuneLicenceInfo | Where-Object -Property id -EQ $Update.NewPrimaryUserID).body.value.serviceplans | Where-Object -Property serviceplanname -Match 'intune' | Where-Object -Property appliesTo -EQ 'User'
            $DisabledIntuneLicence = $UserLicences | Where-Object -Property provisioningStatus -EQ 'disabled'
            if (($null -ne $DisabledIntuneLicence) -or (($UserLicences | Measure-Object).Count -eq 0)) {
                Write-Log -Message "[$i/$PrimaryUserUpdatesCount] User [$($Update.NewPrimaryUser)] does not seem to have a valid Intune licence, the next action may fail: $($UserLicences | ConvertTo-Json)" -Type Warning
            }
            <# else {
                Write-Log -Message "[$i/$PrimaryUserUpdatesCount] User [$($Update.NewPrimaryUser)] has the following Intune licence(s): $($UserLicences | ConvertTo-Json)"
            } #>

            $CurrentPrimaryUserInfo = $IntuneDeviceInfo | Where-Object -Property id -EQ $Update.IntuneDeviceID
            if (($null -eq $CurrentPrimaryUserInfo) -or ($CurrentPrimaryUserInfo.Status -ne 200)) {
                Write-Log -Message "[$i/$PrimaryUserUpdatesCount] Device [$($Update.DeviceName)] was not found" -Type Error
                $update.Status = 'Error: Device not found'
            }
            elseif ($CurrentPrimaryUserInfo.Body.UserId -eq $update.NewPrimaryUserID) {
                Write-Log -Message "[$i/$PrimaryUserUpdatesCount] User [$($Update.NewPrimaryUser)] is already set as the primary user of [$($Update.DeviceName)]" -Type Warning
                $update.Status = 'Skipped: Primary user already set'
            }
            elseif ($DebugMode -eq $false) {
                try {
                    $GRParams = @{
                        APIVersion  = 'beta'
                        Method      = 'POST'
                        Body        = @{
                            '@odata.id' = "https://graph.microsoft.com/beta/users/$($update.NewPrimaryUserID)"
                        }
                        Resource    = "deviceManagement/managedDevices/$($update.IntuneDeviceID)/users/`$ref"
                        ErrorAction = 'Stop'
                    }
                    Invoke-MgGraphRequestSingle @GRParams
                    Write-Log -Message ('{0} Successfuly modified the primary user' -f "[$i/$PrimaryUserUpdatesCount]")
                    $update.Status = 'Success'
                }
                catch {
                    $ErrorMessage = (($_.Exception.Message -replace '^[^\{]+' | ConvertFrom-Json).Message -split ('\.* - Operation'))[0] # Keep the error description before the Operation ID part
                    $update.Status = 'Error: {0}' -f $ErrorMessage
                    $Error.RemoveAt(0)
                    Write-Log -Message ('{0} Failed to update the primary user: {1}' -f "[$i/$PrimaryUserUpdatesCount]", $ErrorMessage)
                }
            }
            else {
                $update.Status = 'Audit'
            }
        }

        if ($outputToLogAnalytics -eq $true) {
            Write-Log -Message "Sending the Primary User changes to Log Analytics table: [$logAnalyticsLogName]"
            $jsonOutput = $ReportResults | ConvertTo-Json
            Send-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($jsonOutput)) -logType $logAnalyticsLogName
        }
    }
    $GlobalError = ''
}
catch {
    $GlobalError = "$($_.Exception.Message) (l. $($_.InvocationInfo.ScriptLineNumber))"
    Write-Log -Message 'Error while executing the script'
}
finally {
    $EndTime = [datetime]::Now

    # Stop and unregister the log rotation event
    if ($null -ne $LogTimer) {
        $LogTimer.Stop()
        Get-EventSubscriber | Where-Object -Property SourceObject -EQ $LogTimer | Unregister-Event -EA Ignore
    }

    $ReportResultCount = ($ReportResults | Measure-Object).Count
    $ReportParams = @{
        DebugMode       = $DebugMode
        InputObject     = $ReportResults
        ConfigName      = $Config
        ScriptParams    = $ScriptConfig.Param
        ScriptAction    = $scriptAction
        DetailedReport  = $DetailedReport
        ReportToDisk    = $ReportToDisk
        ReportPath      = $ReportPath
        ScriptStartTime = $StartTime
        ScriptEndTime   = $EndTime
        GlobalError     = $GlobalError
        SendMail        = $SendMail
    }
    $RemoveZipFile = $false
    if ($SendMail -eq $true) {
        [String[]]$LogList = (Get-ChildItem -Path "$LogFile".Replace('.log','*.log')).FullName
        if ($LogList.Count -gt 1) {
            # Compress the logs in a zip file
            $ZipFile = "$LogFile".Replace('.log','.zip')
            Compress-Archive -Path $LogList -DestinationPath $ZipFile -CompressionLevel Optimal -Force -ErrorAction Ignore
            if (Test-Path -Path $ZipFile) {
                $RemoveZipFile = $true
                [String[]]$LogList = $ZipFile
            }
        }
        $ReportParams.MailSender = $MailSender
        $ReportParams.MailRecipient = $MailRecipient
        $ReportParams.MailCc = $MailCc
        $ReportParams.MailAttachment = @($MailAttachment) + $LogList
        $ReportParams.SmtpServer = $SmtpServer
        $ReportParams.SmtpPort = $SmtpPort
        $ReportParams.MailIdentityFile = $MailIdentityFile
    }
    if (($ReturnReport -eq $true) -and (($ReportResultCount -gt 0) -or ($GlobalError -ne ''))) {
        Invoke-ScriptReport @ReportParams
        Write-Log -Message "Generated summary report (Detailed: $DetailedReport)"
    }
    elseif (($ReturnReport -eq $true) -and ($ReportResultCount -eq 0)) {
        Write-Log -Message 'Cannot generate an empty summary report' -Type Warning
    }

    if ($RemoveZipFile) {
        Remove-Item -Path $ZipFile -Force -EA Ignore
    }

    # Disconnect from Graph and Azure
    if ($null -ne (Get-MgContext)) {
        try {
            $null = Disconnect-MgGraph -ErrorAction Stop
            Write-Log -Message 'Disconnected from Graph'
        }
        catch {
            Write-Log -Message 'Failed to disconnect from Graph'
        }
    }

    if ($null -ne (Get-AzContext)) {
        try {
            $null = Disconnect-AzAccount -ErrorAction Stop
            Write-Log -Message 'Disconnected from Azure'
        }
        catch {
            Write-Log -Message 'Failed to disconnect from Graph'
        }
    }

    # End script and report memory usage
    $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
    $MemoryUsageAfter = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
    Write-Log -Message "Script finished. Memory usage: $MemoryUsage MB ($MemoryUsageAfter MB after cleanup)"
    Write-Log -Message ('=' * 80)
    $PSDefaultParameterValues.Clear()
}
#endregion main