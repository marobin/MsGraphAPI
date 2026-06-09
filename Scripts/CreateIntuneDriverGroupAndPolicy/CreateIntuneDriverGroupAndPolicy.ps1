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
    AUTHOR: Marc-Antoine ROBIN
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
[string]$scriptAction = '[Intune] Driver update rings management' # Action name for logging

$Error.Clear()
# Required API permissions
[String[]]$RequiredScopes = @('DeviceManagementManagedDevices.ReadWrite.All','DeviceManagementConfiguration.ReadWrite.All','Group.ReadWrite.All','Device.Read.All')

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
$DevicePropertyList = ('id','accountEnabled','deviceid','displayName','manufacturer','model')
$ReportResults = New-Object -TypeName System.Collections.ArrayList
$GuidPattern = '^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$' # Used to validate guids
$UPNPattern = '^[^@]+@[\w_\.-]+\.\w{2,4}$' # Used to validate UserPrincipalNames (Ex: foobar@domain.com)

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
#endregion variables


#region functions
. "$PSScriptParentPath\..\Invoke-ScriptReport.ps1" # Import the report function

function New-DriverUpdateProfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$DisplayName,

        [Parameter(Mandatory = $true, Position = 1)]
        [String]$Model,

        [Parameter(Position = 2)]
        [String[]]$ScopeTag,

        [Parameter(Mandatory = $true, Position = 3)]
        [String]$Include,

        [Parameter(Position = 4)]
        [String]$Ring
    )

    # Test if the profile already exists
    $GRParams = @{
        APIVersion = 'beta' # does not work with v1.0 => [Bad request] Resource not found for the segment
        Resource   = 'deviceManagement/windowsDriverUpdateProfiles'
        PageSize   = 200
        Select     = 'id','displayName'
    }
    $AllDriverProfiles = Invoke-MgGraphRequestSingle @GRParams

    if ($DisplayName -notin $AllDriverProfiles.displayName) {
        Write-Log -Message "Creating missing Driver Update Profile [$DisplayName]"

        $Description = "Driver update profile for $Model"
        if ("$Ring".Trim() -ne '') {
            $Description = "$Description ($Ring ring)"
        }

        $ProfileBody = @{
            '@odata.type'   = '#microsoft.graph.windowsDriverUpdateProfile'
            #id = (New-Guid).Guid.Substring(0,10) # The Intune policy id.
            displayName     = "$DisplayName" # The display name for the profile.
            description     = $Description # The description of the profile which is specified by the user.
            approvalType    = 'manual' # Driver update profile approval type. For example, manual or automatic approval. Possible values are: manual, automatic.
            deviceReporting = 0 # Number of devices reporting for this profile
            newUpdates      = 0 # Number of new driver updates available for this profile.
            #deploymentDeferralInDays = '' # Deployment deferral settings in days, only applicable when ApprovalType is set to automatic approval.
            roleScopeTagIds = @($ScopeTag) # List of Scope Tags for this Driver Update entity.
            #ContentType     = 'application/json'
            #createdDateTime = '' # [DateTimeOffset] The date time that the profile was created.
            #lastModifiedDateTime = '' # [DateTimeOffset] The date time that the profile was last modified.
            #inventorySyncStatus = '' # [windowsDriverUpdateProfileInventorySyncStatus] Driver inventory sync status for this profile.
        }
        $GRParams = @{
            APIVersion = 'beta'
            Method     = 'POST'
            Resource   = 'deviceManagement/windowsDriverUpdateProfiles'
            Body       = $ProfileBody
        }
        $DUProfile = Invoke-MgGraphRequestSingle @GRParams
    }
    else {
        Write-Log -Message "Driver Update profile [$DisplayName] already exists"
        $DUProfile = $AllDriverProfiles | Where-Object -Property DisplayName -EQ $DisplayName
    }
    $DUProfile
    <#
