#Requires -module ImportExcel

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [String]$Destination,

    [Parameter(Position = 1)]
    [ValidateSet('IntuneAssignments','IntuneRBAC','IntuneScopeTags','AdministrativeUnits')]
    [String[]]$AdditionalTable
)

$Select = @(
    'id'
    'displayName'
    'description'
    'groupTypes'
    'membershipRule'
    'membershipRuleProcessingState'
    'createdDateTime'
    'isAssignableToRole'
    'securityEnabled'
    'onPremisesSyncEnabled'
    'writebackConfiguration' # Only works in beta
    'onPremisesDomainName'
    'mailEnabled'
    'mail'
)

<# $AnalyticsSelect = @(
    'assignedRoleCount' #long assignedRoleCount=0
    #'calculatedDateTime' #datetime calculatedDateTime=4/25/2026 12:00:00 AM
    #'createdDateTime' #datetime createdDateTime=11/21/2019 11:10:06 PM
    'directGroupMemberCount' #long directGroupMemberCount=0
    'dynamicMembershipType' #string dynamicMembershipType=
    'groupExpirationDateTime' #datetime groupExpirationDateTime=1/1/0001 12:00:00 AM
    #'groupType' #string groupType=isCloudGroup
    'guestOwnerCount' #long guestOwnerCount=0
    'guestTransitiveUserCount' #long guestTransitiveUserCount=0
    'id' #string id=17d1420b-bd8e-4e98-b9d1-ec48453d8faf
    #'isCloudDistributionListGroup' #bool isCloudDistributionListGroup=False
    #'isCloudM365Group' #bool isCloudM365Group=True
    #'isCloudMailEnabledSecurityGroup' #bool isCloudMailEnabledSecurityGroup=False
    #'isCloudSecurityGroup' #bool isCloudSecurityGroup=False
    #'isDynamicGroup' #bool isDynamicGroup=False
    #'isOnPremiseDistributionListGroup' #bool isOnPremiseDistributionListGroup=False
    #'isOnPremiseMailEnabledSecurityGroup' # isOnPremiseMailEnabledSecurityGroup=False
    #'isOnPremiseSecurityGroup' #bool isOnPremiseSecurityGroup=False
    'isValidGroup' #bool isValidGroup=True
    #'lastRestorationDateTime' #datetime lastRestorationDateTime=1/1/0001 12:00:00 AM
    'memberOwnerCount' #long memberOwnerCount=1
    'membershipRuleContainsCount' #long membershipRuleContainsCount=0
    'membershipRuleExpressionCount' #long membershipRuleExpressionCount=0
    'membershipRuleMatchCount' #long membershipRuleMatchCount=0
    'membershipRuleMemberOfCount' #long membershipRuleMemberOfCount=0
    'membershipRuleProcessingState' #string membershipRuleProcessingState=
    'memberTransitiveUserCount' #long memberTransitiveUserCount=3
    #'preferredDataLocation' #string preferredDataLocation=
    'sensitivityLabelCount' #long sensitivityLabelCount=0
    'servicePrincipalOwnerCount' #long servicePrincipalOwnerCount=0
    'softDeletionDateTime' #datetime softDeletionDateTime=1/1/0001 12:00:00 AM
    #'tenantId' #string tenantId=fffad414-b6a3-4f32-a9bd-42d28fc811f1
    'transitiveServicePrincipalCount' #long transitiveServicePrincipalCount=0
    'transitiveUserCount' #long transitiveUserCount=3
) #>

#$TestKeyWords = '\bTest','\bPilot\b'
[String[]]$TestKeyWords = 'Test' ,'Pilot'
[String[]]$ExcludeTestKeyWords = 'autopilot'
$TestFormula = ''
if ($TestKeyWords.Count -gt 0) {
    if ($TestKeyWords.Count -eq 1) {
        $TestFormula = 'IFERROR(FIND("{0}",[Name]),0) > 0' -f "$TestKeyWords"
    }
    elseif ($TestKeyWords.Count -gt 1) {
        $TestFormula = 'OR({0})' -f ($TestKeyWords.foreach({ 'IFERROR(FIND("{0}",[Name]),0) > 0' -f $_ }) -join ',')
    }
    if ($ExcludeTestKeyWords.Count -eq 1) {
        $TestFormula = '=AND(IFERROR(FIND("{0}",[Name]),0) = 0,{1})' -f "$ExcludeTestKeyWords", $TestFormula
    }
    elseif ($ExcludeTestKeyWords.Count -gt 1) {
        $TestFormula = '=AND({0},{1})' -f ($ExcludeTestKeyWords.foreach({ 'IFERROR(FIND("{0}",[Name]),0) = 0' -f $_ }) -join ','),$TestFormula
    }
    else {
        $TestFormula = "=$TestFormula"
    }
}

