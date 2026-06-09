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
[string]$scriptAction = '[EntraID] Synchronize user and device groups' # Action name for logging

$Error.Clear()
# Required API permissions
[String[]]$RequiredScopes = @(
    'Device.Read.All'
    'DeviceManagementManagedDevices.Read.All'
    'Group.ReadWrite.All'
    'GroupMember.ReadWrite.All'
    'User.Read.All'
)

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
$ComponentCleanup = "$($AuditFlag)Cleanup"
#endregion Logging/reporting

$PSDefaultParameterValues.Clear()
$Global:PSDefaultParameterValues.Clear()
$Global:PSDefaultParameterValues['Write-Log:CMTrace'] = $true
$Global:PSDefaultParameterValues['Write-Log:Component'] = "$($AuditFlag)$PSScriptName"
$Global:PSDefaultParameterValues['Write-Log:LogFile'] = $LogFile
$Global:PSDefaultParameterValues['Write-Log:DebugMode'] = ($WhatIfPreference -eq $true) -or ($DebugMode -eq $true)

# Main variables used by the script
$ReportResults = New-Object -TypeName System.Collections.ArrayList
$GuidPattern = '^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$' # Used to validate guids

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
        $ConnectParams = @{ ErrorAction = 'Stop' }
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

    # Get the list of source/target groups from the config file
    $GroupList = $ScriptConfig.GroupMembership.Item
    if ($null -eq $GroupList) {
        throw 'No group is listed in the configuration file'
    }
    else {
        Write-Log -Message "The script will process $(($GroupList | Measure-Object).Count) group(s): `r`n$($GroupList | Select-Object SourceGroup,TargetGroup,SourceType,Cleanup | ConvertTo-Json)"
    }

    if (($OperatingSystems.Count -gt 0) -and ($OperatingSystems -notcontains 'All')) {
        [String[]]$IntuneOSFilters = $(
            # startswith does not work on operatingsystem for "devicemanagement/manageddevices" compared to "devices"
            switch -Regex ($OperatingSystems) {
                'Android' { "operatingSystem eq 'Android'" }
                'iOS|iPhone|IPad' { "operatingSystem eq 'iOS'" }
                'Mac' { "operatingSystem eq 'macOS'" }
                'Windows' { "operatingSystem eq '$_'" }
            }
        ) | Select-Object -Unique
        if ($IntuneOSFilters.Count -gt 0) {
            [String]$IntuneGraphFilterString = "($($IntuneOSFilters -join ' or '))"
        }

        [String[]]$EntraOSFilters = $(
            switch ($OperatingSystems) {
                'AllAndroid' { "startswith(operatingsystem, 'Android')" }
                'AlliOS' { "operatingsystem in ('iOS','IPhone','IPad')" }
                'AllMac' { "startswith(operatingsystem, 'mac')" }
                Default { "operatingSystem eq '$_'" }
            }
        ) | Select-Object -Unique
        if ($EntraOSFilters.Count -gt 0) {
            [String]$EntraGraphFilterString = "($($EntraOSFilters -join ' or '))"
        }
    }

    $GRParams = @{
        Resource = 'deviceManagement/manageddevices'
        Select   = 'deviceName','id','userid','userDisplayName','AzureAdDeviceId'
    }
    if ("$IntuneGraphFilterString".Trim() -ne '') {
        $GRParams.Filter = $IntuneGraphFilterString
        Write-Log -Message "Querying Intune devices using a filter [$IntuneGraphFilterString], this can take a few minutes..."
    }
    else {
        Write-Log -Message 'Querying every device in Intune, this can take a few minutes...'
    }
    $IntuneDeviceList = Invoke-MgGraphRequestSingle @GRParams
    Write-Log -Message "Found $(($IntuneDeviceList | Measure-Object).Count) Intune devices"

    :NextGroup foreach ($GroupItem in $GroupList) {
        [String]$SourceGroupName = $SourceGroup = "$($GroupItem.SourceGroup)".Trim()
        [String]$TargetGroupName = $TargetGroup = "$($GroupItem.TargetGroup)".Trim()
        [String]$SourceType = (Get-Culture).TextInfo.ToTitleCase("$($GroupItem.SourceType)".Trim().TrimEnd('s'))
        [bool]$Cleanup = "$($GroupItem.Cleanup)".Trim() -eq 'true'
        $ResultObject = [PSCustomObject]@{
            SourceType       = $SourceType
            SourceGroupId    = ''
            SourceGroupName  = $SourceGroupName
            SourceItemName   = ''
            SourceItemId     = ''
            TargetType       = ''
            TargetGroupId    = ''
            TargetGroupName  = $TargetGroupName
            TargetItemName   = ''
            TargetItemId     = ''
            MembershipStatus = ''
            Status           = ''
        }
        Write-Log -Message "$('=' * 10) Processing: SourceGroup [$SourceGroup] | TargetGroup [$TargetGroup] | SourceType [$SourceType] | Cleanup [$Cleanup]"
        switch ($SourceType) {
            'User' { $TargetType = 'Device'; break }
            'Device' { $TargetType = 'User'; break }
            Default {
                Write-Log -Message "The source type should be either User or Device not [$SourceType]" -Type Error
                $ResultObject.Status = 'Error: Source type mismatch ({0})' -f $SourceType
                $null = $ReportResults.Add($ResultObject)
                continue NextGroup
            }
        }
        $ResultObject.TargetType = $TargetType

        #region source and target group validation
        if (("$SourceGroup" -eq '') -or ("$TargetGroup" -eq '')) {
            Write-Log -Message "One or both groups are empty strings: Source [$SourceGroup] | Target [$TargetGroup]" -Type Error
            $ResultObject.Status = 'Error: Group configuration error'
            $null = $ReportResults.Add($ResultObject)
            continue NextGroup
        }

        # Source group
        if ("$SourceGroup" -match $GuidPattern) {
            Write-Log -Message "Source group id was provided [$SourceGroup]"
            $ResultObject.SourceGroupId = [String]$SourceGroupId = $SourceGroup
            $ResultObject.SourceGroupName = [String]$SourceGroupName = Invoke-MgGraphRequestSingle -Resource "groups/$SourceGroupId" -Select 'displayName' | Select-Object -ExpandProperty displayName
        }
        else {
            Write-Log -Message "Source group name was provided [$SourceGroup], looking for its id"
            $ResultObject.SourceGroupId = [String]$SourceGroupId = Invoke-MgGraphRequestSingle -Resource 'groups' -Filter "displayName eq '$SourceGroup'" -Select 'id' | Select-Object -ExpandProperty id
        }

        if (("$SourceGroupId" -eq '') -or ("$SourceGroupId" -notmatch $GuidPattern) -or ("$SourceGroupName" -eq '')) {
            Write-Log -Message "Could not find the source group: Id [$SourceGroupId] | Name [$SourceGroupName]" -Type Error
            $ResultObject.Status = 'Error: Group configuration error'
            $null = $ReportResults.Add($ResultObject)
            continue NextGroup
        }

        # Target group
        if ("$TargetGroup" -match $GuidPattern) {
            Write-Log -Message "Target group id was provided [$TargetGroup]"
            $ResultObject.TargetGroupId = [String]$TargetGroupId = $TargetGroup
            $ResultObject.TargetGroupName = [String]$TargetGroupName = Invoke-MgGraphRequestSingle -Resource "groups/$TargetGroupId" -Select 'displayName' | Select-Object -ExpandProperty displayName
        }
        else {
            Write-Log -Message "Target group name was provided [$TargetGroup], looking for its id"
            $ResultObject.TargetGroupId = [String]$TargetGroupId = Invoke-MgGraphRequestSingle -Resource 'groups' -Filter "displayName eq '$TargetGroup'" -Select 'id' | Select-Object -ExpandProperty id
            if ("$TargetGroupId" -eq '') {
                Write-Log -Message 'The target group does not exists'
                $TargetGroupDescription = "$TargetType members are synchronized from the $($SourceType.ToLower()) group `"$SourceGroupName`" ($SourceGroupId)"
                $NESGParams = @{
                    DisplayName = $TargetGroup
                    Description = $TargetGroupDescription
                    MemberType  = $TargetType
                    Members     = @()
                }
                $NewGroup = New-EntraIdGroup @NESGParams
                $ResultObject.TargetGroupId = [String]$TargetGroupId = $NewGroup.id
                Write-Log -Message "The target group was created using id [$TargetGroupId]"
            }
            else {
                Write-Log -Message ('The target group already exists ({0})' -f $TargetGroupId)
            }
        }

        if (("$TargetGroupId" -eq '') -or ("$TargetGroupId" -notmatch $GuidPattern) -or ("$TargetGroupName" -eq '')) {
            Write-Log -Message "Could not find the target group: Id [$TargetGroupId] | Name [$TargetGroupName]" -Type Error
            $ResultObject.Status = 'Error: Group configuration error'
            $null = $ReportResults.Add($ResultObject)
            continue NextGroup
        }
        #endregion source and target group validation

        # Get the source group and target group members
        $SourceGroupMembership = Get-EntraIdGroupMembership -Id $SourceGroupId -Type $SourceType -PropertyList 'id', 'displayName', 'deviceid', 'accountEnabled'
        $SourceGroupMembershipCount = ($SourceGroupMembership | Measure-Object).Count
        $TargetGroupMembership = Get-EntraIdGroupMembership -Id $TargetGroupId -Type $TargetType -PropertyList 'id', 'displayName', 'deviceid', 'accountEnabled'
        $TargetGroupMembershipCount = ($TargetGroupMembership | Measure-Object).Count

        # List used for comparing current group members with the new target members and cleanup those that should not be in the group anymore
        $TargetMembers = New-Object -TypeName system.collections.ArrayList
        if ($SourceGroupMembershipCount -eq 0) {
            Write-Log -Message 'The source group is empty' -Type Warning
            $ResultObject.MembershipStatus = 'No member'
            $ResultObject.Status = 'Skipped'
            $null = $ReportResults.Add($ResultObject)
        }
        else {
            switch ($SourceType) {
                #region SourceType=User
                'User' {
                    Write-Log -Message "Listing owned devices in Entra Id for $SourceGroupMembershipCount users, this can take a few minutes..."
                    $GRParams = @{
                        Resource   = 'users'
                        ObjectList = $SourceGroupMembership
                        Query      = '/ownedDevices/microsoft.graph.device'
                        Select     = 'displayName','id','deviceid','accountEnabled'
                        Filter     = @(
                            if ("$EntraGraphFilterString".Trim() -ne '') {
                                $EntraGraphFilterString
                            }
                            #'accountEnabled eq true'
                            #'isManaged eq true'
                            #"deviceOwnership eq 'company'"
                        ) -join ' and '
                        Advanced   = 'ConsistencyLevel','count'
                    }

                    # Get the devices for which the user is a primary user of and add those devices to the target group
                    $EntraOwnedDeviceList = Invoke-MgGraphRequestBatch @GRParams |
                        Select-Object -Property Id,
                        status,
                        @{
                            Label      = 'DeviceList';
                            Expression = {
                                $_.Body.Value | Select-Object -Property 'id', 'displayName', 'deviceid', 'accountEnabled'
                            }
                        }
                    Write-Log -Message "Found $(($EntraOwnedDeviceList | Where-Object {($_.DeviceList | Measure-Object).Count -gt 0} | Measure-Object).Count) user(s) with at least one owned Entra Id device"

                    # List Intune devices linked to the users in the source group
                    # Using a batch for performance concerns, the id of each request is formated using the userId and the AzureAdDeviceId
                    Write-Log -Message "Listing owned devices in Intune for $SourceGroupMembershipCount users, this can take a few minutes..."
                    $IntunePrimaryDeviceBatch = $IntuneDeviceList |
                        Where-Object -Property userid -In $SourceGroupMembership.id |
                        Select-Object -Property AzureAdDeviceId,userid -Unique |
                        Select-Object @{
                            Label      = 'BatchHashtable';
                            Expression = {
                                @{
                                    id     = "$($_.userId)_$($_.AzureAdDeviceId)";
                                    method = 'GET';
                                    url    = "devices?`$select=id,displayName,deviceid,accountenabled&`$filter=deviceid eq '{0}'" -f $_.AzureAdDeviceId
                                }
                            }
                        }

                    if (($IntunePrimaryDeviceBatch | Measure-Object).Count -eq 0) {
                        [Object[]]$IntunePrimaryDevicesList = $null
                    }
                    else {
                        [Object[]]$IntunePrimaryDevicesList = Invoke-MgGraphRequestBatch -Hashtable $IntunePrimaryDeviceBatch.BatchHashtable
                    }
                    Write-Log -Message "Found $(($IntunePrimaryDevicesList | Where-Object {($_.Body.Value | Measure-Object).Count -gt 0} | Measure-Object).Count) devices(s)"
                    $Index = 0
                    # Loop through every users in the source group, look for the linked devices and add these to the target group
                    :NextMember foreach ($SourceItem in $SourceGroupMembership) {
                        $Index++
                        $ResultObject = [PSCustomObject]@{
                            SourceType       = $SourceType
                            SourceGroupId    = $SourceGroupId
                            SourceGroupName  = $SourceGroupName
                            SourceItemName   = $SourceItem.displayName
                            SourceItemId     = $SourceItem.id
                            TargetType       = $TargetType
                            TargetGroupId    = $TargetGroupId
                            TargetGroupName  = $TargetGroupName
                            TargetItemName   = ''
                            TargetItemId     = ''
                            MembershipStatus = ''
                            Status           = ''
                        }
                        $UserLogInfo = '[{0}/{1}][{2} | {3}]' -f $Index, $SourceGroupMembershipCount, $SourceItem.id, $SourceItem.displayName

                        if ($SourceItem.accountEnabled -eq $false) {
                            Write-Log -Message "$UserLogInfo Account is disabled, skipping" -Type Warning
                            $ResultObject.MembershipStatus = 'N/A'
                            $ResultObject.Status = 'Skipped: Source account disabled'
                            $null = $ReportResults.Add($ResultObject)
                            continue NextMember
                        }
                        [Object[]]$EntraOwnedDevices = $EntraOwnedDeviceList | Where-Object -Property id -EQ $SourceItem.Id | Select-Object -ExpandProperty DeviceList
                        [Object[]]$IntunePrimaryDevices = ($IntunePrimaryDevicesList | Where-Object -Property id -Like "$($SourceItem.id)_*").Body.Value
                        Write-Log -Message "$UserLogInfo Owned device(s) found: Entra ID [$(($EntraOwnedDevices | Measure-Object).Count)] | Intune [$(($IntunePrimaryDevices | Measure-Object).Count)]"

                        $PrimaryDeviceList = @($EntraOwnedDevices) + @($IntunePrimaryDevices) | Select-Object -Property id,displayName,accountEnabled -Unique

                        if (($PrimaryDeviceList | Measure-Object).Count -gt 0) {
                            try {
                                Compare-Object -ReferenceObject @($EntraOwnedDevices) -DifferenceObject @($IntunePrimaryDevices) -Property id, displayName -EA Ignore |
                                    Group-Object -Property SideIndicator |
                                    ForEach-Object {
                                        $JSONObject = $_.Group | Select-Object -Property id, displayName | ConvertTo-Json -Compress
                                        switch ($_.Name) {
                                            '=>' { $Type = 'Intune' }
                                            '<=' { $Type = 'Entra' }
                                        }
                                        Write-Log -Message "$UserLogInfo Difference of ownership between Intune and Entra ID. $($_.Count) $Type device(s) are not linked to the user: $JSONObject" -Type Warning
                                    }
                            }
                            catch {
                                if ($_.exception.ErrorId -like '*NullNotAllowed*') {
                                    # ParameterArgumentValidationErrorNullNotAllowed = EntraOwnedDevices or IntunePrimaryDevices  is null
                                    $Error.RemoveAt(0)
                                    Write-Log -Message "$UserLogInfo Difference of ownership between Intune and Entra ID: No device has been found either in Entra or Intune." -Type Warning
                                }
                            }
                        }
                        Write-Log -Message "$UserLogInfo device ownership: $($PrimaryDeviceList | ConvertTo-Json -Compress)"

                        if (($PrimaryDeviceList | Measure-Object).Count -eq 0) {
                            Write-Log -Message "$UserLogInfo No owned device" -Type Warning
                            $ResultObject.MembershipStatus = 'N/A'
                            $ResultObject.Status = 'Skipped: No owned device'
                            $null = $ReportResults.Add($ResultObject)
                            continue NextMember
                        }

                        # Loop through every devices linked to the user
                        :NextDevice foreach ($device in $PrimaryDeviceList) {
                            $ResultObject = [PSCustomObject]@{
                                SourceType       = $SourceType
                                SourceGroupId    = $SourceGroupId
                                SourceGroupName  = $SourceGroupName
                                SourceItemName   = $SourceItem.displayName
                                SourceItemId     = $SourceItem.id
                                TargetType       = $TargetType
                                TargetGroupId    = $TargetGroupId
                                TargetGroupName  = $TargetGroupName
                                TargetItemName   = $device.displayName
                                TargetItemId     = $device.Id
                                MembershipStatus = ''
                                Status           = ''
                            }
                            $DeviceLogInfo = '[{0} | {1}]' -f $Device.id, $Device.displayName

                            if ($device.accountEnabled -eq $false) {
                                Write-Log -Message "$DeviceLogInfo Account is disabled, skipping" -Type Warning
                                $ResultObject.MembershipStatus = 'N/A'
                                $ResultObject.Status = 'Skipped: Target account disabled'
                                $null = $ReportResults.Add($ResultObject)
                                continue NextDevice
                            }

                            if (($device.Id -in $TargetGroupMembership.id) -or ($TargetMembers.id -contains $Device.id)) {
                                Write-Log -Message "$UserLogInfo The device $DeviceLogInfo is already a member of [$TargetGroupName] ($TargetGroupId)"
                                $ResultObject.MembershipStatus = 'Existing member'
                                $ResultObject.Status = 'Skipped'
                                if ($TargetMembers.id -contains $Device.id) {
                                    $null = $ReportResults.Add($ResultObject)
                                    continue NextUser
                                }
                                $null = $TargetMembers.Add($device)
                            }
                            else {
                                $ResultObject.MembershipStatus = 'Missing member'
                                try {
                                    $null = $TargetMembers.Add($device)
                                    if ($DebugMode -eq $false) {
                                        $Body = @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/directoryObjects/{0}' -f $device.id }
                                        Invoke-MgGraphRequestSingle -Resource ('groups/{0}/members/$ref' -f $TargetGroupId) -Method 'POST' -Body $Body -ErrorAction Stop
                                        $ResultObject.Status = 'Success'
                                    }
                                    else {
                                        $ResultObject.Status = 'Audit'
                                    }
                                }
                                catch {
                                    $ResultObject.Status = "Error: Failed to add the member. $($_.Exception.Message)"
                                }
                                Write-Log -Message "$UserLogInfo Adding the device $DeviceLogInfo to the group [$TargetGroupName] ($TargetGroupId)"
                            }
                            $null = $ReportResults.Add($ResultObject)
                        }
                    }
                    break
                }
                #endregion SourceType=User
                #region SourceType=Device
                'Device' {
                    # Get the primary users of the devices and add those users to the target group
                    Write-Log -Message "Listing every primary users in Entra Id for $SourceGroupMembershipCount devices, this can take a few minutes..."
                    $GRParams = @{
                        Resource   = 'devices'
                        ObjectList = $SourceGroupMembership
                        Query      = '/registeredOwners/microsoft.graph.user'
                        Select     = 'id','displayName','accountenabled'
                    }

                    $EntraOwnerList = Invoke-MgGraphRequestBatch @GRParams |
                        Select-Object -Property Id,
                        status,
                        @{
                            Label      = 'UserList';
                            Expression = {
                                $_.Body.Value
                            }
                        }
                    Write-Log -Message "Found $(($EntraOwnerList | Where-Object {($_.UserList | Measure-Object).Count -gt 0} | Measure-Object).Count) Entra ID devices with at least one owner assigned"

                    $IntunePrimaryUserBatch = $IntuneDeviceList |
                        Where-Object -Property AzureAdDeviceId -In $SourceGroupMembership.deviceid |
                        Where-Object -Property userid -NE '' |
                        Select-Object -ExpandProperty userid -Unique |
                        Select-Object -Property @{
                            Label      = 'BatchHashtable'
                            Expression = {
                                @{
                                    id     = $_
                                    method = 'GET'
                                    url    = 'users/{0}?$Select=accountEnabled' -f $_
                                }
                            }
                        }

                    if (($IntunePrimaryUserBatch | Measure-Object).Count -eq 0) {
                        [Object[]]$IntunePUEnabledList = $null
                    }
                    else {
                        [Object[]]$IntunePUEnabledList = Invoke-MgGraphRequestBatch -Hashtable $IntunePrimaryUserBatch.BatchHashtable |
                            Select-Object -Property id,
                            @{
                                Label      = 'accountEnabled';
                                Expression = {
                                    $AE = $_.Body.accountEnabled
                                    if ($null -eq $AE) { $true } # If the request fails, set accountEnabled to $true to avoid errors
                                    else { $AE }
                                }
                            }
                    }

                    $Index = 0
                    # Loop through every devices in the source group, look for the linked users and add these to the target group
                    :NextMember foreach ($SourceItem in $SourceGroupMembership) {
                        $Index++
                        $ResultObject = [PSCustomObject]@{
                            SourceType       = $SourceType
                            SourceGroupId    = $SourceGroupId
                            SourceGroupName  = $SourceGroupName
                            SourceItemName   = $SourceItem.displayName
                            SourceItemId     = $SourceItem.id
                            TargetType       = $TargetType
                            TargetGroupId    = $TargetGroupId
                            TargetGroupName  = $TargetGroupName
                            TargetItemName   = ''
                            TargetItemId     = ''
                            MembershipStatus = ''
                            Status           = ''
                        }
                        $DeviceLogInfo = '[{0}/{1}][{2} | {3}]' -f $Index, $SourceGroupMembershipCount, $SourceItem.id, $SourceItem.displayName

                        if ($SourceItem.accountEnabled -eq $false) {
                            Write-Log -Message "$DeviceLogInfo Account is disabled, skipping" -Type Warning
                            $ResultObject.MembershipStatus = 'N/A'
                            $ResultObject.Status = 'Skipped: Source account disabled'
                            $null = $ReportResults.Add($ResultObject)
                            continue NextMember
                        }

                        $IntunePrimaryUsers = $IntuneDeviceList |
                            Where-Object -Property AzureAdDeviceId -EQ $SourceItem.deviceid |
                            Where-Object -Property userid -NE '' |
                            Select-Object -Property @{Label = 'displayName'; Expression = { $_.userDisplayName } },
                            @{Label = 'id'; Expression = { $_.userid } },
                            @{Label = 'accountEnabled'; Expression = { ($IntunePUEnabledList | Where-Object -Property Id -EQ $_.userId).accountEnabled } }

                        $EntraOwner = $EntraOwnerList | Where-Object -Property Id -EQ $SourceItem.Id | Select-Object -ExpandProperty UserList
                        Write-Log -Message "$DeviceLogInfo Owner(s) found: Entra ID [$(($EntraOwner | Measure-Object).Count)] | Intune [$(($IntunePrimaryUsers | Measure-Object).Count)]"

                        $PrimaryUserList = @($EntraOwner) + @($IntunePrimaryUsers) | Select-Object -Property id,displayName,accountEnabled -Unique

                        if (($PrimaryUserList | Measure-Object).Count -gt 0) {
                            try {
                                Compare-Object -ReferenceObject @($EntraOwner) -DifferenceObject @($IntunePrimaryUsers) -Property id, displayName -EA Ignore |
                                    Group-Object -Property SideIndicator |
                                    ForEach-Object {
                                        $JSONObject = $_.Group | Select-Object -Property id, displayName | ConvertTo-Json -Compress
                                        switch ($_.Name) {
                                            '=>' { $Type = 'Intune' }
                                            '<=' { $Type = 'Entra' }
                                        }
                                        Write-Log -Message "$DeviceLogInfo Difference of ownership between Intune and Entra ID. $($_.Count) user(s) are not linked to the $Type device: $JSONObject" -Type Warning
                                    }
                            }
                            catch {
                                if ($_.exception.ErrorId -like '*NullNotAllowed*') {
                                    # ParameterArgumentValidationErrorNullNotAllowed = EntraOwnedDevices or IntunePrimaryDevices  is null
                                    $Error.RemoveAt(0)
                                    Write-Log -Message "$DeviceLogInfo Difference of ownership between Intune and Entra ID." -Type Warning
                                }
                            }
                        }
                        Write-Log -Message "$DeviceLogInfo device owner(s): $($PrimaryUserList | ConvertTo-Json -Compress)"

                        if (($PrimaryUserList | Measure-Object).Count -eq 0) {
                            Write-Log -Message "$DeviceLogInfo No primary user" -Type Warning
                            $ResultObject.MembershipStatus = 'N/A'
                            $ResultObject.Status = 'Skipped: No primary user'
                            $null = $ReportResults.Add($ResultObject)
                            continue NextMember
                        }

                        # Loop through every users linked to the device
                        :NextUser foreach ($User in $PrimaryUserList) {
                            $ResultObject = [PSCustomObject]@{
                                SourceType       = $SourceType
                                SourceGroupId    = $SourceGroupId
                                SourceGroupName  = $SourceGroupName
                                SourceItemName   = $SourceItem.displayName
                                SourceItemId     = $SourceItem.id
                                TargetType       = $TargetType
                                TargetGroupId    = $TargetGroupId
                                TargetGroupName  = $TargetGroupName
                                TargetItemName   = $User.displayName
                                TargetItemId     = $User.Id
                                MembershipStatus = ''
                                Status           = ''
                            }
                            $UserLogInfo = '[{0} | {1}]' -f $User.id, $User.displayName

                            if ($User.accountEnabled -eq $false) {
                                Write-Log -Message "$UserLogInfo Account is disabled, skipping" -Type Warning
                                $ResultObject.MembershipStatus = 'N/A'
                                $ResultObject.Status = 'Skipped: Target account disabled'
                                $null = $ReportResults.Add($ResultObject)
                                continue NextUser
                            }

                            if ($User.displayName -like 'package_*') {
                                # When a device is enrolled using a DEM account, a "package_..." user is created and linked to the device
                                Write-Log -Message "$DeviceLogInfo Device owner $UserLogInfo is a result of an DEM account enrollment, skipping" -Type Warning
                                $ResultObject.MembershipStatus = 'N/A'
                                $ResultObject.Status = 'Skipped: DEM account'
                                $null = $ReportResults.Add($ResultObject)
                                continue NextUser
                            }
                            elseif (($User.Id -in $TargetGroupMembership.id) -or ($TargetMembers.id -contains $User.id)) {
                                Write-Log -Message "$DeviceLogInfo Device owner $UserLogInfo is already a member of [$TargetGroupName] ($TargetGroupId)"
                                $ResultObject.MembershipStatus = 'Existing member'
                                $ResultObject.Status = 'Skipped'
                                if ($TargetMembers.id -contains $User.id) {
                                    $null = $ReportResults.Add($ResultObject)
                                    continue NextUser
                                }
                                $null = $TargetMembers.Add($User)
                            }
                            else {
                                $ResultObject.MembershipStatus = 'Missing member'
                                try {
                                    $null = $TargetMembers.Add($User)
                                    if ($DebugMode -eq $false) {
                                        $Body = @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/directoryObjects/{0}' -f $User.id }
                                        Invoke-MgGraphRequestSingle -Resource ('groups/{0}/members/$ref' -f $TargetGroupId) -Method 'POST' -Body $Body -ErrorAction Stop
                                        $ResultObject.Status = 'Success'
                                    }
                                    else {
                                        $ResultObject.Status = 'Audit'
                                    }
                                }
                                catch {
                                    $ResultObject.Status = "Error: Failed to add the member. $($_.Exception.Message)"
                                }
                                Write-Log -Message "$DeviceLogInfo Adding the user $UserLogInfo to the group [$TargetGroupName] ($TargetGroupId)"
                            }
                            $null = $ReportResults.Add($ResultObject)
                        }
                    }
                    break
                }
                #endregion SourceType=Device
            }
        }

        #region cleanup
        # Remove the extra members if Cleanup is enabled
        $TargetMembers = $TargetMembers | Select-Object -Unique id,displayname
        if (($TargetGroupMembershipCount -gt 0) -and ($TargetMembers.Count -gt 0)) {
            $RemoveIDList = Compare-Object -ReferenceObject @($TargetGroupMembership) -DifferenceObject @($TargetMembers) -Property Id -EA Ignore |
                Where-Object -Property SideIndicator -EQ '<=' |
                Select-Object -Property Id,
                @{
                    Label      = 'BatchHashtable';
                    Expression = {
                        @{
                            id     = $_.id
                            method = 'DELETE'
                            url    = 'groups/{0}/members/{1}/$ref' -f $TargetGroupId, $_.id
                        }
                    }
                }
        }
        if (($RemoveIDList | Measure-Object).Count -eq 0) {
            Write-Log -Message 'No member needs to be removed from the target group' -Component $ComponentCleanup -Type Warning
            continue NextGroup
        }

        if (($Cleanup -eq $true) -and ($DebugMode -eq $false)) {
            # Use batching to remove the extra members from the target group and add the item's displayName to the results
            try {
                $CleanupResults = Invoke-MgGraphRequestBatch -Hashtable $RemoveIDList.BatchHashtable -EA Stop |
                    Select-Object *,
                    @{Label = 'displayName'; Expression = { $TargetGroupMembership | Where-Object -Property id -EQ $_.id | Select-Object -ExpandProperty displayName } }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $CleanupResults = $RemoveIDList | Select-Object id, @{Label = 'Status'; Expression = { 400 } }, @{Label = 'Error'; Expression = { $ErrorMessage } }
            }
            finally {
                $DeletionSuccess = $CleanupResults | Where-Object -Property Status -EQ 204
                $DeletionFailure = $CleanupResults | Where-Object -Property Status -NE 204
            }
            if (($DeletionFailure | Measure-Object).Count -gt 0) {
                Write-Log -Message "Failed to remove $(($DeletionFailure | Measure-Object).Count) members from the target group.`r`n$($DeletionFailure.id -join "`r`n")" -Type 'Error' -Component $ComponentCleanup
            }
            else {
                Write-Log -Message "Successfuly removed $(($DeletionSuccess | Measure-Object).Count) members from the target group." -Component $ComponentCleanup
            }
        }
        else {
            Write-Log -Message "Cleanup is disabled (Debug: $DebugMode)" -Component $ComponentCleanup
            $CleanupResults = $RemoveIDList |
                Select-Object -Property id,
                @{Label = 'displayName'; Expression = { $TargetGroupMembership | Where-Object -Property id -EQ $_.id | Select-Object -ExpandProperty displayName } }
        }

        foreach ($Item in $CleanupResults) {
            if (($Cleanup -eq $true) -and ($DebugMode -eq $false)) {
                $Status = 'Removed'
                if ($Item.Status -ne 204) {
                    $Status = 'Error (Remove): {0}' -f $item.Error
                }
            }
            elseif ($DebugMode -eq $false) {
                $Status = 'Skipped: Remove (Cleanup=false)'
            }
            else {
                $Status = 'Skipped: Remove (Debug)'
            }
            Write-Log -Message "[Cleanup] Remove [$($Item.displayName)] ($($Item.Id)) from the target group [$TargetGroupId]: $Status" -Component $ComponentCleanup

            $null = $ReportResults.Add([PSCustomObject]@{
                    SourceType       = $SourceType
                    SourceGroupId    = $SourceGroupId
                    SourceGroupName  = $SourceGroupName
                    SourceItemName   = ''
                    SourceItemId     = ''
                    TargetType       = $TargetType
                    TargetGroupId    = $TargetGroupId
                    TargetGroupName  = $TargetGroupName
                    TargetItemName   = $Item.displayName
                    TargetItemId     = $Item.Id
                    MembershipStatus = 'Extra member'
                    Status           = $Status
                })
        }
        #endregion cleanup
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

    # End script and report memory usage
    $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
    $MemoryUsageAfter = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
    Write-Log -Message "Script finished. Memory usage: $MemoryUsage MB ($MemoryUsageAfter MB after cleanup)"
    Write-Log -Message ('=' * 80)
    $PSDefaultParameterValues.Clear()
}
#endregion main