@odata.context
id
displayName
description
approvalType
deviceReporting
newUpdates
deploymentDeferralInDays
createdDateTime
lastModifiedDateTime
roleScopeTagIds
inventorySyncStatus
    #>

    $GRParams = @{
        APIVersion = 'beta'
        Resource   = 'deviceManagement/windowsDriverUpdateProfiles/{0}/assignments' -f $DUProfile.id
    }
    $AssignedGroups = Invoke-MgGraphRequestSingle @GRParams | Where-Object { $_.Target.groupid -eq $Include }

    Write-Log -Message 'Assigning the driver update profile'
    foreach ($GroupId in $Include) {
        if ($GroupId -in ($AssignedGroups.target.groupid)) { continue }
        $AssignBody = @{
            assignments = @(
                @{
                    target = @{
                        '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                        # #microsoft.graph.exclusionGroupAssignmentTarget
                        groupId       = $GroupId
                    }
                }
            )
        }
        $GRParams = @{
            APIVersion = 'beta'
            Method     = 'POST'
            Resource   = 'deviceManagement/windowsDriverUpdateProfiles/{0}/assign' -f $DUProfile.id
            Body       = $AssignBody
        }
        Invoke-MgGraphRequestSingle @GRParams
    }
}
#endregion functions


#region main
$StartTime = [datetime]::Now