$ExcelParams = @{
    Path               = "$Destination\EntraIdGroups-$(Get-Date -Format 'yyyyMMdd_HHmm').xlsx"
    TableStyle         = 'Medium2'
    AutoSize           = $true
    NoNumberConversion = 'createdDateTime'
    #Numberformat       = 'Text'
}

<# $PivotParams = @{
    PivotTableName = 'Statistics'
    PivotRows      = 'Membership','Type'
    PivotColumns   = 'To be reviewed'
    #PivotColumns       = 'isAssignableToRole','TestGroup'
    PivotData      = 'id'
    #PivotFilter        = 'Type','MembershipType'
} #>

$GroupList = Invoke-MgGraphRequestSingle -Resource 'groups' -Select $Select -APIVersion 'beta'
#$Analytics = Invoke-MgGraphRequestSingle -Resource 'reports/identityAnalytics/groups' -APIVersion beta -Select $AnalyticsSelect | Convert-PSObjectArrayToHashTable -idProperty id

$GroupHash = $GroupList | Convert-PSObjectArrayToHashTable -idProperty id -Property 'displayName'

$MemberOwnerCountBatch = Invoke-MgGraphRequestBatch -Hashtable $(
    foreach ($Gid in $GroupList.id) {
        @{
            id      = '{0}_members' -f $Gid
            method  = 'GET'
            url     = 'groups/{0}/members/$count' -f $Gid
            headers = @{'ConsistencyLevel' = 'eventual' }
        }
        @{
            id      = '{0}_owners' -f $Gid
            method  = 'GET'
            url     = 'groups/{0}/owners/$count' -f $Gid
            headers = @{'ConsistencyLevel' = 'eventual' }
        }
    }
) | Convert-PSObjectArrayToHashTable -idProperty id

$UsedGroups = $GroupList | Where-Object { $MemberOwnerCountBatch["$($_.id)_members"].body -gt 0 }
if (($UsedGroups | Measure-Object).Count -gt 0) {
    # M365 or distribution groups only contain users
    [String[]]$UsedUserGroupsId = $UsedGroups | Where-Object { ($_.groupTypes -contains 'Unified') -or ($_.mailEnabled -eq $true) } | Select-Object -ExpandProperty id
    # Dynamic groups don't usually have nested groups unless their membership rule contains group.objectid
    # However, their members are not considered as groups
    [String[]]$UsedAssignedGroupsId = $UsedGroups | Where-Object -Property mailEnabled -NE $true | Where-Object -Property groupTypes -NotContains 'DynamicMembership' | Select-Object -ExpandProperty id
    $BatchHashTable = $(
        foreach ($Gid in $UsedGroups.id) {
            @{
                id      = '{0}_UsersCount' -f $Gid
                method  = 'GET'
                url     = 'groups/{0}/members/microsoft.graph.user/$count' -f $Gid
                headers = @{'ConsistencyLevel' = 'eventual' }
            }
            if ($Gid -notin $UsedUserGroupsId) {
                #Non M365/distribution groups
                @{
                    id      = '{0}_DevicesCount' -f $Gid
                    method  = 'GET'
                    url     = 'groups/{0}/members/microsoft.graph.device/$count' -f $Gid
                    headers = @{'ConsistencyLevel' = 'eventual' }
                }
                if ($Gid -in $UsedAssignedGroupsId) {
                    @{
                        id      = '{0}_GroupsCount' -f $Gid
                        method  = 'GET'
                        url     = 'groups/{0}/members/microsoft.graph.group/$count' -f $Gid
                        headers = @{'ConsistencyLevel' = 'eventual' }
                    }
                    @{
                        id     = '{0}_NestedGroups' -f $Gid
                        method = 'GET'
                        url    = 'groups/{0}/members/microsoft.graph.group?$select=id,displayName' -f $Gid
                    }
                }
            }
        }
    )
    $MembersBatch = Invoke-MgGraphRequestBatch -Hashtable $BatchHashTable -DoNotLogErrors | Convert-PSObjectArrayToHashTable -idProperty id
}
$UsedGroups = $UsedUserGroupsId = $UsedAssignedGroupsId = $null

$DynamicNestedHashId = @{}
$DynamicNestedHashName = @{}
$GroupList |
    Where-Object -Property groupTypes -Contains 'DynamicMembership' |
    Where-Object -Property membershipRule -Match 'group\.objectid' |
    ForEach-Object {
        $Name = $_.displayName
        # Split the membershipRule using " and keep only the strings that match a guid
        # Ex: user.memberOf -any (group.objectId -in ["11111111-2222-3333-4444-555555555555", "22222222-2222-3333-4444-555555555555"]) => 11111111-2222-3333-4444-555555555555 and 22222222-2222-3333-4444-555555555555
        $DynamicNestedHashName["$Name"] = New-Object -TypeName 'System.Collections.Generic.List[String]'
        # Remove line breaks + split the string using either " or '
        ("$($_.membershipRule)".Replace("`r`n", '').Replace("`n",' ') -split "[`"']").where({ $_ -match '\w{8}-\w{4}-\w{4}-\w{4}-\w{12}' }).foreach({
                if ($null -eq $DynamicNestedHashId["$_"]) {
                    $DynamicNestedHashId["$_"] = New-Object -TypeName 'System.Collections.Generic.List[String]'
                }
                $DynamicNestedHashName["$Name"].Add("$($GroupHash[$_])")
                $DynamicNestedHashId["$_"].Add($Name)
            })
    }

$AssignedNestedHashId = @{}
$AssignedNestedHashName = @{}
$MembersBatch.values | 
    Where-Object -Property id -Like '*_NestedGroups' |
    ForEach-Object {
        if ($null -ne $_.body.value.id) {
            [String]$id = $_.id -split '_' | Select-Object -First 1
            $Name = $GroupHash["$id"]
            $AssignedNestedHashName["$Name"] = New-Object -TypeName 'System.Collections.Generic.List[String]'
            ($_.body.value).foreach(
                {
                    if ($null -eq $_.error) {
                        [String]$NGId = $_.id
                        if ($null -eq $AssignedNestedHashId["$NGId"]) {
                            $AssignedNestedHashId[$NGId] = New-Object -TypeName 'System.Collections.Generic.List[String]'
                        }
                        $AssignedNestedHashName["$Name"].Add("$($_.displayName)")
                        $AssignedNestedHashId[$NGId].Add($Name)
                    }
                }
            )
        }
    }