try {
    #region connection
    #Sign in to Graph
    try {
        $ConnectParams = @{
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
        Write-Log -Message 'Success to get Access Token to Graph'
    }
    catch {
        throw ('Failed to get Access Token to Graph with error: {0}' -f $_.Exception.Message)
    }

    if ((Test-GraphRequiredScope -Scope $RequiredScopes) -eq $false) {
        throw "You don't have the necessary permissions to run the script: $($RequiredScopes -join ', ')"
    }
    #endregion connection

    # Log rotation timer (checks every 3min if the log size is greater than $LogMaxSize and renames it if so)
    $LogTimer = Register-LogRotationScript -LogFile $LogFile -Delay 3 -LogMaxSize $LogMaxSize -Verbose
    $LogTimer.Start()

    # Get the rings from the configuration file
    $RingList = $ScriptConfig.RingList.Ring | Select-Object -Property RingName, @{Label = 'GroupName'; Expression = { [String[]]($_.GroupName -replace '\s*,\s*',',' -split ',' | Where-Object { "$_".Trim() -ne '' }) } }

    $DynamicRing = $RingList | Where-Object { $_.GroupName.Count -eq 0 }
    $DynamicRingCount = ($DynamicRing | Measure-Object).Count
    switch ($DynamicRingCount) {
        0 {
            Write-Log -Message ('None of the rings has no group defined (no broad deployment), the script cannot continue' -f ($DynamicRing -join ', '))
            throw
        }
        { $_ -gt 1 } {
            Write-Log -Message ('More than one ring has no group defined ({0}), the script cannot continue' -f ($DynamicRing -join ', '))
            throw
        }
    }

    if ($ExcludedManufacturers -notcontains 'Lenovo') {
        # Lenovo uses a specific model name convention
        $URL = 'https://download.lenovo.com/bsco/public/allModels.json'
        Invoke-RestMethod -Uri $URL -Method GET -OutFile "$PSScriptParentPath\LenovoModels.json"
        $RefLenovoModel = Get-Content -Path "$PSScriptParentPath\LenovoModels.json" | ConvertFrom-Json
    }

    Write-Log -Message ('Getting scope tags id for: {0}' -f ($ScopeTag -join ', '))
    $GRParams = @{
        APIVersion = 'beta' # does not work with v1.0 => [Bad request] Resource not found for the segment
        Resource   = 'deviceManagement/roleScopeTags'
        PageSize   = 50
        Select     = 'id','displayName'
    }
    $ScopeTagList = Invoke-MgGraphRequestSingle @GRParams | Where-Object -Property DisplayName -In $ScopeTag

    [String[]]$OwnerList = $(
        if ($GroupOwnersFromUsers.Count -gt 0) {
            $GroupOwnersFromUsers = $GroupOwnersFromUsers | Where-Object { ($_ -match $GuidPattern) -or ($_ -match $UPNPattern) }
            Write-Log -Message ('Adding {0} users in the list of owners for the new groups' -f $GroupOwnersFromUsers.Count)
        }
        if ($GroupOwnersFromGroups.Count -gt 0) {
            Write-Log -Message ('Listing the users in [{0}] to set the owners of the new groups' -f ($GroupOwnersFromGroups -join ', '))
            [String[]]$OwnersGroupMemberList = Get-EntraIdGroupMembership -Name $GroupOwnersFromGroups -Type User -PropertyList id | Select-Object -ExpandProperty id
            Write-Log -Message "Found $(($AllDeviceList | Measure-Object).Count) devices"
            Write-Log -Message ('Adding {0} users in the list of owners for the new groups' -f $OwnersGroupMemberList.Count)
            $OwnersGroupMemberList
        }
    )

    Write-Log -Message 'Listing every Windows device in Entra ID'
    $AllDeviceList = Invoke-MgGraphRequestSingle -Resource 'devices' -Filter "operatingsystem eq 'Windows'" -Select $DevicePropertyList
    Write-Log -Message "Found $(($AllDeviceList | Measure-Object).Count) devices"

    Write-Log -Message "Listing Windows devices belonging to the following rings: $($RingList.RingName -join ', ')"
    $DirectoryDeviceList = $(
        foreach ($RingItem in $RingList) {
            if (($RingItem.GroupName | Measure-Object).Count -gt 0) {
                Get-EntraIdGroupMembership -Name $RingItem.GroupName -Type Device -PropertyList $DevicePropertyList |
                    Select-Object -Property @{Label = 'Ring'; Expression = { $RingItem.RingName } },*
            }
        }
    )
    Write-Log -Message "Found $(($DirectoryDeviceList | Measure-Object).Count) devices in those rings"

    $ModelList = $AllDeviceList |
        Group-Object -Property { $_.Model -replace ' 2[- ]in[- ]1' -replace ' Detachable' } |
        Where-Object -Property Count -GE $MinDeviceNumber |
        Where-Object -Property Name -NE '' |
        Sort-Object -Property Count -Descending
    Write-Log -Message "Found $(($ModelList | Measure-Object).Count) models with more than $MinDeviceNumber devices: "
    foreach ($ModelItem in $ModelList) {
        Write-Log -Message "    - ($($ModelItem.Count)) $($ModelItem.Name)"
    }
    #endregion initialisation

    foreach ($ModelItem in $ModelList) {
        #region model parsing
        $PSDefaultParameterValues['Write-Log:Component'] = "${AuditFlag}Model parsing"

        Write-Log -Message ('#' * 80)

        $Vendor = $DeviceManufacturer = $ModelItem.group[0] | Select-Object -ExpandProperty Manufacturer -First 1
        $Vendor = ($DeviceManufacturer -split '[ ,-]')[0]

        $ResultObject = [PSCustomObject]@{
            Vendor                = $Vendor
            Model                 = $ModelItem.Name
            RingName              = ''
            GroupName             = ''
            PolicyName            = ''
            MembershipType        = ''
            StaticMembershipCount = 0
            Action                = ''
        }

        if ($Vendor -eq 'HEWLETT') { $Vendor = 'HP' }
        if ($Vendor | Select-String -Pattern $ExcludedManufacturers -Quiet) {
            $ResultObject.Action = 'Skipped (Vendor)'
            $null = $ReportResults.Add($ResultObject)
            Write-Log -Message "Skip vendor [$Vendor] (Model: $($ModelItem.Name))" -Type Warning
            continue
        }

        [String]$Model = $DeviceModel = $ModelItem.Name
        if ("$Model".Trim() -in ('','Unknown')) {
            $ResultObject.Action = 'Skipped (Model)'
            $null = $ReportResults.Add($ResultObject)
            Write-Log -Message "Skip model [$Model] (Vendor: $Vendor)" -Type Warning
            continue
        }
        $Message = "Processing [$DeviceManufacturer] [$DeviceModel]"
        try { $PadLength = ((80 - $Message.Length - 2) / 2) }
        catch { $Error.RemoveAt(0); $PadLength = 25 }
        Write-Log -Message "$('#' * $PadLength) $Message $('#' * $PadLength)"

        switch ($Vendor) {
            'Lenovo' {
                $MTM = $DeviceModel.Substring(0,4)
                $LenovoModel = $RefLenovoModel |
                    Where-Object { ($_ -match "\b$MTM\b") -and ($_ -notmatch 'dTPM|Asset|fTPM|-UEFI Lenovo') } |
                    Select-Object -First 1 -Property @{Label = 'ModelName'; Expression = { ($_.Name -replace '([^\(]+)\(.+','$1').Trim() } },
                    @{Label = 'ModelID'; Expression = { $_.Name -replace '[^\(]+\(([^\(]+)\)','$1' -split ',' } }
                if ($null -ne $LenovoModel) {
                    [String[]]$ModelIDList = $LenovoModel.ModelID
                    $Model = $LenovoModel.ModelName
                }
                else {
                    [String[]]$ModelIDList = @($MTM)
                    $Model = $MTM
                }
                $DevicePerRingList = $DirectoryDeviceList | Where-Object { $_.Model | Select-String -Pattern "^($($ModelIDList -join '|'))" -SimpleMatch -Quiet }

                Write-Log -Message "Manufacturer is [$Vendor]. Model convertion from [$($DeviceModel)] to [$Model] "
                Write-Log -Message "$($ModelIDList.Count) sub models found: $($ModelList -join ', ')"

                $GroupQuery = -join $(
                    '(device.deviceManufacturer -eq "{0}") and (' -f $DeviceManufacturer
                    $(
                        foreach ($ModelID in $ModelIDList) {
                            '(device.deviceModel -startsWith "{0}")' -f $ModelID
                        }
                    ) -join ' -or '
                    ')'
                )
                $GroupDescription = "Dynamic group for $Model ($MTM)"
            }
            Default {
                [String[]]$ModelIDList = $ModelItem.group | Select-Object -ExpandProperty Model -Unique
                if ($ModelIDList.Count -gt 1) {
                    Write-Log -Message "Sub model list: $($ModelIDList -join ', ')"
                }
                $DevicePerRingList = $DirectoryDeviceList | Where-Object -Property Model -In $ModelIDList
                $GroupDescription = "Dynamic group for $($DeviceModel)"
                $GroupQuery = -join $(
                    '(device.deviceManufacturer -eq "{0}") and (' -f $DeviceManufacturer
                    $(
                        foreach ($ModelID in $ModelIDList) {
                            '(device.deviceModel -eq "{0}")' -f $ModelID
                        }
                    ) -join ' -or '
                    ')'
                )
            }
        }

        $Model = Invoke-Command -ScriptBlock $RenameModel -ArgumentList $Model -ErrorAction Stop # Rename the model using the provided scriptblock
        #endregion model parsing

        #region creation of groups and profiles
        foreach ($RingItem in $RingList) {
            $Ring = $RingItem.RingName
            $RingGroupName = $ExecutionContext.InvokeCommand.ExpandString($GroupNamePrefix)
            $PolicyName = $ExecutionContext.InvokeCommand.ExpandString($PolicyNamePrefix) # Expand the policy name prefix
            $ResultObject = [PSCustomObject]@{
                Vendor                = $Vendor
                Model                 = $ModelItem.Name
                RingName              = $Ring
                GroupName             = $RingGroupName
                PolicyName            = $PolicyName
                MembershipType        = ''
                StaticMembershipCount = 0
                Action                = ''
            }

            $PSDefaultParameterValues['Write-Log:Component'] = "${AuditFlag}$Ring Ring"
            [String[]]$DeviceRingMembers = $DevicePerRingList | Where-Object -Property Ring -EQ $Ring | Select-Object -ExpandProperty id

            $DUGroup = Invoke-MgGraphRequestSingle -Resource 'groups' -Filter "displayName eq '$RingGroupName'" -Select id,description,membershipRule
            if ($null -ne $DUGroup) {
                Write-Log -Message "The group [$RingGroupName] already exists"
                if ($Ring -eq $DynamicRing.RingName) {
                    $ResultObject.MembershipType = 'Dynamic'
                    if ($DUGroup.membershipRule -ne $GroupQuery) {
                        Write-Log -Message "The dynamic query for [$RingGroupName] is not the same as the target one: [$($DUGroup.membershipRule)] <> [$GroupQuery]" -Type 'Warning'
                        if ($DebugMode -eq $false) {
                            Invoke-MgGraphRequestSingle -Resource "groups/$($DUGroup.id)" -Method PATCH -Body @{ membershipRule = $GroupQuery }
                            Write-Log -Message 'Modified the group membership query'
                            $ResultObject.Action = 'Success (Modify group query)'
                        }
                        else {
                            $ResultObject.Action = 'Audit (Modify group query)'
                        }
                    }
                }
                else {
                    $ResultObject.MembershipType = 'Static'
                    [String[]]$CurrentGroupMembership = Get-EntraIdGroupMembership -Id $DUGroup.id -Type Device -PropertyList id | Select-Object -ExpandProperty id
                    [String[]]$MembershipDifference = Compare-Object -ReferenceObject @($CurrentGroupMembership) -DifferenceObject @($DeviceRingMembers) -EA Ignore | Where-Object -Property SideIndicator -EQ '=>' | Select-Object -ExpandProperty InputObject
                    if ($MembershipDifference.Count -gt 0) {
                        Write-Log -Message "The group [$RingGroupName] is missing $($MembershipDifference.Count) member(s)" -Type 'Warning'
                        if ($DebugMode -eq $false) {
                            $Result = Add-EntraIdGroupMember -Id $DUGroup.Id -Members $MembershipDifference -MemberType device
                            if ($AddFailures = ($Result | Where-Object -Property Action -EQ 'Failure')) {
                                Write-Log -Message "Failed to add $(($AddFailures | Measure-Object).Count) member(s) to the group: $($AddFailures.members -join ', ')" -Type Error
                                $ResultObject.Action = 'Failure (Modify group membership)'
                            }
                            else {
                                Write-Log -Message "Added $($MembershipDifference.Count) member(s) to the group"
                                $ResultObject.Action = 'Success (Modify group membership)'
                            }
                            $ResultObject.StaticMembershipCount = $CurrentGroupMembership.Count + (($Result | Where-Object -Property Action -EQ 'Success' | Measure-Object).Count)
                        }
                        else {
                            $ResultObject.Action = 'Audit (Modify group membership)'
                            $ResultObject.StaticMembershipCount = $CurrentGroupMembership.Count + $MembershipDifference.Count
                        }
                    }
                    else {
                        $ResultObject.StaticMembershipCount = $CurrentGroupMembership.Count
                    }
                }
                if (($DebugMode -eq $false) -and ($OwnerList.Count -gt 0)) {
                    Add-EntraIdGroupOwner -Groupid $DUGroup.Id -Owner $OwnerList
                }
            }
            else {
                $GroupParams = @{
                    DisplayName = "$RingGroupName"
                    Description = "$GroupDescription in Ring [$Ring]"
                    ErrorAction = 'Stop'
                }
                if ($OwnerList.Count -gt 0) {
                    $GroupParams.Owner = $OwnerList
                }
                if ($Ring -eq $DynamicRing.RingName) {
                    $ResultObject.MembershipType = 'Dynamic'
                    $GroupParams.DynamicQuery = $GroupQuery
                    Write-Log -Message "Creating a dynamic group [$RingGroupName] with query [$GroupQuery]"
                }
                else {
                    $ResultObject.MembershipType = 'Static'
                    if ($DeviceRingMembers.Count -eq 0) {
                        Write-Log -Message ('No [{0}] was found in the {1} ring' -f $DeviceModel,$Ring) -Type Error
                    }
                    $GroupParams.Description = "$($GroupParams.Description)".Replace('Dynamic','Static')
                    $GroupParams.Members = [String[]]$DeviceRingMembers
                    Write-Log -Message "Creating a static group [$RingGroupName] with $($GroupParams.Members.Count) members"
                    $ResultObject.StaticMembershipCount = $GroupParams.Members.Count
                }
                if ($DebugMode -eq $false) {
                    $ResultObject.Action = 'Success (Create group)'
                    try {
                        $DUGroup = New-EntraIdGroup @GroupParams
                    }
                    catch {
                        $ResultObject.Action = 'Failure (Create group: {0})' -f $_.Exception.Message
                    }
                }
                else {
                    $ResultObject.Action = 'Audit (Create group)'
                }
            }

            Write-Log -Message "Creating driver update profile [$PolicyName]"
            if ($DebugMode -eq $false) {
                try {
                    $DUProfile = New-DriverUpdateProfile -DisplayName "$PolicyName" -Model $DeviceModel -ScopeTag $ScopeTagList.Id -Include $DUGroup.Id -Ring $Ring -EA Stop
                    $ResultObject.Action = '{0}, Success (Create policy)' -f $ResultObject.Action
                }
                catch {
                    $ResultObject.Action = '{0}, Failure (Create policy: {1})' -f $ResultObject.Action, $_.Exception.Message
                    Write-Log -Message "Failed to create driver update profile [$PolicyName]"
                }
            }
            else {
                $ResultObject.Action = '{0}, Audit (Create policy)' -f $ResultObject.Action
            }
            Write-Log -Message "Done processing ring [$Ring]"
            $null = $ReportResults.Add($ResultObject)
        }
        #endregion creation of groups and profiles
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
        if ($DebugMode) {
            $LogList = $LogList | Where-Object { $_ -like '*-Audit*' }
        }
        else {
            $LogList = $LogList | Where-Object { $_ -notlike '*-Audit*' }
        }
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

    # Disconnect from Graph
    if ($null -ne (Get-MgContext)) {
        try {
            $null = Disconnect-MgGraph -ErrorAction Stop
            Write-Log -Message 'Disconnected from Graph'
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