#region all group
$GroupList |
    Select-Object id,
    @{Label = 'Name'; expression = { "$($_.displayName)" -replace '^=',"'=" } },
    @{Label = 'Description'; expression = { "$($_.description)" -replace '^=',"'=" } },
    @{
        Label      = 'Type'
        Expression = {
            if ($_.groupTypes -contains 'Unified') {
                'Microsoft 365'
            }
            elseif (($_.securityEnabled -eq $true) -and ($_.mailEnabled -eq $true)) {
                'Mail enabled security'
            }
            elseif ($_.securityEnabled -eq $true) {
                'Security'
            }
            elseif ($_.mailEnabled -eq $true) {
                'Distribution'
            }
        }
    },
    @{
        Label      = 'Membership'
        expression = {
            if (($_.groupTypes -contains 'DynamicMembership')) {
                'Dynamic'
            }
            else {
                'Assigned'
            }
        }
    },
    @{
        Label      = 'Source'
        expression = {
            if ($_.onPremisesSyncEnabled -eq $true) {
                'Windows Server AD'
            }
            else {
                'Cloud'
            }
        }
    },
    @{
        Label      = 'Test group'
        expression = {
            $TestFormula
            #(@($_.DisplayName -split '[\W_]+') + @($_.Description -split '[\W_]+') | Select-String -Pattern $TestKeyWords -Quiet) -eq $true
        }
    },
    @{
        Label      = 'Members'
        expression = {
            [uint32]$MemberOwnerCountBatch["$($_.id)_members"].body
        }
    },
    @{
        Label      = 'Devices'
        expression = {
            [uint32]$MembersBatch["$($_.id)_DevicesCount"].body
        }
    },
    @{
        Label      = 'Users'
        expression = {
            [uint32]$MembersBatch["$($_.id)_UsersCount"].body
        }
    },
    @{
        Label      = 'Groups'
        expression = {
            [uint32]$MembersBatch["$($_.id)_GroupsCount"].body
        }
    },
    @{
        Label      = 'Others'
        expression = {
            '=[Members]-[Devices]-[Users]-[Groups]'
        }
    },
    @{
        Label      = 'Owners'
        expression = {
            [uint32]$MemberOwnerCountBatch["$($_.id)_owners"].body
        }
    },
    @{
        Label      = 'To be reviewed'
        expression = {
            if ($MemberOwnerCountBatch.Count -gt 0) { '=OR([Test group]=TRUE,[Members]=0,AND([Devices]>0,[Users]>0))' }
            else { '=[Test group]=TRUE' }
        }
    },
    @{
        Label      = 'Created on'
        expression = { $_.createdDateTime }
    },
    @{
        Label      = 'Security enabled'
        expression = { $_.securityEnabled }
    },
    @{
        Label      = 'Role assignable'
        expression = {
            if ($_.isAssignableToRole -eq $true) { $true }
            else { $false }
        }
    },
    @{
        Label      = 'On-prem sync enabled'
        expression = {
            if ($_.onPremisesSyncEnabled -eq $true) { $true }
            else { $false }
        }
    },
    @{
        Label      = 'On-prem domain'
        expression = { $_.onPremisesDomainName }
    },
    @{
        Label      = 'Writeback enabled'
        expression = {
            if ($_.writebackConfiguration.isEnabled -eq $true) { $true }
            else { $false }
        }
    },
    @{
        Label      = 'Nested in'
        expression = {
            $(
                ($DynamicNestedHashId["$($_.id)"])
                ($AssignedNestedHashId["$($_.id)"])
            ).where({ "$_" -ne '' }) -join "`r`n"
        }
    },
    @{
        Label      = 'Nested groups'
        expression = {
            $(
                ($DynamicNestedHashName["$($_.displayName)"])
                ($AssignedNestedHashName["$($_.displayName)"])
            ).where({ "$_" -ne '' }) -join "`r`n"
        }
    },
    @{Label = 'OnPremisesGroupType'; expression = { [String]$_.writebackConfiguration.onPremisesGroupType } },
    @{
        Label      = 'Mail enabled'
        expression = { $_.mailEnabled }
    },
    @{
        Label      = 'Mail'
        expression = { "$($_.mail)" }
    },
    @{
        Label      = 'In use'
        expression = {
            '=OR([Used for Intune Policy] <> "",[Used for Intune Roles] <> "",[Used for Intune ScopeTag]<>"",[Used for Administrative units]<>"")'
        }
    },
    @{
        Label      = 'Used for Intune Policy'
        Expression = {
            if ($AdditionalTable -contains 'IntuneAssignments') {
                '=TEXTJOIN(CHAR(10), TRUE, SORT(FILTER(IntuneAssignments[displayName], IntuneAssignments[AssignmentTarget]=[Name],"")))'
            }
            else { '' }
        }
    },
    @{
        Label      = 'Used for Intune Roles'
        Expression = {
            if ($AdditionalTable -contains 'IntuneRBAC') {
                '=TEXTJOIN(CHAR(10), TRUE, SORT(FILTER(IntuneRBAC[RoleName], IntuneRBAC[AssignmentTargetName]=[Name],"")))'
            }
            else { '' }
        }
    },
    @{
        Label      = 'Used for Intune ScopeTag'
        Expression = {
            if ($AdditionalTable -contains 'IntuneScopeTags') {
                '=TEXTJOIN(CHAR(10), TRUE, SORT(FILTER(IntuneScopeTags[displayName], IntuneScopeTags[AssignmentTargetName]=[Name],"")))'
            }
            else {
                ''
            }
        }
    },
    @{
        Label      = 'Used for Administrative units'
        Expression = {
            if ($AdditionalTable -contains 'AdministrativeUnits') {
                '' #TODO
            }
            else {
                ''
            }
        }
    } |
    Export-Excel -WorksheetName 'All groups' -TableName 'AllGroups' @ExcelParams

$MemberOwnerCountBatch.Clear()
$MembersBatch.Clear()
#endregion all groups


#region dynamic groups
$GroupList |
    Where-Object -Property GroupTypes -Contains 'DynamicMembership' |
    Select-Object -Property id,
    @{Label = 'Name'; Expression = { $_.displayName } },
    @{Label = 'Membership rule'; Expression = { $_.membershiprule } },
    @{
        Label      = 'Processing state'
        expression = {
            if ("$($_.membershipRuleProcessingState)" -ne '') { [String]$_.membershipRuleProcessingState }
            else { 'Off' }
        }
    },
    @{
        Label      = 'Uses group.objectid'
        expression = {
            "$($_.membershiprule)" -match 'group\.objectid'
        }
    },
    @{
        Label      = 'Nested group'
        expression = {
            ($DynamicNestedHashName["$($_.displayName)"]).where({ "$_" -ne '' }) -join "`r`n"
        }
    },
    @{
        Label      = 'ext1'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute1' { 'device' }
                    'user.extensionAttribute1' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext2'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute2' { 'device' }
                    'user.extensionAttribute2' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext3'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute3' { 'device' }
                    'user.extensionAttribute3' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext4'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute4' { 'device' }
                    'user.extensionAttribute4' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext5'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute5' { 'device' }
                    'user.extensionAttribute5' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext6'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute6' { 'device' }
                    'user.extensionAttribute6' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext7'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute7' { 'device' }
                    'user.extensionAttribute7' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext8'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute8' { 'device' }
                    'user.extensionAttribute8' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext9'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute9' { 'device' }
                    'user.extensionAttribute9' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext10'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute10' { 'device' }
                    'user.extensionAttribute10' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext11'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute11' { 'device' }
                    'user.extensionAttribute11' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext12'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute12' { 'device' }
                    'user.extensionAttribute12' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext13'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute13' { 'device' }
                    'user.extensionAttribute13' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext14'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute14' { 'device' }
                    'user.extensionAttribute14' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'ext15'
        expression = {
            $(switch -Regex ($_.membershiprule) {
                    'device.extensionAttribute15' { 'device' }
                    'user.extensionAttribute15' { 'user' }
                    default { '' }
                }) -join ','
        }
    },
    @{
        Label      = 'Autopilot'
        expression = { "$($_.membershiprule)" -match '\[(OrderId|ZTDID)\]' }
    },
    @{
        Label      = 'GroupTag'
        expression = { "$($_.membershiprule)" -replace '\[OrderId\]:([^"]+)', '$1' }
    },
    @{
        Label      = 'UserProperties'
        expression = {
            $(($_.membershiprule -split '\s+').Where({ $_ -match '\buser\.(\w+)' -and ($_ -notmatch 'extensionAttribute') }).foreach({ "$_" -replace '.*user\.' }) | Sort-Object -Unique) -join ', '
        }
    },
    @{
        Label      = 'DeviceProperties'
        expression = {
            $(($_.membershiprule -split '\s+').Where({ $_ -match '\bdevice\.(\w+)' -and ($_ -notmatch 'extensionAttribute') }).foreach({ "$_" -replace '.*device\.' }) | Sort-Object -Unique) -join ', '
        }
    } |
    Export-Excel -WorksheetName 'Dynamic groups' -TableName 'DynamicGroups' @ExcelParams

$DynamicNestedHashId.Clear()
$DynamicNestedHashName.Clear()
#endregion dynamic group

#region additional tables
if ($AdditionalTable.Count -gt 0) {
    $ScopeTagList = Get-IntuneScopeTag -EA continue
}
switch ($AdditionalTable) {
    'IntuneAssignments' {
        Get-IntuneAssignment |
            Select-Object -Property Category,
            SubCategory,
            type,
            Platform,
            status,
            id,
            displayName,
            lastModifiedDateTime,
            @{
                Label      = 'ScopeTags'
                Expression = {
                    if ($ScopeTagList) {
                        ($ScopeTagList | Where-Object -Property id -In $_.ScopeTags).displayName -join ','
                    }
                    else {
                        $_.ScopeTags -join ','
                    }
                }
            },
            AssignmentMemberCount,
            AssignmentIntent,
            AssignmentType,
            AssignmentTargetType,
            AssignmentTarget,
            AssignmentTargetid,
            AssignmentFilterType,
            AssignmentFilter |
            Export-Excel -WorksheetName 'Intune assignments' -TableName $_ @ExcelParams
    }
    'IntuneRBAC' {
        Get-IntuneRBACRole | ForEach-Object {
            $Role = $_
            <#
            $RoleScopeTags = $Role.RoleScopeTags
            if ($ScopeTagList) {
                $RoleScopeTags = $ScopeTagList | Where-Object -Property id -in $RoleScopeTags.id | Select-Object -ExpandProperty displayName
            }
            #>
            @($Role.AssignmentScopeGroup) |
                ForEach-Object {
                    [PSCustomObject]@{
                        Roleid                  = $Role.Roleid
                        RoleName                = $Role.RoleName
                        Roletype                = $Role.Roletype
                        description             = $Role.description
                        isBuiltIn               = $Role.isBuiltIn
                        isBuiltInRoleDefinition = $Role.isBuiltInRoleDefinition
                        RoleScopeTags           = $Role.RoleScopeTags -join "`r`n"
                        AssignmentId            = $Role.AssignmentId
                        AssignmentName          = $Role.AssignmentName
                        AssignmentDescription   = $Role.AssignmentDescription
                        AssignmentScopeType     = $Role.AssignmentScopeType
                        AssignmentTargetType    = 'Scope group'
                        AssignmentTargetName    = "$_"
                    }
                }
                @($Role.AssignmentMembers) |
                    ForEach-Object {
                        [PSCustomObject]@{
                            Roleid                  = $Role.Roleid
                            RoleName                = $Role.RoleName
                            Roletype                = $Role.Roletype
                            description             = $Role.description
                            isBuiltIn               = $Role.isBuiltIn
                            isBuiltInRoleDefinition = $Role.isBuiltInRoleDefinition
                            RoleScopeTags           = $Role.RoleScopeTags -join "`r`n"
                            AssignmentId            = $Role.AssignmentId
                            AssignmentName          = $Role.AssignmentName
                            AssignmentDescription   = $Role.AssignmentDescription
                            AssignmentScopeType     = $Role.AssignmentScopeType
                            AssignmentTargetType    = 'Role member'
                            AssignmentTargetName    = "$_"
                        }
                    }
                } |
                    Export-Excel -WorksheetName 'Intune RBAC' -TableName $_ @ExcelParams
    }
    'IntuneScopeTags' {
        $ScopeTagList | ForEach-Object {
            $Scope = $_
            $Scope.Assignments |
                ForEach-Object {
                    [PSCustomObject]@{
                        id                   = $Scope.id
                        displayName          = $SCope.displayName
                        AssignmentId         = $_.id
                        AssignmentTargetName = $_.displayName
                        description          = $Scope.description
                    }
                }
            } |
                Export-Excel -WorksheetName 'Intune Scope Tags' -TableName $_ @ExcelParams
    }
    'AdministrativeUnits' {
        #TODO
    }
}
#endregion additional tables

#region customizations
$Excel = Open-ExcelPackage -Path $ExcelParams.Path

$ColumnDefinitions = @(
    # All groups
    @{WIndex = 1; MinWidth = 35; Wrap = $false } #id
    @{WIndex = 1; MinWidth = 75; Wrap = $true } #Name
    @{WIndex = 1; MinWidth = 70; Wrap = $true } #Description
    @{WIndex = 1; MinWidth = 12; Wrap = $false } #Type
    @{WIndex = 1; MinWidth = 17; Wrap = $false } #Membership
    @{WIndex = 1; MinWidth = 10; Wrap = $false } #Source
    @{WIndex = 1; MinWidth = 10; Wrap = $false } #Test group
    @{WIndex = 1; MinWidth = 8; Wrap = $false } #Members
    @{WIndex = 1; MinWidth = 8; Wrap = $false } #Devices
    @{WIndex = 1; MinWidth = 8; Wrap = $false } #Users
    @{WIndex = 1; MinWidth = 8; Wrap = $false } #Groups
    @{WIndex = 1; MinWidth = 8; Wrap = $false } #Others
    @{WIndex = 1; MinWidth = 8; Wrap = $false } #Owners
    @{WIndex = 1; MinWidth = 10; Wrap = $false } #To be reviewed
    @{WIndex = 1; MinWidth = 16; Wrap = $false } #Created on
    @{WIndex = 1; MinWidth = 10; Wrap = $false } #Security enabled
    @{WIndex = 1; MinWidth = 10; Wrap = $false } #Role assignable
    @{WIndex = 1; MinWidth = 10; Wrap = $false } #On-prem sync enabled
    @{WIndex = 1; MinWidth = 10; Wrap = $false } #On-prem domain
    @{WIndex = 1; MinWidth = 10; Wrap = $false } #Writeback enabled
    @{WIndex = 1; MinWidth = 25; Wrap = $true } #Nested in
    @{WIndex = 1; MinWidth = 25; Wrap = $true } #Nested groups
    @{WIndex = 1; MinWidth = 15; Wrap = $false } #OnPremisesGroupType
    @{WIndex = 1; MinWidth = 10; Wrap = $false } #Mail enabled
    @{WIndex = 1; MinWidth = 50; Wrap = $false } #Mail
    @{WIndex = 1; MinWidth = 10; Wrap = $false } #In use
    @{WIndex = 1; MinWidth = 30; Wrap = $true } #Intune Policy
    @{WIndex = 1; MinWidth = 30; Wrap = $true } #Intune Roles
    @{WIndex = 1; MinWidth = 30; Wrap = $true } #Intune ScopeTag
    @{WIndex = 1; MinWidth = 30; Wrap = $true } #Administrative units
    # Dynamic groups
    @{WIndex = 2; MinWidth = 35; Wrap = $false } #id
    @{WIndex = 2; MinWidth = 75; Wrap = $true } #Name
    @{WIndex = 2; MinWidth = 80; Wrap = $true } #Membership rule
    @{WIndex = 2; MinWidth = 16; Wrap = $false } #Processing state
    @{WIndex = 2; MinWidth = 10; Wrap = $false } #Uses group.objectid
    @{WIndex = 2; MinWidth = 25; Wrap = $true } #Nested group
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext1
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext2
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext3
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext4
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext5
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext6
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext7
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext8
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext9
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext10
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext11
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext12
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext13
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext14
    @{WIndex = 2; MinWidth = 6; Wrap = $false } #ext15
    @{WIndex = 2; MinWidth = 10; Wrap = $false } #Autopilot
    @{WIndex = 2; MinWidth = 30; Wrap = $false } #GroupTag
    @{WIndex = 2; MinWidth = 15; Wrap = $true } #UserProperties
    @{WIndex = 2; MinWidth = 15; Wrap = $true } #DeviceProperties
)

$ColumnIndex = 1
$LastWIndex = 1
foreach ($Column in $ColumnDefinitions) {
    if ($Column.WIndex -gt $LastWIndex) {
        $ColumnIndex = 1
    }
    $ColumnObj = $Excel.Workbook.Worksheets[$Column.WIndex].Column($ColumnIndex++)
    $ColumnObj.Style.VerticalAlignment = 'Top' # Set the vertical alignment
    $ColumnObj.Style.WrapText = $Column.Wrap # Wrap text if defined in the $ColumnDefinitions
    $ColumnObj.AutoFit($Column.MinWidth) # Autofit the column with a minimum width
    $LastWIndex = $Column.WIndex
}
<#
$worksheet = $exceL.workbook.Worksheets["$($ExcelParams.PivotTableName)"]
$pt = $worksheet.PivotTables["$($ExcelParams.PivotTableName)"]
$pt.DataFields[0].Name = 'Group count'
$pt.RowHeaderCaption = 'Membership'
$pt.ColumnHeaderCaption = 'Is Role assignable?'
$Excel.Save() #>

Close-ExcelPackage -ExcelPackage $Excel -Show
#endregion customizations
