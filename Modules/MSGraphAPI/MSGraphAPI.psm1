#region examples
<#
Autopilot devices:
    (update properties) deviceManagement/windowsAutopilotDeviceIdentities/$Id/updateDeviceProperties
    (unassign) deviceManagement/windowsAutopilotDeviceIdentities/$Id/unassignUserFromDevice

==============================APPS
- Apps
    (microsoft.graph.managedApp/appAvailability eq null or microsoft.graph.managedApp/appAvailability eq 'lineOfBusiness' or isAssigned eq true)
- App Configuration policies
    - Mobile: deviceAppManagement/mobileAppConfigurations
        FILTER = isof('microsoft.graph.iosMobileAppConfiguration') or isof('microsoft.graph.androidManagedStoreAppConfiguration')
                 microsoft.graph.androidManagedStoreAppConfiguration/appSupportsOemConfig eq false or isof('microsoft.graph.androidManagedStoreAppConfiguration') eq false
                 microsoft.graph.androidManagedStoreAppConfiguration/appSupportsOemConfig eq true

==============================ENTRA
- Group Object membership
    - Users: users/{id}/transitiveMemberOf
    - Devices: devices/{id}/transitiveMemberOf


==============================ID
When deviceManagement/deviceEnrollmentConfigurations is queried, object ids can be suffixed depending on their @odata.type:
    _DefaultLimit (Enrollment device limit restrictions)
    _Limit (Enrollment device limit restrictions)
    _PlatformRestrictions (Enrollment restrictions)
    _DefaultPlatformRestrictions (Enrollment restrictions)
    _SinglePlatformRestriction (Enrollment restrictions)
    _DefaultWindows10EnrollmentCompletionPageConfiguration
    _Windows10EnrollmentCompletionPageConfiguration (Enrollment status page)
    _WindowsRestore (Windows Backup and Restore)
    _DefaultWindowsHelloForBusiness (Windows Hello for Business)

Some are prefixed:
    - deviceAppManagement/androidManagedAppProtections or deviceAppManagement/iosManagedAppProtections
        T_ (App protection)
    - deviceAppManagement/targetedManagedAppConfigurations
        A_ (Managed apps)
#>



#endregion examples


#region variables
#$BaselineTemplateFilter = (Get-IntuneTemplate | Where-Object -Property templatename -Match 'baseline' | Select-Object -ExpandProperty id | ForEach-Object { "templateid eq '$_'" }) -join ' or '
$Script:AssignableIntuneResourceMap = @(
    # Compliance policies types: #microsoft.graph.aospDeviceOwnerCompliancePolicy, #microsoft.graph.iosCompliancePolicy, #microsoft.graph.androidDeviceOwnerCompliancePolicy, #microsoft.graph.macOSCompliancePolicy, #microsoft.graph.windows10CompliancePolicy, #microsoft.graph.androidWorkProfileCompliancePolicy, #microsoft.graph.androidCompliancePolicy
    @{Category = 'Compliance'; SubCategory = 'Compliance policy'; Resource = 'deviceManagement/deviceCompliancePolicies' }
    #@{Category = 'Compliance'; SubCategory = 'Compliance notifications'; Resource = ''}
    @{Category = 'Configuration policies'; SubCategory = 'Administrative Templates'; Resource = 'deviceManagement/groupPolicyConfigurations' }
    @{Category = 'Configuration policies'; SubCategory = 'Configuration policies'; Resource = 'deviceManagement/configurationPolicies'; Filter = "templateReference/TemplateFamily eq 'none'" }
    @{Category = 'Configuration policies'; SubCategory = 'Device configurations'; Resource = 'deviceManagement/deviceConfigurations'; Filter = "not isof('microsoft.graph.windowsUpdateForBusinessConfiguration') and not isof('microsoft.graph.iosUpdateConfiguration')" }
    @{Category = 'Configuration policies'; SubCategory = 'Properties catalog'; Resource = 'deviceManagement/inventoryPolicies' }
    @{Category = 'Configuration policies'; SubCategory = 'Policy sets'; Resource = 'deviceAppManagement/policySets' }
    @{Category = 'Updates'; SubCategory = 'Windows Update Rings'; Resource = 'deviceManagement/deviceConfigurations'; Filter = "isof('microsoft.graph.windowsUpdateForBusinessConfiguration')" }
    @{Category = 'Updates'; SubCategory = 'Windows Feature Update profiles'; Resource = 'deviceManagement/windowsFeatureUpdateProfiles' }
    @{Category = 'Updates'; SubCategory = 'Windows Quality Update profiles'; Resource = 'deviceManagement/windowsQualityUpdateProfiles' }
    @{Category = 'Updates'; SubCategory = 'Windows Driver update profiles'; Resource = 'deviceManagement/windowsDriverUpdateProfiles' }
    @{Category = 'Updates'; SubCategory = 'iOS and iPad update policies'; Resource = 'deviceManagement/deviceConfigurations'; Filter = "isof('microsoft.graph.iosUpdateConfiguration')" }
    @{Category = 'Updates'; SubCategory = 'macOS update policies'; Resource = 'deviceManagement/deviceConfigurations'; Filter = "isof('microsoft.graph.macOSSoftwareUpdateConfiguration')" }
    #@{Category = 'Configuration policies'; SubCategory = 'Android FOTA deployments'; Resource = ''; Filter = ""}
    @{Category = 'Enrollment'; SubCategory = 'Enrollment configurations'; Resource = 'deviceManagement/deviceEnrollmentConfigurations' }
    #@{Category = 'Enrollment'; SubCategory = 'Enrollment restrictions'; Resource = 'deviceManagement/deviceEnrollmentConfigurations'; Filter = "deviceEnrollmentConfigurationType eq 'SinglePlatformRestriction' or deviceEnrollmentConfigurationType eq 'platformRestrictions'"}
    #@{Category = 'Enrollment'; SubCategory = 'Enrollment restrictions'; Resource = 'deviceManagement/deviceEnrollmentConfigurations'; Filter = "isof('microsoft.graph.deviceEnrollmentPlatformRestrictionsConfiguration') or isof('microsoft.graph.deviceEnrollmentPlatformRestrictionConfiguration')"}
    #@{Category = 'Enrollment'; SubCategory = 'Device limit restrictions'; Resource = 'deviceManagement/deviceEnrollmentConfigurations'; Filter = "deviceEnrollmentConfigurationType eq 'Limit'"}
    #@{Category = 'Enrollment'; SubCategory = 'Notifications'; Resource = 'deviceManagement/notificationMessageTemplates'; Filter = "isof('microsoft.graph.deviceEnrollmentNotificationConfiguration')"}
    #@{Category = 'Enrollment'; SubCategory = 'Windows Hello for Business'; Resource = 'deviceManagement/deviceEnrollmentConfigurations'; Filter = "isof('microsoft.graph.deviceEnrollmentWindowsHelloForBusinessConfiguration')" }
    @{Category = 'Enrollment'; SubCategory = 'Windows Autopilot Deployment profiles'; Resource = 'deviceManagement/windowsAutopilotDeploymentProfiles' }
    #@{Category = 'Enrollment'; SubCategory = 'Device preparation policies'; Resource = 'deviceManagement/deviceEnrollmentConfigurations'; Filter = ""}
    #@{Category = 'Enrollment'; SubCategory = 'Enrollment status page'; Resource = 'deviceManagement/deviceEnrollmentConfigurations'; Filter = "isof('microsoft.graph.windows10EnrollmentCompletionPageConfiguration')"}
    #@{Category = 'Enrollment'; SubCategory = 'Windows Backup and Restore'; Resource = ''; Filter = "isof('microsoft.graph.windowsRestoreDeviceEnrollmentConfiguration')"}
    @{Category = 'Enrollment'; SubCategory = 'Apple enrollment types'; Resource = 'deviceManagement/appleUserInitiatedEnrollmentProfiles' }
    @{Category = 'Scripts'; SubCategory = 'PowerShell scripts'; Resource = 'deviceManagement/deviceManagementScripts' }
    @{Category = 'Scripts'; SubCategory = 'Shell scripts'; Resource = 'deviceManagement/deviceShellScripts' }
    @{Category = 'Scripts'; SubCategory = 'Remediation Scripts'; Resource = 'deviceManagement/deviceHealthScripts'; Filter = "deviceHealthScriptType eq 'deviceHealthScript'" }
    @{Category = 'Scripts'; SubCategory = 'MacOS Custom Attribute Shell Scripts'; Resource = 'deviceManagement/deviceCustomAttributeShellScripts' }
    @{Category = 'Windows 365 Cloud PC'; SubCategory = 'Provisioning polices'; Resource = 'deviceManagement/virtualEndpoint/provisioningPolicies' }
    @{Category = 'Windows 365 Cloud PC'; SubCategory = 'Settings'; Resource = 'deviceManagement/virtualEndpoint/userSettings' }
    #@{Category = 'Windows 365 Cloud PC'; SubCategory = 'Maintenance Windows'; Resource = 'deviceManagement/virtualEndpoint/maintenanceWindow' }
    @{Category = 'Applications'; SubCategory = 'Applications'; Resource = 'deviceAppManagement/mobileApps' }
    @{Category = 'Application Configurations'; SubCategory = 'Configuration policies - Single platform'; Resource = 'deviceAppManagement/mobileAppConfigurations'; Filter = "isof('microsoft.graph.iosMobileAppConfiguration') or isof('microsoft.graph.androidManagedStoreAppConfiguration')" }
    @{Category = 'Application Configurations'; SubCategory = 'Configuration policies - Multiple platforms'; Resource = 'deviceAppManagement/targetedManagedAppConfigurations' }
    @{Category = 'Application Configurations'; SubCategory = 'Protection policies - iOS'; Resource = 'deviceAppManagement/iosManagedAppProtections' }
    @{Category = 'Application Configurations'; SubCategory = 'Protection policies - Android'; Resource = 'deviceAppManagement/androidManagedAppProtections' }
    @{Category = 'Application Configurations'; SubCategory = 'Protection policies - Windows'; Resource = 'deviceAppManagement/windowsInformationProtectionPolicies' }
    @{Category = 'Application Configurations'; SubCategory = 'Protection policies - Windows MDM'; Resource = 'deviceAppManagement/mdmWindowsInformationProtectionPolicies' }
    @{Category = 'Application Configurations'; SubCategory = 'iOS app provisioning profiles'; Resource = 'deviceAppManagement/iosLobAppProvisioningConfigurations' }
    @{Category = 'Application Configurations'; SubCategory = 'S Mode Supplemental policies'; Resource = 'deviceAppManagement/wdacSupplementalPolicies' }
    #@{Category = 'Application Configurations'; SubCategory = 'Policies for Microsoft 365 apps'; Resource = ''; Filter = ""} # TODO
    #@{Category = 'Application Configurations'; SubCategory = 'Quiet time'; Resource = ''; Filter = ""} # TODO
    @{Category = 'Application Configurations'; SubCategory = 'eBooks'; Resource = 'deviceAppManagement/managedEBooks' }
    @{Category = 'Endpoint Security'; SubCategory = 'Configurations'; Resource = 'deviceManagement/configurationPolicies'; Filter = "templateReference/TemplateFamily ne 'none' and templateReference/TemplateFamily ne 'baseline'" }
    #@{Category = 'Endpoint Security'; SubCategory = 'Account Protection policies'; Resource = 'deviceManagement/configurationPolicies'; Filter = "isof('microsoft.graph.endpointSecurityAccountProtection')"}
    #@{Category = 'Endpoint Security'; SubCategory = 'Antivirus policies'; Resource = 'deviceManagement/configurationPolicies'; Filter = "isof('microsoft.graph.endpointSecurityAntivirus')"}
    #@{Category = 'Endpoint Security'; SubCategory = 'Attack Surface Reduction policies'; Resource = 'deviceManagement/configurationPolicies'; Filter = "isof('microsoft.graph.endpointSecurityAttackSurfaceReductionRules')"}
    #@{Category = 'Endpoint Security'; SubCategory = 'Disk Encryption policies'; Resource = 'deviceManagement/configurationPolicies'; Filter = "isof('microsoft.graph.endpointSecurityDiskEncryption')"}
    #@{Category = 'Endpoint Security'; SubCategory = 'Disk Encryption policies'; Resource = 'deviceManagement/intents'; Filter = "templateId eq 'd1174162-1dd2-4976-affc-6667049ab0ae'"}
    #@{Category = 'Endpoint Security'; SubCategory = 'Endpoint Detection and Response policies'; Resource = 'deviceManagement/configurationPolicies'; Filter = "isof('microsoft.graph.endpointSecurityEndpointDetectionAndResponse')"}
    #@{Category = 'Endpoint Security'; SubCategory = 'Firewall policies'; Resource = 'deviceManagement/configurationPolicies'; Filter = "isof('microsoft.graph.endpointSecurityFirewall')"}
    #@{Category = 'Endpoint Security'; SubCategory = 'Endpoint Privilege Management'; Resource = 'deviceManagement/configurationPolicies'; Filter = "isof('microsoft.graph.endpointSecurityEndpointPrivilegeManagement')"}
    #@{Category = 'Endpoint Security'; SubCategory = 'App Control for Business Policies'; Resource = 'deviceManagement/configurationPolicies'; Filter = "isof('microsoft.graph.endpointSecurityApplicationControl')"}
    #@{Category = 'Endpoint Security'; SubCategory = 'Managed installer'; Resource = 'deviceManagement/deviceHealthScripts'; Filter = "deviceHealthScriptType eq 'managedInstallerScript'"}
    @{Category = 'Endpoint Security'; SubCategory = 'Security baselines'; Resource = 'deviceManagement/configurationPolicies'; Filter = "templateReference/TemplateFamily eq 'baseline'" }
    @{Category = 'Endpoint Security'; SubCategory = 'Security baselines - Legacy'; Resource = 'deviceManagement/intents'; Filter = "templateid eq 'cef15778-c3b9-4d53-a00a-042929f0aad0' or templateid eq '2209e067-9c8c-462e-9981-5a8c79165dcc' or templateid eq 'a8d6fa0e-1e66-455b-bb51-8ce0dde1559e' or templateid eq '034ccd46-190c-4afc-adf1-ad7cc11262eb'" }
    #@{Category = 'Endpoint Security'; SubCategory = 'Security baselines - Legacy'; Resource = 'deviceManagement/intents'; Filter = "$BaselineTemplateFilter" }
    @{Category = 'Tenant administration'; SubCategory = 'Role definitions'; Resource = 'deviceManagement/roleDefinitions' }
    @{Category = 'Tenant administration'; SubCategory = 'Role assignments'; Resource = 'deviceManagement/roleassignments' }
    @{Category = 'Tenant administration'; SubCategory = 'Scope tags'; Resource = 'deviceManagement/roleScopeTags' }
    @{Category = 'Tenant administration'; SubCategory = 'Terms and conditions'; Resource = 'deviceManagement/termsAndConditions' }
    @{Category = 'Tenant administration'; SubCategory = 'Customization'; Resource = 'deviceManagement/intuneBrandingProfiles' }
    @{Category = 'Tenant administration'; SubCategory = 'Multi admin approval'; Resource = 'deviceManagement/operationApprovalPolicies' }
)

$Script:NonAssignableIntuneResourceMap = @(
    @{Category = 'Compliance'; SubCategory = 'Compliance scripts'; Resource = 'deviceManagement/deviceComplianceScripts' }
    @{Category = 'Configuration'; SubCategory = 'W365 Azure network connection'; Resource = 'deviceManagement/virtualEndpoint/onPremisesConnections' }
    @{Category = 'Devices'; SubCategory = 'Autopilot devices'; Resource = 'deviceManagement/windowsAutopilotDeviceIdentities' }
    @{Category = 'Devices'; SubCategory = 'Intune devices'; Resource = 'deviceManagement/managedDevices' }
    @{Category = 'Enrollment'; SubCategory = 'Android enrollment'; Resource = 'deviceManagement/androidDeviceOwnerEnrollmentProfiles' }
    @{Category = 'Tenant administration'; SubCategory = 'Assignment filters'; Resource = 'deviceManagement/assignmentFilters' }
    @{Category = 'Tenant administration'; SubCategory = 'Device cleanup rules'; Resource = 'deviceManagement/managedDeviceCleanupRules' }
)

$Script:EntraResourceMap = @(
    @{Category = 'Directory'; SubCategory = 'Devices'; Resource = 'devices' }
    @{Category = 'Directory'; SubCategory = 'Groups'; Resource = 'groups' }
    @{Category = 'Directory'; SubCategory = 'Users'; Resource = 'users' }
    #https://learn.microsoft.com/en-us/graph/api/directory-deleteditems-list
    @{Category = 'Directory'; SubCategory = 'Deleted administrative units'; Resource = 'directory/deletedItems/microsoft.graph.administrativeUnit' }
    @{Category = 'Directory'; SubCategory = 'Deleted applications'; Resource = 'directory/deletedItems/microsoft.graph.application' }
    @{Category = 'Directory'; SubCategory = 'Deleted certificate authority detail'; Resource = 'directory/deletedItems/microsoft.graph.certificateAuthorityDetail' }
    @{Category = 'Directory'; SubCategory = 'Deleted certificate based auth'; Resource = 'directory/deletedItems/microsoft.graph.certificateBasedAuthPki' }
    @{Category = 'Directory'; SubCategory = 'Deleted group'; Resource = 'directory/deletedItems/microsoft.graph.group' }
    @{Category = 'Directory'; SubCategory = 'Deleted service principal'; Resource = 'directory/deletedItems/microsoft.graph.servicePrincipal' }
    @{Category = 'Directory'; SubCategory = 'Deleted user'; Resource = 'directory/deletedItems/microsoft.graph.user' }
)

# Suffix added to object ids for the deviceManagement/deviceEnrollmentConfigurations endpoint
$Script:EnrollementIdSuffix = @(
    '_DefaultLimit'
    '_Limit'
    '_PlatformRestrictions'
    '_DefaultPlatformRestrictions'
    '_SinglePlatformRestriction'
    '_DefaultWindows10EnrollmentCompletionPageConfiguration'
    '_Windows10EnrollmentCompletionPageConfiguration'
    '_WindowsRestore'
    '_DefaultWindowsHelloForBusiness'
)

# List of non retryable status code to be used in the retry loop
$Script:nonRetryableHttpStatusCodes = @{
    '400' = 'BadRequest'
    '401' = 'Unauthorized'
    '403' = 'Forbidden / Access denied'
    '404' = 'Resource not found'
    '405' = 'Method Not Allowed - Wrong HTTP verb'
    '409' = 'Conflict - Resource state conflict'
    '410' = 'Gone - Resource permanently removed'
    '411' = 'Length Required - Missing Content-Length'
    '413' = 'Payload Too Large - Request body too big'
    '415' = 'Unsupported Media Type - Wrong content type'
    '422' = 'Unprocessable Entity - Validation failure'
}
#endregion variables


if ($null -eq (Get-Command -Name 'Write-Log' -EA Ignore)) {
    function Write-Log {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, Position = 0)]
            [String]$Message,

            [Parameter(Position = 1)]
            [ValidateSet('Debug', 'Info', 'Warning', 'Error')]
            [String[]]$Type = 'Info',

            [Alias('Path', 'FullName')]
            [String]$LogFile,

            [String]$Component = ' ',

            [Switch]$CMTrace,

            [Switch]$NoTimestamp,

            [Switch]$DebugMode,

            [Switch]$SplitLine,

            [Switch]$PassThru
        )

        if (($null -ne $Global:Error[0])) {
            $ErrorMessage = $Global:Error[0].Exception.Message
            $Global:Error.Clear()
            $Type = 'Error'
        }

        if (($Type.Count -eq 1) -and ($Type -eq 'Debug')) { $Type = 'Info' }

        switch ($Type) {
            'Info' {
                Write-Verbose -Message $Message -Verbose
            }
            'Warning' {
                Write-Warning -Message $Message
            }
            'Error' {
                $EAPref = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                Write-Error -Message "$Message. $ErrorMessage"
                $Global:Error.RemoveAt(0)
                $ErrorActionPreference = $EAPref
            }
        }
    }
}


#region authentication
function ConvertFrom-JWTToken {
    <#
.SYNOPSIS
    Convert a JWT token to an object.

.DESCRIPTION
    Convert a JWT token to an object.

    This function can be used instead of an online tool to avoid data theft.

.PARAMETER Token
    String representing the JWT token.

.PARAMETER httpResponse
    System.Net.Http.HttpResponseMessage object.

.EXAMPLE
    PS C:\> $Token = (Invoke-MgGraphRequest -Method GET -Uri 'v1.0/me' -OutputType 'HttpResponseMessage').RequestMessage.Headers.Authorization.Parameter
    PS C:\> ConvertFrom-JWTToken -Token $Token

.EXAMPLE
    PS C:\> Invoke-MgGraphRequest -Method GET -Uri 'v1.0/me' -OutputType 'HttpResponseMessage' | ConvertFrom-JWTToken

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION:
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [cmdletbinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'TokenString')]
        [string]$token,

        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'HttpResponseMessage')]
        [System.Net.Http.HttpResponseMessage]$httpResponse
    )

    begin {
        $DateOrigin = Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0
        $timeZone = Get-TimeZone
        $offset = $timeZone.GetUtcOffset($(Get-Date)).TotalMinutes #Daylight saving needs to be calculated
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'httpResponseMessage') {
            [String]$Token = $httpResponse.RequestMessage.Headers.Authorization.Parameter
        }

        #Validate as per https://tools.ietf.org/html/rfc7519
        #Access and ID tokens are fine, Refresh tokens will not work
        if (!$token.Contains('.') -or !$token.StartsWith('eyJ')) { throw 'Invalid token' }

        $SplitedToken = $token.Split('.')
        #Header
        $tokenheader = $SplitedToken[0].Replace('-', '+').Replace('_', '/')
        #Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
        while ($tokenheader.Length % 4) {
            Write-Verbose -Message 'Invalid length for a Base-64 char array or string, adding ='
            $tokenheader += '='
        }
        Write-Verbose -Message 'Base64 encoded (padded) header:'
        Write-Verbose -Message $tokenheader
        #Convert from Base64 encoded string to PSObject all at once
        Write-Verbose -Message 'Decoded header:'
        $decodedHeaderToken = [System.Text.Encoding]::ASCII.GetString([system.convert]::FromBase64String($tokenheader)) | ConvertFrom-Json

        # Signature
        foreach ($i in 0..2) {
            $Signature = $SplitedToken[$i].Replace('-', '+').Replace('_', '/')
            switch ($Signature.Length % 4) {
                0 { break }
                2 { $Signature += '==' }
                3 { $Signature += '=' }
            }
        }

        #Payload
        $tokenPayload = $SplitedToken[1].Replace('-', '+').Replace('_', '/')
        #Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
        while ($tokenPayload.Length % 4) {
            Write-Verbose 'Invalid length for a Base-64 char array or string, adding ='
            $tokenPayload += '='
        }
        Write-Verbose -Message 'Base64 encoded (padded) payoad:'
        Write-Verbose -Message $tokenPayload
        #Convert to Byte array
        $tokenByteArray = [System.Convert]::FromBase64String($tokenPayload)
        #Convert to string array
        $tokenArray = [System.Text.Encoding]::ASCII.GetString($tokenByteArray)
        Write-Verbose -Message 'Decoded array in JSON format:'
        Write-Verbose -Message $tokenArray
        #Convert from JSON to PSObject
        Write-Verbose -Message 'Decoded Payload:'
        $DecodedToken = $tokenArray | ConvertFrom-Json
        $DateVariables = $DecodedToken.psobject.members | Where-Object -Property MemberType -EQ 'NoteProperty' | Where-Object -Property TypeNameOfValue -Match 'int' | Select-Object -Property name, value | Where-Object -Property Value -GT 1GB
        foreach ($DateVar in $DateVariables) {
            $DecodedToken.$($DateVar.Name) = $DateOrigin.AddSeconds($decodedToken."$($DateVar.Name)").AddMinutes($offset)
        }
        $DecodedToken | Add-Member -MemberType NoteProperty -Name 'header' -Value $decodedHeaderToken
        $DecodedToken | Add-Member -MemberType NoteProperty -Name 'signature' -Value $Signature
        $DecodedToken | Add-Member -Type NoteProperty -Name 'expiryDateTime' -Value $DecodedToken.exp
        $DecodedToken | Add-Member -Type NoteProperty -Name 'timeToExpiry' -Value ($DecodedToken.exp - (Get-Date)) -PassThru
    }
}


function Test-GraphRequiredScope {
    <#
.SYNOPSIS
    Test if the required permissions are available in the current context.

.DESCRIPTION
    Test if the required permissions are available in the current context.

    When using a delegated scenario, the function will test if the Directory.AccessAsUser.All permission is granted instead of the User, Device, or group ones.

.PARAMETER Scopes
    Permission list.

.EXAMPLE
    PS C:\> Test-GraphRequiredScope -Scopes 'DeviceManagementManagedDevices.ReadWrite.All', 'AuditLog.Read.All','User.Read.All'

.EXAMPLE
    PS C:\> Get-MgContext | Test-GraphRequiredScope

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-09-28
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String[]]$Scopes
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
    }
    process {
        $Context = Get-MgContext
        if ($null -eq $Context) {
            throw "[$InvocationName] Connect to Microsoft Graph before using this function"
        }

        [String[]]$DirectoryScope = $Scopes | Where-Object { $_.Split('.')[0] -in ('User', 'Device', 'Group', 'Directory') }
        [String[]]$Scopes = $Scopes | Where-Object { $_.Split('.')[0] -notin ('User', 'Device', 'Group', 'Directory') }

        $Delegated = (Get-MgContext | Select-Object -ExpandProperty AuthType) -in ('Delegated', 'UserProvidedAccessToken')
        [String[]]$ScopeList = $Context.Scopes
        $Permissions = ($ScopeList |
                Where-Object { $_ -in $Scopes } |
                Measure-Object |
                Select-Object -ExpandProperty Count) -eq $Scopes.Count

        if ($DirectoryScope.Count -gt 0) {
            $DirectoryPermissions = (($Delegated -eq $true) -and ($ScopeList -contains 'Directory.AccessAsUser.All')) -or (
                $ScopeList |
                    Where-Object { $_ -in $DirectoryScope } |
                    Measure-Object |
                    Select-Object -ExpandProperty Count
            ) -eq $DirectoryScope.Count

            $Permissions -and $DirectoryPermissions
        }
        else {
            $Permissions
        }
    }
    end {}
}


function Connect-MgGraphApplication {
    <#
.SYNOPSIS
Connect to Microsoft Graph and Azure.

.DESCRIPTION
Connect to Microsoft Graph and Azure.

By default, the interactive authentication is used.

To use a secret, specify only the TenantId and ApplicationId.
Enter the secret at the prompt to connect.

To use a certificate, either specify its thumbprint or its partial name.
When using the CertificateSubjectName, the function looks for a matching certificate in the current user's personal certificate store.


.PARAMETER Interactive
Use the interactive authentication method.

.PARAMETER TenantId
Id of the tenant.

.PARAMETER ApplicationId
Id of the application to connect with.

.PARAMETER CertificateThumbprint
Thumbrpint of the certificate used to connect with the application.

.PARAMETER CertificateSubjectName
Subject name of the certificate used to connect with the application.

.PARAMETER ConnectAzAccount
Connect to Azure as well as to Microsoft Graph.

.PARAMETER AzureAuthScope
Optional OAuth scope for login.

.EXAMPLE
Connect to Microsoft Graph interactively, using the default application (Microsoft Graph Command Line Tool)

    PS C:\> Connect-MgGraphApplication

.EXAMPLE
Connect to Microsoft Graph using a certificate.

    PS C:\> Connect-MgGraphApplication -TenantId $TenantId -ApplicationId $ClientId -CertificateThumbprint $CertificateThumbprint

.EXAMPLE
Connect to Microsoft Graph using a certificate.
    PS C:\> Connect-MgGraphApplication -TenantId $TenantId -ApplicationId $ClientId -CertificateSubjectName $CertificateSubjectName

.EXAMPLE
Connect to Microsoft Graph using a secret.
    PS C:\> Connect-MgGraphApplication -TenantId $TenantId -ApplicationId $ClientId

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION:
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param (
        [Parameter(ParameterSetName = 'Interactive')]
        [Switch]$Interactive,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Secret')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Cert')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'CertName')]
        [String]$TenantId,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Secret')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Cert')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'CertName')]
        [Parameter(Position = 0, ParameterSetName = 'Interactive')]
        [Alias('ClientId')]
        [String]$ApplicationId,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'Cert')]
        [String]$CertificateThumbprint,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'CertName')]
        [String]$CertificateSubjectName,

        [Parameter(Position = 3, ParameterSetName = 'Cert')]
        [Parameter(Position = 3, ParameterSetName = 'CertName')]
        [String]$CertificatePath = 'Cert:\CurrentUser\My',

        [Parameter(ParameterSetName = 'Cert')]
        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'Secret')]
        [Parameter(ParameterSetName = 'Interactive')]
        [Switch]$ConnectAzAccount,

        [Parameter(ParameterSetName = 'Cert')]
        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'Secret')]
        [Parameter(ParameterSetName = 'Interactive')]
        [ValidateNotNullOrEmpty()]
        [String]$AzureAuthScope
    )

    $InvocationName = $MyInvocation.MyCommand.Name

    $Params = @{
        NoWelcome   = $true
        ErrorAction = 'Stop'
    }

    $AzParams = @{
        ErrorAction = 'Stop'
    }

    switch -regex ($PSCmdlet.ParameterSetName) {
        'Secret' {
            $AzParams.ServicePrincipal = $true
            $AzParams.Tenant = $Params.TenantId = $TenantId
            $SecureClientSecret = Read-Host -AsSecureString -Prompt "Enter the application's secret [$ApplicationId]"
            $SecretParams = @{
                TypeName     = 'System.Management.Automation.PSCredential'
                ArgumentList = $ApplicationId, $SecureClientSecret
            }
            $Secret = New-Object @SecretParams
            $AzParams.Credential = $Params.ClientSecretCredential = $Secret
            break
        }
        'Cert' {
            $AzParams.ServicePrincipal = $true
            $AzParams.Tenant = $Params.TenantId = $TenantId
            $AzParams.ApplicationId = $Params.ClientId = $ApplicationID
            if ($_ -eq 'CertName') {
                $Certificate = Get-ChildItem -Path $CertificatePath | Where-Object -Property 'Subject' -Like "*$CertificateSubjectName*"
                if ($null -eq $Certificate) {
                    throw "[$InvocationName] No certificate matching [$CertificateSubjectName] was found in [$CertificatePath] for user [$Env:UserName]"
                }
                $CertificateThumbprint = $Certificate.Thumbprint
                $Params.Certificate = $Certificate
            }
            else {
                $Params.CertificateThumbprint = $CertificateThumbprint
            }
            $AzParams.CertificateThumbprint = $CertificateThumbprint
            break
        }
        'Interactive' {
            if ($env:IDENTITY_ENDPOINT -and $env:IDENTITY_HEADER) {
                # Managed identity
                $AzParams.Identity = $Params.Identity = $true
            }
            if ("$ApplicationId" -ne '') {
                $AzParams.ApplicationId = $Params.ClientId = $ApplicationID
            }
        }
    }

    # Connecting to Azure first because the opposite could fail
    if ($ConnectAzAccount.IsPresent) {
        if ("$AzureAuthScope" -ne '') {
            $AzParams.AuthScope = $AzureAuthScope
        }
        $null = Connect-AzAccount @AzParams
    }

    Connect-MgGraph @Params
}




function Add-MsGraphOAuthAppPermission {
    <#
.SYNOPSIS
    Add delegated Graph permissions to an App Registration.

.DESCRIPTION
    Add delegated Graph permissions to an App Registration.



.PARAMETER ApplicationName
    Name of the App Registration or Enterprise App.

.PARAMETER Scope
    Permissions to be consented.

.PARAMETER ConsentType
    Consent type:
        - "AllPrincipals" consents the permissions to everybody according to the application's settings
        - "Principal" only consents the permissions to the principals whose id are specified using the -PrincipalId parameter

.PARAMETER PrincipalId
    Id of the principals for whom the permissions should be consented.

.EXAMPLE
    PS C:\> Add-MsGraphOAuthAppPermission -ApplicationName 'Microsoft Graph Command Line Tools' -Scope 'Sites.ReadWrite.All','Files.ReadWrite.All' -ConsentType Principal -PrincipalId '11111111-2222-3333-4444-555555555555'

.EXAMPLE
    PS C:\> Add-MsGraphOAuthAppPermission -ApplicationName 'Microsoft Graph Command Line Tools' -Scope 'Sites.ReadWrite.All','Files.ReadWrite.All' -ConsentType AllPrincipals

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-05-26
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$ApplicationName,

        [Parameter(Mandatory = $true, Position = 1)]
        [String[]]$Scope,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateSet('AllPrincipals', 'Principal')]
        [String]$ConsentType,

        [Parameter(Position = 3)]
        [ValidateScript({ foreach ($id in $_) { if ($id -notmatch '^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$') { throw "Failed to validate [$id] as a guid" } }; $true })]
        [String[]]$PrincipalId
    )

    begin {
        $InvocationName = $MyInvocation.InvocationName
        $RequiredScopes = @(
            'DelegatedPermissionGrant.ReadWrite.All'
            'Directory.ReadWrite.All'
            'Directory.AccessAsUser.All'
        )
        if (! ((Get-MgContext).Scopes | Select-String -Pattern $RequiredScopes -Quiet)) {
            throw "Current context does not have one of the required scopes to run this function: $($RequiredScopes -join ', ')"
        }
        $ExistingScope = New-Object -TypeName System.Collections.Generic.List[String]
        $AddScopes = New-Object -TypeName System.Collections.Generic.List[String]
        # Get-MgServicePrincipal
        $GraphSp = Invoke-MgGraphRequestSingle -Resource 'servicePrincipals' -Filter "AppId eq '00000003-0000-0000-c000-000000000000'" -ErrorAction Stop
        $AppSp = Invoke-MgGraphRequestSingle -Resource 'servicePrincipals' -Filter "DisplayName eq '$ApplicationName'" -ErrorAction Stop
        if ($null -eq $AppSp) {
            throw "[$InvocationName] Failed to find an app named [$ApplicationName]"
        }
        # Get-MgOauth2PermissionGrant
        $pgs = Invoke-MgGraphRequestSingle -Resource 'oauth2PermissionGrants' -Filter "ClientId eq '$($AppSp.Id)'" -ErrorAction Stop
    }
    process {
        $GraphPgs = $pgs | Where-Object -Property ResourceId -EQ $GraphSp.Id | Where-Object -Property ConsentType -EQ $ConsentType
        if ($ConsentType -eq 'AllPrincipals') {
            if ($null -eq $GraphPgs) {
                # New-MgOauth2PermissionGrant
                $params = @{
                    Resource    = 'oauth2PermissionGrants'
                    Method      = 'POST'
                    Body        = @{
                        clientId    = $AppSp.Id
                        consentType = $ConsentType
                        resourceId  = $GraphSp.Id
                        scope       = ($Scope | Sort-Object -Unique) -join ' '
                    }
                    ErrorAction = 'Stop'
                }
                Invoke-MgGraphRequestSingle @params
            }
            else {
                foreach ($PGSItem in $GraphPgs) {
                    $PGSItem.Scope -split ' ' | Where-Object { "$_".Trim() -ne '' } | ForEach-Object { $ExistingScope.Add("$_") }
                    $Scope | Where-Object { $_ -notin $ExistingScope } | ForEach-Object { if ($AddScopes -notcontains "$_") { $AddScopes.Add("$_".Trim()) } }
                    if ($AddScopes.Count -eq 0) {
                        Write-Warning -Message "[$InvocationName] All the requested scopes are already consented for [$($PGSItem.id)]"
                    }
                    else {
                        #Update-MgOauth2PermissionGrant
                        $params = @{
                            Resource    = 'oauth2PermissionGrants/{0}' -f $PGSItem.id
                            Method      = 'PATCH'
                            Body        = @{
                                Scope = (($ExistingScope + $AddScopes | Sort-Object -Unique)) -join ' '
                            }
                            ErrorAction = 'Stop'
                        }
                        Invoke-MgGraphRequestSingle @params
                    }
                    $ExistingScope.Clear()
                    $AddScopes.Clear()
                }
            }
        }
        else {
            if ($PrincipalId.Count -eq 0) {
                throw 'Specify the principal id using the -PrincipalId parameter'
            }
            foreach ($PrId in $PrincipalId) {
                $ExistingScope.Clear()
                $AddScopes.Clear()
                $PGSItem = $GraphPgs | Where-Object -Property PrincipalId -EQ $PrId
                if ($null -eq $PGSItem) {
                    $params = @{
                        # New-MgOauth2PermissionGrant
                        Resource = 'oauth2PermissionGrants'
                        Method   = 'POST'
                        Body     = @{
                            clientId    = $AppSp.Id
                            consentType = $ConsentType
                            resourceId  = $GraphSp.Id
                            principalId = $PrId
                            scope       = ($Scope | Sort-Object -Unique) -join ' '
                            ErrorAction = 'Stop'
                        }
                    }
                    Invoke-MgGraphRequestSingle @params
                }
                else {
                    $PGSItem.Scope -split ' ' | Where-Object { "$_".Trim() -ne '' } | ForEach-Object { $ExistingScope.Add("$_") }
                    $Scope | Where-Object { $_ -notin $ExistingScope } | ForEach-Object { if ($AddScopes -notcontains "$_") { $AddScopes.Add("$_".Trim()) } }
                    if ($AddScopes.Count -eq 0) {
                        Write-Warning -Message "[$InvocationName] All the requested scopes are already consented for [$($PGSItem.id)]"
                    }
                    else {
                        #Update-MgOauth2PermissionGrant
                        $params = @{
                            Resource    = 'oauth2PermissionGrants/{0}' -f $PGSItem.id
                            Method      = 'PATCH'
                            Body        = @{
                                Scope = (($ExistingScope + $AddScopes | Sort-Object -Unique)) -join ' '
                            }
                            ErrorAction = 'Stop'
                        }
                        Invoke-MgGraphRequestSingle @params
                    }
                }
            }
        }
    }
    end {}
}


function Invoke-Pim {
    <#
.SYNOPSIS
    Activation of Priviledge Identity Management eligible Entra Id roles.

.DESCRIPTION
    Activation of Priviledge Identity Management eligible Entra Id roles.

    The current user is prompted to choose one or more roles which will then be activated.

    That function has an alias: pim

.EXAMPLE
    PS C:\> pim

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-09-30
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK
    roleManagement/directory/roleEligibilitySchedules (Available roles)
    roleManagement/directory/roleAssignmentScheduleRequests (Activation history)
#>


    [CmdletBinding()]
    [Alias('pim')]
    param ()

    $context = Get-MgContext
    if ($null -eq $Context) {
        Connect-MgGraph -NoWelcome -EA Stop
    }
    $currentUser = Invoke-MgGraphRequest -Uri 'v1.0/me' -OutputType PSObject | Select-Object -ExpandProperty id

    $History = Get-PimHistory

    # Get all available roles
    $Uri = 'v1.0/roleManagement/directory/roleEligibilitySchedules?$filter=principalId eq ''{0}''&$expand=RoleDefinition' -f $currentUser
    $RoleList = Invoke-MgGraphRequest -Uri $Uri -OutputType PSObject |
        Select-Object -ExpandProperty value |
        Select-Object -Property @{Label = 'DisplayName'; Expression = { $_.RoleDefinition.DisplayName } },
        @{
            Label      = 'Active'
            Expression = {
                $LastAction = $History | Where-Object -Property Role -EQ $_.RoleDefinition.DisplayName | Sort-Object -Property createdDateTime -Descending | Select-Object -First 1
                if ($LastAction.status -eq 'Revoked') {
                    $false
                }
                else {
                    if ($null -ne $LastAction.ExpiresAt) {
                        (Get-Date).ToLocalTime() -lt $LastAction.ExpiresAt
                    }
                    else {
                        $false #Revoked
                    }
                }
            }
        },
        @{
            Label      = 'LastStatus'
            Expression = {
                $History | Where-Object -Property Role -EQ $_.RoleDefinition.DisplayName | Sort-Object -Property createdDateTime -Descending | Select-Object -First 1 -ExpandProperty Status
            }
        },
        @{
            Label      = 'ActivatedOn'
            Expression = {
                $History | Where-Object -Property Role -EQ $_.RoleDefinition.DisplayName | Sort-Object -Property createdDateTime -Descending | Select-Object -ExpandProperty completedDateTime -First 1
            }
        },
        @{
            Label      = 'ExpiresAt'
            Expression = {
                $History | Where-Object -Property Role -EQ $_.RoleDefinition.DisplayName | Sort-Object -Property createdDateTime -Descending | Select-Object -ExpandProperty ExpiresAt -First 1
            }
        },
        PrincipalId,
        RoleDefinitionId,
        DirectoryScopeId,
        membertype |
        Sort-Object -Property Active, ExpiresAt -Descending |
        Out-GridView -Title 'Select the needed roles' -OutputMode Multiple

    $RequestResource = 'v1.0/roleManagement/directory/roleAssignmentScheduleRequests'
    foreach ($NeededRole in $RoleList) {
        # Activate the role
        $Params = @{
            ContentType = 'application/json'
            Method      = 'POST'
            Uri         = $RequestResource
            Body        = @{
                Action           = 'selfActivate'
                PrincipalId      = $NeededRole.PrincipalId
                RoleDefinitionId = $NeededRole.RoleDefinitionId
                DirectoryScopeId = $NeededRole.DirectoryScopeId
                Justification    = 'Needed for work'
                ScheduleInfo     = @{
                    StartDateTime = "$((Get-Date).AddHours(-1).ToUniversalTime().ToString('s'))Z"
                    Expiration    = @{
                        Type     = 'AfterDuration'
                        Duration = 'PT8H'
                    }
                }
            }
            OutputType  = 'PSObject'
        }
        Invoke-MgGraphRequest @Params
    }
}


function Get-PimHistory {
    <#
.SYNOPSIS
    Get the history of Priviledge Identity Management actions.

.DESCRIPTION
    Get the history of Priviledge Identity Management actions.

.EXAMPLE
    PS C:\> Get-PimHistory | Out-GridView

.EXAMPLE
    PS C:\> pimh | Where-Object -Property Role -match 'Intune'

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-09-30
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK
    roleManagement/directory/roleEligibilitySchedules (Available roles)
    roleManagement/directory/roleAssignmentScheduleRequests (Activation history)

#>


    [CmdletBinding()]
    [Alias('pimh')]
    param ()
    $currentUser = Invoke-MgGraphRequest -Uri 'v1.0/me' -OutputType PSObject | Select-Object -ExpandProperty id

    # Get all available roles
    $Uri = 'v1.0/roleManagement/directory/roleEligibilitySchedules?$filter=principalId eq ''{0}''&$expand=RoleDefinition' -f $currentUser
    $RoleList = Invoke-MgGraphRequest -Uri $Uri -OutputType PSObject |
        Select-Object -ExpandProperty value |
        Select-Object -Property @{Label = 'DisplayName'; Expression = { $_.RoleDefinition.DisplayName } }, PrincipalId, RoleDefinitionId, DirectoryScopeId, membertype

    $RequestResource = 'v1.0/roleManagement/directory/roleAssignmentScheduleRequests'
    Invoke-MgGraphRequest -Uri ('{0}?$orderby=createdDateTime desc' -f $RequestResource) -OutputType PSObject |
        Select-Object -ExpandProperty Value |
        Select-Object -Property @{Label = 'Role'; Expression = { $RoleList | Where-Object -Property RoleDefinitionId -EQ $_.RoleDefinitionId | Select-Object -ExpandProperty DisplayName } },
        @{Label = 'createdDateTime'; Expression = { ([datetime]$_.createdDateTime).ToLocalTime() } },
        @{Label = 'completedDateTime'; Expression = { ([datetime]$_.completedDateTime).ToLocalTime() } },
        @{
            Label      = 'ExpiresAt'
            Expression = {
                $Duration = $_.ScheduleInfo.expiration.duration -replace 'PT'
                $CompletedDate = ([datetime]$_.completedDateTime).ToLocalTime()
                switch -regex ($Duration) {
                    '(?<duration>\d+)H' { $CompletedDate.AddHours($Matches['duration']) }
                    '(?<duration>\d+)M' { $CompletedDate.AddMinutes($Matches['duration']) }
                }
            }
        },
        action,
        status,
        Justification
}
#endregion authentication


#region Invoke-MgGraphRequest
function Invoke-MgGraphRequestSingle {
    <#
.SYNOPSIS
    Invoke a Microsoft Graph request.

.DESCRIPTION
    Invoke a Microsoft Graph request.

    This function encapsulates Invoke-MgGraphRequest and offers multiple parameters to avoid having to build long queries in the uri parameter.

    When querying a resource that is not available in the v1.0 version of the API, the APIVersion can be omitted and the function will automatically switch the beta version after failing on the first try.

    When using parameters in the uri that need to have the advanced query enable, the -Advanced parameter can be used to add $count=true in the uri, or to add ConsistencyLevel=eventual in the request header.
    If advanced query is needed but the -Advanced parameter is omitted, the request will fail once and the advanced queries will automatically be enabled by the function.
    See https://learn.microsoft.com/en-us/graph/aad-advanced-queries to know more about advanced queries.

    The function also handles the common http status codes returned by Invoke-MgGraphRequest (see $Script:nonRetryableHttpStatusCodes for the full list):
        400: Bad request. Will try to enable advanced queries if the error indicates that the query is unsupported and retry once, then exit if it still fails.
        403: Access denied
        404: Not found
        429: throttling, will retry a number of $MaxRetry times before exiting with an error if unsuccessful

.PARAMETER SkipToken
    Use the @odata.nextlink returned from the previous call in the $_GraphAPINextLink global variable.

.PARAMETER DeltaToken
    Use the @odata.deltaLink returned from the previous call in the $_GraphAPIDeltaLink global variable.
    See more information at https://learn.microsoft.com/en-us/graph/delta-query-overview

.PARAMETER APIVersion
    Microsoft Graph API version: v1.0, beta
    Default is v1.0.

.PARAMETER Method
    API method: GET, POST, PATCH, PUT, DELETE.

.PARAMETER Resource
    The Graph API endpoint path to target (ex: 'me', 'users', 'groups/<id>', ...).

.PARAMETER Filter
    Graph API filters to apply.
    See https://learn.microsoft.com/en-us/graph/filter-query-parameter?tabs=http

.PARAMETER Select
    Graph API properties to include.

.PARAMETER Body
    Request body for POST/PATCH operations.

.PARAMETER OrderBy
    Property to be used for sorting the results.

.PARAMETER Expand
    Properties to be expanded.

.PARAMETER Search
    Advanced filtering using search.
    See https://learn.microsoft.com/en-us/graph/search-query-parameter

.PARAMETER Format
    Returns results in the specified media format.

.PARAMETER Top
    Number of total items to be returned.

.PARAMETER Skip
    Number of items to be skipped on each page.

.PARAMETER Advanced
    Specify if the count property and/or the ConsistencyLevel header attribute should be used.
    The $whatif parameter can also be added to see the internal graph queries without actually executing the query.
    (See https://michev.info/blog/post/3799/did-you-know-whatif-operator-for-graph-api-queries)

.PARAMETER ThrottlingDelay
    Delay between requests if throttled in milliseconds
    Default is 1000.

.PARAMETER MaxRetry
    Maximum retry attempts for failed requests.
    Default is 3.

.PARAMETER OutputType
    Type of object to be returned (PSObject,HashTable,Json,HttpResponseMessage).
    Default is PSObject.

.PARAMETER OutputFilePath
    Path to the file where the requested content should be written.

.PARAMETER ContentType
    Type of content to be returned.

.EXAMPLE
Get a list of every Windows device in Entra ID with 4 of their properties and sorted by device name.

    PS C:\> $GRParams = @{
        Resource = 'deviceManagement/managedDevices'
        Select   = 'id','deviceName','operatingSystem','AzureAdDeviceId'
        OrderBy  = 'deviceName'
        Filter   = "operatingsystem eq 'Windows'"
    }
    PS C:\> $AllDevices = Invoke-MgGraphRequestSingle @GRParams

.EXAMPLE
Get a list of Intune health (remediation) scripts.
The specified resource is not available using the v1.0 API version, hence the use of the beta one.
The APIVersion can also be omitted and the function will automatically switch the beta version after failing on the first try.

    PS C:\> Invoke-MgGraphRequestSingle -APIVersion beta -Resource 'deviceManagement/deviceHealthScripts'

.EXAMPLE

    PS C:\> $Answser = Invoke-MgGraphRequestSingle -Resource 'devices' -Top 1 -OutputType HttpResponseMessage

    ($Answser.content.ReadAsStringAsync().result | ConvertFrom-Json).value

.EXAMPLE
Use the skiptoken parameter to process a portion of the results in a loop (helps with memory management).

    PS C:\>
    $FirstCall = $true
    do {
        if ($FirstCall) {
            $Results = Invoke-MgGraphRequestSingle -Resource 'devices' -Top 100 -Select 'id','displayname' -Filter "operatingsystem eq 'Windows'"
        }
        else {
            $Results = Invoke-MgGraphRequestSingle -SkipToken $NextLink
        }

        ### process the current batch here
        $Results
        ###

        [String]$NextLink = $_GraphAPINextLink

        $FirstCall = $false
    } until ($NextLink -eq '')

.EXAMPLE
Download a file from SharePoint

    PS C:\> $SPSiteName = 'MySharepointSite'
    PS C:\> $FileFolder = 'path/of the/folder'
    PS C:\> $FileName = 'FileName.xlsx'
    PS C:\> $FullFilePath = "$FileFolder/$FileName" -replace '\s','%20'
    PS C:\> $Destination = 'C:\Windows\Temp'
    PS C:\> [String]$SPSiteId = Invoke-MgGraphRequestSingle -Resource 'sites' -Search $SPSiteName | Where-Object -Property Name -EQ $SPSiteName | Select-Object -ExpandProperty Id
    PS C:\> [String]$SPDriveId = Invoke-MgGraphRequestSingle -Resource ('sites/{0}/drives' -f $SPSiteId) | Where-Object -Property Name -eq $SPDriveName | Select-Object -ExpandProperty id
    PS C:\> $Resource = 'sites/{0}/drives/{1}/root:/{2}:/content' -f $SPSiteId,$SPDriveId,$FullFilePath
    PS C:\> Invoke-MgGraphRequestSingle -Resource $Resource -OutputFilePath "$Destination\$FileName"

.EXAMPLE
Use the whatif parameter to see the internal graph queries without actually executing the query.

    PS C:\> Invoke-MgGraphRequestSingle -Resource 'users' -Advanced WhatIf | Format-List

Description      : Execute HTTP request
Uri              : https://graph.windows.net/v2/<TenantId>/users?$select=businessPhones,displayName,givenName,jobTitle,mail,mobilePhone,officeLocation,preferredLanguage,surname,userP
                   rincipalName,id
HttpMethod       : GET
TargetWorkloadId : Microsoft.DirectoryServices

.NOTES
    AUTHOR: Tbone Granheden / Marc-Antoine ROBIN
    CREATION:
    VERSION: 1.4.1
    MODIFICATIONS:
        - 2025-09-22 - Marc-Antoine ROBIN - Code cleanup, added the Write-Log function
        - 2026-01-29 - Marc-Antoine ROBIN
            Added SkipToken, Search and Format parameters
            Added global variables to hold @odata.nextlink (_GraphAPINextLink) and @odata.count (_GraphAPICount)
            Avoid processing the query if not authenticated
            Handle the 401 status code
        - 2026-03-28 - Marc-Antoine ROBIN - Added the WhatIf capability
        - 2026-03-30 - Marc-Antoine ROBIN
            Cleanup the retry logic by using a list of non-retryable status codes
            Exit the function if a paging loop is detected
        - 2026-04-30 - Marc-Antoine ROBIN
            Added the OutputFilePath and ContentType parameters
        - 2026-06-04 - Marc-Antoine ROBIN
            Add automatic OutputFilePath if required but not specified
        - 2026-06-08 - Marc-Antoine ROBIN
            Add delta query capability

    TODO: Add the same capabilities as Invoke-MgGraphRequest
        InferOutputFileName
        SkipHttpErrorCheck
        StatusCodeVariable
        GraphRequestSession
        SessionVariable
        Headers
        ResponseHeadersVariable
        SkipHeaderValidation
        InputFilePath
        UserAgent
.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'Query')]
    [Alias('grs')]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Skip the results up to the $skiptoken', ParameterSetName = 'Skiptoken')]
        [String]$SkipToken,

        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Retrieve the modifications from the last delta sync with $deltatoken', ParameterSetName = 'Deltatoken')]
        [String]$DeltaToken,

        [Parameter(Position = 0, HelpMessage = "The Graph API version ('beta' or 'v1.0')", ParameterSetName = 'Query')]
        [ValidateSet('beta', 'v1.0')]
        [Alias('RunProfile', 'Version')]
        [string]$APIVersion = 'v1.0',

        [Parameter(Position = 1, HelpMessage = "The HTTP method for the request(e.g., 'GET', 'PATCH', 'POST', 'PUT', 'DELETE')", ParameterSetName = 'Query')]
        [ValidateSet('GET', 'PATCH', 'POST', 'PUT', 'DELETE')]
        [String]$Method = 'GET',

        [Parameter(Position = 2, Mandatory = $true, HelpMessage = "The Graph API endpoint path to target (e.g., 'me', 'users', 'groups')", ParameterSetName = 'Query')]
        [Alias('Object')]
        [string]$Resource,

        [Parameter(Position = 3, HelpMessage = 'Graph API filters to apply', ParameterSetName = 'Query')]
        [Alias('Filters')]
        [Object]$Filter,

        [Parameter(Position = 4, HelpMessage = 'Graph API properties to include', ParameterSetName = 'Query')]
        [Alias('Properties')]
        [string[]]$Select,

        [Parameter(Position = 5, HelpMessage = 'Request body for POST/PATCH operations', ParameterSetName = 'Query')]
        $Body,

        [Parameter(Position = 6, HelpMessage = 'Sorting expression', ParameterSetName = 'Query')]
        [string]$OrderBy,

        [Parameter(Position = 7, HelpMessage = 'Graph API properties to expand', ParameterSetName = 'Query')]
        [string[]]$Expand,

        [Parameter(Position = 8, HelpMessage = 'Graph API properties to search', ParameterSetName = 'Query')]
        [string]$Search,

        [Parameter(Position = 9, HelpMessage = 'Format the result', ParameterSetName = 'Query')]
        [ValidateSet('json','xml','verbosejson','atom')]
        [string]$Format,

        [Parameter(Position = 10, HelpMessage = 'Only return the $Top first results', ParameterSetName = 'Query')]
        [uint32]$Top,

        [Parameter(Position = 11, HelpMessage = 'Skip the $Skip first results', ParameterSetName = 'Query')]
        [uint32]$Skip,

        [Parameter(Position = 12, HelpMessage = 'Specify if the query is an advanced one with Count or/and ConsistencyLevel', ParameterSetName = 'Query')]
        [Parameter(Position = 1, HelpMessage = 'Specify if the query is an advanced one with Count or/and ConsistencyLevel', ParameterSetName = 'Skiptoken')]
        [Parameter(Position = 1, HelpMessage = 'Specify if the query is an advanced one with Count or/and ConsistencyLevel', ParameterSetName = 'Deltatoken')]
        [ValidateSet('Count', 'ConsistencyLevel', 'WhatIf', 'DeltaTokenLatest')]
        [String[]]$Advanced,

        [Parameter(Position = 13, HelpMessage = 'Page size (max 999 objects per page)', ParameterSetName = 'Query')]
        [ValidateRange(1, 999)]
        [uint16]$PageSize = 999,

        [Parameter(Position = 14, HelpMessage = 'Delay between requests if throttled in milliseconds', ParameterSetName = 'Query')]
        [Parameter(Position = 2, HelpMessage = 'Delay between requests if throttled in milliseconds', ParameterSetName = 'Skiptoken')]
        [Parameter(Position = 2, HelpMessage = 'Delay between requests if throttled in milliseconds', ParameterSetName = 'Deltatoken')]
        [ValidateRange(100, 60000)]
        [Alias('WaitTime')]
        [uint16]$ThrottlingDelay = 1000,

        [Parameter(Position = 15, HelpMessage = 'Maximum retry attempts for failed requests when throttled', ParameterSetName = 'Query')]
        [Parameter(Position = 3, HelpMessage = 'Maximum retry attempts for failed requests when throttled', ParameterSetName = 'Skiptoken')]
        [Parameter(Position = 3, HelpMessage = 'Maximum retry attempts for failed requests when throttled', ParameterSetName = 'Deltatoken')]
        [ValidateRange(1, 10)]
        [uint16]$MaxRetry = 3,

        [Parameter(Position = 16, ParameterSetName = 'Query')]
        [Parameter(Position = 4, ParameterSetName = 'Skiptoken')]
        [Parameter(Position = 4, ParameterSetName = 'Deltatoken')]
        [ValidateSet('PSObject', 'HashTable', 'Json', 'HttpResponseMessage')]
        [ValidateSet('PSObject', 'HashTable', 'Json', 'HttpResponseMessage')]
        [String]$OutputType = 'PSObject',

        [Parameter(Position = 17, ParameterSetName = 'Query')]
        [Parameter(Position = 5, ParameterSetName = 'Skiptoken')]
        [Parameter(Position = 5, ParameterSetName = 'Deltatoken')]
        [String]$OutputFilePath,

        [Parameter(Position = 18, ParameterSetName = 'Query')]
        [Parameter(Position = 6, ParameterSetName = 'Skiptoken')]
        [Parameter(Position = 6, ParameterSetName = 'Deltatoken')]
        [String]$ContentType
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        if ($null -eq (Get-MgContext -EA Stop)) {
            throw "[$InvocationName] Authenticate first with Microsoft Graph before using this function"
        }
        # Remove the global variables used to share the results' next link and count
        Remove-Variable -Name '_GraphAPINextLink', '_GraphAPICount' -Force -EA Ignore -Scope Global -Verbose:$false
        New-Variable -Name '_GraphAPINextLink' -Force -EA Ignore -Scope Global -Value '' -Verbose:$false
        $ResultObjectCount = 0
        $RetryCount = 0
        $Headers = @{}

        if ($Global:PSDefaultParameterValues.Keys.Count -gt 0) {
            $PSDefaultParameterValues = $Global:PSDefaultParameterValues.Clone()
        }
        else {
            $PSDefaultParameterValues.Clear()
        }

        # Build base URI
        $GuidPattern = '\w{8}-\w{4}-\w{4}-\w{4}-\w{12}'
        $TopEnabled = $false
        if ("$SkipToken".Trim() -ne '') {
            $uri = "$SkipToken".Trim()
            Write-Verbose -Message "[$InvocationName] Skipping the resource [$Resource], select [$Select], expand [$Expand] filter [$Filter], orderby [$OrderBy], skip [$Skip], top [$PageSize] and count parameters because a skiptoken was specified: $SkipToken"
            if (($Method -eq 'GET') -and ($uri -match '\$top=(\d+)')) {
                # Only retrieve the specified count of results in the skiptoken
                $PageSize = $Top = $Matches[1]
                $TopEnabled = $true
            }
        }
        elseif ("$DeltaToken".Trim() -ne '') {
            $uri = "$DeltaToken".Trim()
            Write-Verbose -Message "[$InvocationName] Skipping the resource [$Resource], select [$Select], expand [$Expand] filter [$Filter], orderby [$OrderBy], skip [$Skip], top [$PageSize] and count parameters because a DeltaToken was specified: $DeltaToken"
            if (($Method -eq 'GET') -and ($uri -match '\$top=(\d+)')) {
                # Only retrieve the specified count of results in the DeltaToken
                $PageSize = $Top = $Matches[1]
                $TopEnabled = $true
            }
        }
        else {
            $queryParams = [System.Collections.ArrayList]::new()
            $uri = "https://graph.microsoft.com/$APIVersion/$("$Resource".Trim('/'))"

            # Check if the resource is not a collection (Ex: users/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx or users('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx') )
            $SingleItemTarget = $false
            if ("$Resource" -match "(\('|/)$GuidPattern('\)|/*)$") {
                $SingleItemTarget = $true
            }

            # Add properties if specified
            if ($Select.Count -gt 0) {
                [void]$queryParams.Add("`$select=$($Select -split ',' -replace ' ' -join ',')")
            }
            # Expand properties if specified
            if ($Expand.Count -gt 0) {
                [void]$queryParams.Add("`$expand=$($Expand -join ',')")
            }
            # Search properties if specified
            if ("$Search".Trim() -ne '') {
                [void]$queryParams.Add(("`$search=`"$Search`"" -replace '"+','"'))
            }
            # Format properties if specified
            if ("$Format".Trim() -ne '') {
                [void]$queryParams.Add("`$format=$($format -join ',')")
            }

            # $filter, $orderby, $count, $skip, and $top can only be applied to collections
            if ($SingleItemTarget -eq $false) {
                # Add filters if specified
                if ($null -ne $PSBoundParameters['Filter']) {
                    if ($Filter -is [string]) {
                        [void]$queryParams.Add("`$filter=$([System.Web.HttpUtility]::UrlEncode("$($Filter -replace "'+","'")"))")
                    }
                    elseif ($Filter -is [hashtable]) {
                        $filterParts = $(
                            foreach ($key in $Filter.Keys) {
                                "$key eq '$($Filter[$key])'"
                            }
                        )
                        $filterStr = $filterParts -join ' and ' -replace "'+", "'"
                        [void]$queryParams.Add("`$filter=$([System.Web.HttpUtility]::UrlEncode("$filterStr"))")
                    }
                }

                # Expand properties if specified
                if ("$OrderBy".Trim() -ne '') {
                    [void]$queryParams.Add("`$orderby=$OrderBy")
                }

                # Add page size parameter
                if ($Method -eq 'GET') {
                    if (($Top -gt 0) -and ($Top -lt 999)) {
                        # Will exit the loop when the count of results is equal to $Top
                        $TopEnabled = $true
                        if ($Top -lt $PageSize) {
                            # $Top takes precedence over $PageSize
                            $PageSize = $Top
                        }
                    }
                    if ($PageSize -ne 999) { [void]$queryParams.Add("`$top=$PageSize") }

                    if ($Skip -gt 0) {
                        [void]$queryParams.Add("`$skip=$Skip")
                    }
                }

                # Enable the advanced queries
                if ($Advanced -contains 'count') { [void]$queryParams.Add("`$count=true") }
            }
            else {
                Write-Verbose -Message "[$InvocationName] Ignored the filter [$Filter], orderby [$OrderBy], skip [$Skip], top [$PageSize] and count parameters because the resource is not a collection"
            }

            if ($Advanced -contains 'WhatIf') {
                [void]$queryParams.Add('$whatif')
            }
            if (($Advanced -contains 'DeltaTokenLatest') -and ($Resource -like '*/delta*')) {
                if ($Resource | Select-String -Pattern '(drive)?/root/','sites/','/lists/' -Quiet) {
                    # SharePoint and OneDrive require the "token" keyword
                    [void]$queryParams.Add('token=latest')
                }
                else {
                    [void]$queryParams.Add('$deltatoken=latest')
                }
                Write-Verbose -Message "[$InvocationName] Adding $($queryParams[-1]) in the url"
            }
            # Combine query parameters into URI
            if ($queryParams.Count -gt 0) {
                $uri = "$uri`?$($queryParams -join '&')"
            }
        }
        Write-Verbose -Message "[$InvocationName] Query: $uri"

        if ($Advanced -contains 'ConsistencyLevel') {
            Write-Verbose -Message "[$InvocationName] Adding ConsistencyLevel=eventual in the headers"
            $Headers.ConsistencyLevel = 'eventual'
        }
        $JsonDepth = 10
        #$JsonDepth = if ($PSVersionTable.PSVersion -ge [version]'6.0.0') { 10 } else { 2 }
    }
    process {
        :RetryLoop do {
            if ("$uri".Trim() -eq '') { return } # Exit the loop if the previous checks did not work
            try {
                Write-Log -Message "[$InvocationName] Making request to: $uri" -Type Debug
                $i = 1
                :UriLoop do {
                    $response = $null
                    if ($Method -eq 'GET') {
                        Write-Log -Message "[$InvocationName] Requesting page $i with $PageSize items" -Type Debug
                    }
                    else {
                        Write-Log -Message "[$InvocationName] Sending request with $Method method" -Type Debug
                    }
                    #Set default parameters for Invoke-MgGraphRequest
                    $params = @{
                        Method      = $Method
                        Uri         = $uri
                        OutputType  = $OutputType
                        Headers     = $Headers
                        ErrorAction = 'Stop'
                        Verbose     = $false
                    }
                    if ("$OutputFilePath".Trim() -ne '') {
                        if (! (Split-Path -Path $OutputFilePath -Parent | Test-Path)) {
                            $null = New-Item -Path (Split-Path -Path $OutputFilePath -Parent) -ItemType Directory -Force
                        }
                        $params.OutputFilePath = "$OutputFilePath"
                    }
                    if ("$ContentType".Trim() -ne '') {
                        $params.ContentType = "$ContentType"
                    }
                    # add additional parameters based on method
                    if (($Method -in 'POST', 'PATCH', 'PUT') -and ($null -ne $Body)) {
                        $params.Body = $Body
                        $params.Headers.'Content-Type' = 'application/json'
                        if ($body.count -lt 50) {
                            Write-Log -Message "[$InvocationName] Request body: $($Body | ConvertTo-Json -Depth $JsonDepth)" -Type Debug
                        }
                        else {
                            Write-Log -Message "[$InvocationName] Request body is too big to be shown ($($body.count))" -Type Debug
                        }
                        $body = $null
                        $null = [System.GC]::GetTotalMemory($true)
                    }
                    #send request to Graph API
                    try {
                        if ($headers.Keys.Count -eq 0) { $Params.Remove('Headers') }
                        $response = Invoke-MgGraphRequest @params
                        $params.Clear()
                        Write-Log -Message "[$InvocationName] Request successful" -Type Debug
                    }
                    catch {
                        $params.Clear()
                        throw "Request failed with error: $_"
                    }
                    if ($Method -in ('POST','PUT','PATCH') -and ($null -eq $response.value)) {
                        Write-Log -Message "[$InvocationName] $Method answer delivered" -Type Debug
                        return $response
                    }
                    if ($null -ne $response.value) {
                        $ResultObjectCount += ($response.value | Measure-Object).Count
                        $response.value # return the results
                    }
                    elseif ($null -ne $response) {
                        $ResultObjectCount += ($response | Measure-Object).Count
                        $response # return the results
                    }
                    elseif ($params.ContainsKey('OutputFilePath')) {
                        if (Test-Path -LiteralPath $Params.OutputFilePath) {
                            Write-Log -Message "[$InvocationName] Requested content saved in [$($Params.OutputFilePath)]" -Type Debug
                            return "$($Params.OutputFilePath)"
                            #Get-Content -LiteralPath $Params.OutputFilePath
                        }
                        else {
                            Write-Log -Message "[$InvocationName] Could not find [$($Params.OutputFilePath)]" -Type Warning
                            return
                        }
                    }
                    Write-Log -Message "[$InvocationName] Retrieved page $i, Now total: $ResultObjectCount items" -Type Debug

                    if ($null -ne $response.'@odata.count') {
                        # Create a global variable to hold the results count
                        New-Variable -Name '_GraphAPICount' -Value $response.'@odata.count' -Force -Scope Global -EA Ignore
                    }

                    # Check for next page
                    if (($response.PSObject.Properties.Name -contains '@odata.nextLink') -and ("$($response.'@odata.nextLink')".Trim() -ne '')) {
                        if ("$Global:_GraphAPINextLink" -ne $response.'@odata.nextLink') {
                            $uri = $response.'@odata.nextLink'
                            # Create a global variable to hold the nextlink
                            Set-Variable -Name '_GraphAPINextLink' -Value $uri -Force -Scope Global -EA Ignore
                            Write-Log -Message "[$InvocationName] Next page found: $uri" -Type Debug
                        }
                        else {
                            # The previous @odata.nextlink is equal to the current one which indicates a paging loop
                            $Global:_GraphAPINextLink = $uri = ''
                            Write-Log -Message "[$InvocationName] Found a paging loop, exiting." -Type Warning
                            $response = $null
                            return
                        }
                    }
                    elseif ($response.PSObject.Properties.Name -contains '@odata.deltaLink') {
                        [String]$Global:_GraphAPIDeltaLink = $response.'@odata.deltaLink'
                        $uri = ''
                        $response = $null
                        return
                    }
                    else {
                        Write-Log -Message "[$InvocationName] No more pages found" -Type Debug
                        $uri = ''
                        $response = $null
                        return
                    }

                    if ($TopEnabled -eq $true) {
                        if ($ResultObjectCount -ge $Top) {
                            Write-Log -Message "[$InvocationName] Number of results has been reached, exiting." -Type Debug
                            $uri = ''
                            $response = $null
                            return
                        }
                        elseif (($ResultObjectCount + $PageSize) -gt $Top) {
                            $NewPageSize = $Top - $ResultObjectCount
                            $Uri = $Uri -replace "`$top=$PageSize", "`$top=$NewPageSize"
                            Write-Log -Message "[$InvocationName] Changing the number of result from $PageSize to ${NewPageSize}: $uri" -Type Debug
                            $PageSize = $NewPageSize
                        }
                    }

                    $i++
                } while ("$uri".Trim() -ne '')
                Write-Log -Message "[$InvocationName] Returning array with $ResultObjectCount items" -Type Debug
                $response = $null
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                # Exit the function if not authenticated
                if ($ErrorMessage -match 'Authentication needed|User canceled authentication') { throw $ErrorMessage }
                $Error.Clear()
                Write-Log -Message "[$InvocationName] Request failed (Retry attempt $($RetryCount + 1)/$MaxRetry): $ErrorMessage" -Type Warning
                # Converting the json error part of the answer
                $httpErrorJson = "$ErrorMessage".Split("`r`n") | Where-Object { $_ -like '{"error*' } | ConvertFrom-Json | Select-Object -ExpandProperty error
                # Check if the exception has response details (it should for HTTP errors)
                $StatusCode = $_.Exception.Response.StatusCode
                if (($null -eq $StatusCode) -and ($ErrorMessage -match 'HTTP/[\d\.]+\s+(?<StatusCode>\d+)')) {
                    # Parsing the error message to get the http status code (Ex: HTTP/1.1 400 ...)
                    $StatusCode = $Matches['StatusCode']
                }
                $httpErrorDesc = "(ErrorCode $StatusCode) [$($httpErrorJson.code)] $($httpErrorJson.message)" -replace ' \[\]\s+$'
                $RetryMessage = 'Waiting $Delay milliseconds before retrying. '
                if ($RetryCount -eq $MaxRetry) {
                    $RetryMessage = ''
                }
                if (($null -ne $_.Exception.Response) -or ($StatusCode -gt 0)) {
                    # Use switch to handle specific status codes
                    switch ($StatusCode) {
                        429 {
                            # Throttling
                            $RetryAfter = $_.Exception.Response.Headers | Where-Object -Property Key -EQ 'Retry-After' | Select-Object -ExpandProperty Value
                            if ($null -ne $RetryAfter) {
                                $Delay = $RetryAfter * 1000
                                Write-Log -Message "[$InvocationName] Throttling detected (429). $($ExecutionContext.InvokeCommand.ExpandString("$RetryMessage"))" -Type Warning
                                Start-Sleep -Milliseconds ($RetryAfter * 1000) # Convert seconds to milliseconds
                            }
                            else {
                                $Delay = [math]::Min(($ThrottlingDelay * ([math]::Pow(2, $RetryCount))), 60000) # Exponential backoff, max 60 seconds
                                Write-Log -Message "[$InvocationName] Throttling detected (429). No Retry-After header found. $($ExecutionContext.InvokeCommand.ExpandString("$RetryMessage"))" -Type Warning
                                Start-Sleep -Milliseconds $Delay
                            }
                            # Function break not needed, will fall through to retry logic below
                            break
                        }
                        400 {
                            # Bad Request
                            if ($RetryCount -eq 0) {
                                if (($httpErrorJson.Code -match 'UnsupportedQuery') -and ($httpErrorJson.message -match 'not supported')) {
                                    # Next try with advanced query enabled:
                                    Write-Log -Message "[$InvocationName] $httpErrorDesc Trying again with advanced query parameters" -Type Warning
                                    if (($uri -notlike '*$count=true*')) {
                                        if ($uri -like '*$search*') {
                                            Write-Log -Message "[$InvocationName] `$count cannot be added when `$search is used." -Type Warning
                                        }
                                        else {
                                            Write-Log -Message "[$InvocationName] Adding `$count=true to the uri" -Type Warning
                                            $uri = "$uri&`$count=true"
                                        }
                                    }
                                    if ($Headers.ContainsKey('ConsistencyLevel') -eq $false) {
                                        Write-Log -Message "[$InvocationName] Adding ConsistencyLevel=eventual in the header" -Type Warning
                                        $Headers.ConsistencyLevel = 'eventual'
                                    }
                                    break
                                }
                                elseif (($httpErrorJson.message -match 'Resource not found for the segment') -and ($APIVersion -eq 'v1.0')) {
                                    # Next try using the beta API version
                                    Write-Log -Message "[$InvocationName] $httpErrorDesc Trying again using the beta API version" -Type Warning
                                    $uri = $uri.Replace('/v1.0/', '/beta/')
                                    break
                                }
                                elseif (($httpErrorJson.message -match 'ConsistencyLevel: eventual') -and ($Headers.ContainsKey('ConsistencyLevel') -eq $false)) {
                                    # Next try using the ConsistencyLevel=eventual header
                                    Write-Log -Message "[$InvocationName] $httpErrorDesc. Adding ConsistencyLevel=eventual in the header before trying again" -Type Warning
                                    $Headers.ConsistencyLevel = 'eventual'
                                    break
                                }
                            }
                            Write-Log -Message "[$InvocationName] $httpErrorDesc" -Type Error
                            # Re-throw to fail immediately (assuming Bad Request is not retryable)
                            throw $httpErrorDesc
                        }
                        { "$_" -in $Script:nonRetryableHttpStatusCodes.Keys } {
                            Write-Log -Message "[$InvocationName] $($Script:nonRetryableHttpStatusCodes["$StatusCode"]) ($StatusCode)." -Type Error
                            # Re-throw to fail immediately
                            throw $httpErrorDesc
                        }
                        default {
                            # Other HTTP errors - Use generic retry
                            $Delay = [math]::Min(($ThrottlingDelay * ([math]::Pow(2, $RetryCount))), 60000) # Exponential backoff, max 60 seconds
                            Write-Log -Message "[$InvocationName] HTTP error $($StatusCode). $($ExecutionContext.InvokeCommand.ExpandString("$RetryMessage"))" -Type Warning
                            Start-Sleep -Milliseconds $Delay
                            # Function break not needed, will fall through to retry logic below
                            break
                        }
                    }
                }
                else {
                    if ($ErrorMessage -like "*please specify '-OutputFilePath'*") {
                        $OutputFilePath = "$env:Temp\$($Resource.Replace('/','_'))-$(Get-Date -Format 'yyyyMMdd_HHmmss').xml"
                        Write-Log -Message "[$InvocationName] $ErrorMessage. Retrying using -OutputFilePath '$OutputFilePath'" -Type Warning
                    }
                    else {
                        # Non-HTTP errors (e.g., network issues, DNS resolution) - Use generic retry
                        $Delay = [math]::Min(($ThrottlingDelay * ([math]::Pow(2, $RetryCount))), 60000) # Exponential backoff, max 60 seconds
                        Write-Log -Message "[$InvocationName] Non-HTTP error. $($ExecutionContext.InvokeCommand.ExpandString("$RetryMessage")) Error: $ErrorMessage" -Type Warning
                        Start-Sleep -Milliseconds $Delay
                        # Fall through to retry logic below
                    }
                }

                # Increment retry count and check if max retries exceeded ONLY if not already thrown
                $RetryCount++
                if ($RetryCount -ge $MaxRetry) {
                    Write-Log -Message "[$InvocationName] Request failed after $($MaxRetry) retries. Aborting." -Type Error
                    # Throw a specific message or re-throw the last caught error
                    throw "Request failed after $($MaxRetry) retries. Last error: $ErrorMessage"
                }
                # If retries not exceeded and error was potentially retryable (e.g., 429, other HTTP, non-HTTP), the loop will continue
            }
        } while ($RetryCount -le $MaxRetry)
        $response = $null
        Write-Log -Message "[$InvocationName] Request failed after $($MaxRetry) retries. Aborting." -Type Error
        throw "Request failed after $($MaxRetry) retries. $httpErrorDesc" # Re-throw the exception after max retries
    }

    end {
        # End function and report memory usage
        $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
        $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
        Write-Log -Message "[$InvocationName] Function finished. Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)" -Type Debug
    }
}


function Invoke-MgGraphRequestBatch {
    <#
.SYNOPSIS
    Invoke a Microsoft Graph request as a batch.

.DESCRIPTION
    Invoke a Microsoft Graph request as a batch.

    This function encapsulates Invoke-MgGraphRequest to process batches and offers multiple parameters to avoid having to build long queries in the uri parameter.
    Batching can be use to enhance the script performances.

    It also handles the common http status codes returned by Invoke-MgGraphRequest (see $Script:nonRetryableHttpStatusCodes for the full list):
        200 = Success
        201 = POST success
        204 = PATCH/DELETE success
        400 = Bad request
        403 = Access denied
        404 = Resource not found
        429 = Throttling, will retry a number of times before exiting with an error if unsuccessful
        100 - 199 = Informal
        200 - 299 = Success
        300 - 399 = Redirection
        400 - 499 = Errors, will retry a number of times before exiting with an error if unsuccessful
        500 - 599 = Server errors, will retry a number of times before exiting with an error if unsuccessful
    See https://learn.microsoft.com/en-us/graph/errors for more information.

    There are 2 ways of batching requests using this function:
        - All requests point to the same resource => Use the ObjectList containing a list of objects that are either ids or objects with an id property (See EXAMPLE 1)
        - Different resources are queried => Use the HashTable parameter, and the APIVersion if needed (See EXAMPLE 2)

    The function will return a list of objects with the following properties:
        - id = identificator of the request.
            Its value depends on the parameter used (hashtable, objectlist).
                Hashtable => the id is the same as the id provided in the hashtable, it'll otherwise be a number representing the order in which the request was made.
                ObjectList => the id is the same as the object's id.
        - status = http code returned by the request (2xx, 4xx)
        - header = header returned by the request (OData-Version and Content-Type)
        - body = body of the answer.
            Has a value property representing the object returned by the request (empty if no answer was returned)

    See https://learn.microsoft.com/en-us/graph/json-batching to find more information about batching.

.PARAMETER APIVersion
    Microsoft Graph API version: v1.0, beta
    Default is v1.0.

.PARAMETER Method
    API method: GET, POST, PATCH, PUT, DELETE.

.PARAMETER Resource
    The Graph API endpoint path to target (ex: 'me', 'users', 'groups/<id>', ...).

.PARAMETER Hashtable
    List of requests formated as hashtables with the following properties:
        - (Optinal) id = identificator for the request, can be a string, a guid, or a number
        - method = Same as the Method parameter
        - url = url of the request (resource, filters, select, count, ...)
        - (Optional) body = body if the request uses the POST, PATCH, or PUT method
        - (Optional) headers = additional headers (Content-Type, ConsistencyLevel, ...)

    This can be used when batching multiple queries that are using different resources.

    See https://learn.microsoft.com/en-us/graph/json-batching?tabs=http#processing-the-json-batch-response

.PARAMETER Filter
    Graph API filters to apply.

.PARAMETER Select
    Graph API properties to include.

.PARAMETER Body
    Request body for POST/PATCH operations.

.PARAMETER ObjectList
    Array of objects to process in batches.

    This parameter is used when the Resource parameter is also used.

.PARAMETER Query
    Graph API query on each object in $ObjectList.

.PARAMETER Advanced
    Specify if the count property and/or the ConsistencyLevel header attribute should be used.

.PARAMETER BatchSize
    Batch size (max 20 objects per batch).
    Default is 20.

.PARAMETER WaitTime
    Delay between batches in milliseconds.
    Default is 100.

.PARAMETER ThrottlingDelay
    Delay between request if throttled in seconds.
    Default is 2.

.PARAMETER MaxRetry
    Maximum retry attempts for failed requests.
    Default is 3.

.PARAMETER OutputType
    Type of object to be returned (PSObject,HashTable,Json,HttpResponseMessage).
    Default is PSObject.

.PARAMETER DoNotLogErrors
    Requests failing with status 4xx will not be logged.

.EXAMPLE
Get the primary users of every Windows device.

    PS C:\> $GRParams = @{
        Resource = 'deviceManagement/managedDevices'
        Select   = 'id','deviceName','operatingSystem','AzureAdDeviceId'
        OrderBy  = 'deviceName'
        Filter   = "operatingsystem eq 'Windows'"
    }
    PS C:\> $AllDevices = Invoke-MgGraphRequestSingle @GRParams

    PS C:\> $GRParams = @{
        APIVersion = 'beta'
        Resource   = 'deviceManagement/managedDevices'
        ObjectList = $AllDevices
        Query      = '/users'
        Select     = 'deviceDetail,userPrincipalName,userId'
    }
    PS C:\> $AllPrimaryUsers = Invoke-MgGraphRequestBatch @GRParams
    PS C:\> $AllPrimaryUsers.Body.value | Out-GridView

.EXAMPLE
Execute 4 queries at the same time:

    PS C:\> $HashTable = @(
        @{
            # Get the current user's groups
            id     = 'MyGroups'
            method = 'GET';
            url    = '/me/memberOf'
        },
        @{
            # Delete a group
            method = 'DELETE';
            url    = '/groups/0e226165-c685-41ce-8bfc-df8360ab325d'
        },
        @{
            # Get a list of single sign-on credentials using a password for a user
            id      = 'getPasswordSingleSignOnCredentials'
            url     = '/users/161ab652-cdbc-490d-82a4-0ada1f0db247/getPasswordSingleSignOnCredentials';
            method  = 'POST';
            body    = @{};
            headers = @{'Content-Type' = 'application/json' }
        },
        @{
            # Return a count of the users without a defined city
            id      = 'CountOfUsersWithoutDefinedCity'
            url     = 'users?$select=id,displayName,userPrincipalName&$filter=city eq null&$count=true';
            method  = 'GET';
            headers = @{
                'ConsistencyLevel' = 'eventual'
            }
        }
    )
    Invoke-MgGraphRequestBatch -Hashtable $HashTable

.NOTES
    AUTHOR: Tbone Granheden / Marc-Antoine ROBIN
    CREATION:
    VERSION: 1.2.4
    MODIFICATIONS:
        - 2025-09-19 - Marc-Antoine ROBIN - Function cleanup + Write-Log used instead of Write-Verbose/Warning/Error
        - 2025-09-25 - Marc-Antoine ROBIN - Added the hashtable parameter
        - 2026-01-25 - Marc-Antoine ROBIN
            Avoid processing the query if not authenticated
            Handle the 401 status code
            Fix the wait behavior for throttled queries where every batch was slowed down as soon as one contained a 429 code instead of looking for a 429 code in the current batch.
        - 2026-03-30 - Marc-Antoine ROBIN - Cleanup the retry logic by using a list of non-retryable status codes

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'SingleResource')]
    [Alias('grb')]
    param(
        [Parameter(Position = 0, HelpMessage = "The Graph API version ('beta' or 'v1.0')", ParameterSetName = 'SingleResource')]
        [Parameter(Position = 0, HelpMessage = "The Graph API version ('beta' or 'v1.0')", ParameterSetName = 'Hashtable')]
        [ValidateSet('beta', 'v1.0')]
        [Alias('RunProfile', 'Version')]
        [string]$APIVersion = 'v1.0',

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'List of requests in the hashtable format including method,url[,headers,body]', ParameterSetName = 'Hashtable')]
        [Hashtable[]]$Hashtable,

        [Parameter(Position = 1, HelpMessage = "The HTTP method for the request(e.g., 'GET', 'PATCH', 'POST', 'PUT', 'DELETE')", ParameterSetName = 'SingleResource')]
        [ValidateSet('GET', 'PATCH', 'POST', 'PUT', 'DELETE')]
        [String]$Method = 'GET',

        [Parameter(Position = 2, Mandatory = $true, HelpMessage = "The Graph API endpoint path to target (e.g., 'me', 'users', 'groups')", ParameterSetName = 'SingleResource')]
        [Alias('Object')]
        [string]$Resource,

        [Parameter(Position = 3, HelpMessage = 'Graph API filters to apply', ParameterSetName = 'SingleResource')]
        [Alias('Filters')]
        [Object]$Filter,

        [Parameter(Position = 4, HelpMessage = 'Graph API properties to include', ParameterSetName = 'SingleResource')]
        [Alias('Properties')]
        [string[]]$Select,

        [Parameter(Position = 4, HelpMessage = 'Graph API properties to expand', ParameterSetName = 'SingleResource')]
        [string[]]$Expand,

        [Parameter(Position = 5, HelpMessage = 'Request body for POST/PATCH operations', ParameterSetName = 'SingleResource')]
        $Body,

        [Parameter(Position = 6, Mandatory = $true, HelpMessage = 'Array of objects to process in batches', ParameterSetName = 'SingleResource')]
        [Alias('Objects')]
        [System.Object[]]$ObjectList,

        [Parameter(Position = 7, HelpMessage = 'The Graph API query on the objects', ParameterSetName = 'SingleResource')]
        [string]$Query,

        [Parameter(Position = 8, HelpMessage = 'Specify if the query is an advanced one with Count or/and ConsistencyLevel', ParameterSetName = 'SingleResource')]
        [ValidateSet('Count', 'ConsistencyLevel')]
        [String[]]$Advanced,

        [Parameter(Position = 9, HelpMessage = 'Batch size (max 20 objects per batch)', ParameterSetName = 'SingleResource')]
        [Parameter(Position = 2, HelpMessage = 'Batch size (max 20 objects per batch)', ParameterSetName = 'Hashtable')]
        [ValidateRange(1, 20)]
        [int]$BatchSize = 20,

        [Parameter(Position = 10, HelpMessage = 'Delay between batches in milliseconds', ParameterSetName = 'SingleResource')]
        [Parameter(Position = 3, HelpMessage = 'Delay between batches in milliseconds', ParameterSetName = 'Hashtable')]
        [ValidateRange(1, 5000)]
        [int]$WaitTime = 1,

        [Parameter(Position = 11, HelpMessage = 'Delay between requests if throttled in seconds', ParameterSetName = 'SingleResource')]
        [Parameter(Position = 4, HelpMessage = 'Delay between requests if throttled in seconds', ParameterSetName = 'Hashtable')]
        [ValidateRange(1, 60)]
        [uint16]$ThrottlingDelay = 2,

        [Parameter(Position = 12, HelpMessage = 'Maximum retry attempts for failed requests', ParameterSetName = 'SingleResource')]
        [Parameter(Position = 5, HelpMessage = 'Maximum retry attempts for failed requests', ParameterSetName = 'Hashtable')]
        [ValidateRange(1, 10)]
        [int]$MaxRetry = 3,

        [Parameter(Position = 13, ParameterSetName = 'SingleResource')]
        [Parameter(Position = 6, ParameterSetName = 'Hashtable')]
        [ValidateSet('PSObject', 'HashTable', 'Json', 'HttpResponseMessage')]
        [String]$OutputType = 'PSObject',

        [Parameter(ParameterSetName = 'SingleResource')]
        [Parameter(ParameterSetName = 'Hashtable')]
        [Switch]$DoNotLogErrors
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        if ($null -eq (Get-MgContext -EA Stop)) {
            throw "[$InvocationName] Authenticate first with Microsoft Graph before using this function"
        }
        $IsSystem = [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem
        $JsonDepth = 10
        #$JsonDepth = if ($PSVersionTable.PSVersion -ge [version]'6.0.0') { 10 } else { 2 }
        $ErrorActionPreference = 'Stop'
        $starttime = ([DateTime]::Now).ToString('yyyy-MM-dd HH:mm:ss')

        if ($Global:PSDefaultParameterValues.Keys.Count -gt 0) {
            $PSDefaultParameterValues = $Global:PSDefaultParameterValues.Clone()
        }
        else {
            $PSDefaultParameterValues.Clear()
        }
        try {
            $Retrycount = 0
            $CollectedObjectsCount = 0
            $RetryObjects = [System.Collections.Generic.List[PSCustomObject]]::new()

            # Check execution context
            if ($env:AUTOMATION_ASSET_ACCOUNTID) {
                [Bool]$ManagedIdentity = $true
                Write-Log -Message ('[{0}] Running in Azure Automation context' -f $InvocationName) -Type Debug
            }
            else {
                [Bool]$ManagedIdentity = $false
                Write-Log -Message ('[{0}] Running in Local PowerShell context' -f $InvocationName) -Type Debug
            }
        }
        catch {
            Write-Log -Message ('[{0}] Failed to initialize with error' -f $InvocationName) -Type Error
            throw
        }
    }

    process {
        try {
            $BreakRetryLoop = $false
            :RetryLoop do {
                try {
                    switch ($PSCmdlet.ParameterSetName) {
                        'Hashtable' {
                            $TotalObjects = ($Hashtable | Measure-Object).Count
                        }
                        'SingleResource' {
                            $TotalObjects = ($ObjectList | Measure-Object).Count
                        }
                    }

                    if ($TotalObjects -eq 0) {
                        Write-Log -Message "[$InvocationName] Cannot process an empty request" -Type Warning
                        break RetryLoop
                    }
                    Write-Log -Message "[$InvocationName] Start processing with $TotalObjects objects" -Type Debug
                    $currentObject = 0
                    # Clear RetryObjects at the beginning of each retry loop
                    $RetryObjects.Clear()

                    Write-Log -Message "[$InvocationName] Processing started with $TotalObjects objects" -Type Debug
                    # Start looping all objects and run batches
                    $Index = 0
                    for ($i = 0; $i -lt $TotalObjects; $i += $BatchSize) {
                        try {
                            # Create Requests of id, method and url
                            $batchStart = $i
                            $batchEnd = [Math]::Min($i + $BatchSize - 1, $TotalObjects - 1)
                            $BatchRequestList = $(
                                switch ($PSCmdlet.ParameterSetName) {
                                    'Hashtable' {
                                        $batchObjects = $Hashtable[$batchStart..$batchEnd]
                                        foreach ($Item in $batchObjects) {
                                            # The hashtable must have at least a method and an url property
                                            if (($null -eq $Item.method) -or ($null -eq $Item.url)) {
                                                Write-Log -Message "[$InvocationName] Item is missing a parameter: $($Item | ConvertTo-Json -Compress)" -Type Warning
                                                continue
                                            }
                                            # Use the id property provided in the hashtable or an index
                                            if ($null -ne $Item.id) { $ItemId = $Item.id }
                                            else { $ItemId = $Index++ }

                                            # Build the request hashtable for the item
                                            $Req = @{
                                                id      = $ItemId
                                                method  = "$($Item.method)".ToUpper() # The method needs to be in capital letters
                                                url     = "/$($Item.url)" -replace '^/*(v1\.0|beta)/', '/'
                                                body    = $Item.Body
                                                headers = $Item.Headers
                                            }
                                            if ($Item.method -in ('PATCH', 'POST', 'PUT')) {
                                                $Req.headers.'Content-Type' = 'application/json'
                                            }
                                            if (($null -eq $Req.headers) -and ($null -eq $Req.body)) { $Req.Remove('body'); $Req.Remove('headers') }
                                            #if ($null -eq $Req.headers) { $Req.Remove('headers') }
                                            $Req
                                        }
                                        break
                                    }
                                    'SingleResource' {
                                        $batchObjects = $ObjectList[$batchStart..$batchEnd]
                                        foreach ($Item in $batchObjects) {
                                            [String]$ItemId = $Item.Id
                                            if (("$ItemId" -eq '') -and ($null -ne $Item)) {
                                                $ItemId = $Item
                                            }

                                            # Build URL with properties and filters
                                            $url = "/$($Resource)/$ItemId/$query" -replace '/+', '/'

                                            # Add properties if specified
                                            [String[]]$urlParams = $(
                                                if ($Select.Count -gt 0) {
                                                    "`$select=$($Select -join ',')"
                                                }

                                                if ($Expand.Count -gt 0) {
                                                    "`$expand=$($Expand -join ',')"
                                                }

                                                # Add filters if specified
                                                if ($null -ne $PSBoundParameters['Filter']) {
                                                    "`$filter=$([System.Web.HttpUtility]::UrlEncode("$($Filter -replace "'+","'")"))"
                                                }

                                                if (($Advanced -contains 'count') -and ($url -notlike '*$count=true*')) {
                                                    '$count=true'
                                                }
                                            )

                                            # Combine URL parameters
                                            if ($urlParams.Count -gt 0) {
                                                $url = '{0}?{1}' -f $url, ($urlParams -join '&')
                                            }

                                            $req = @{
                                                id      = $ItemId
                                                method  = "$Method".ToUpper() # The method needs to be in capital letters
                                                url     = $url
                                                body    = $null
                                                headers = @{}
                                            }
                                            if ($Method -in ('PATCH', 'POST', 'PUT')) {
                                                $req.body = $Body
                                                $req.headers.'Content-Type' = 'application/json'
                                            }
                                            if ($Advanced -contains 'ConsistencyLevel') {
                                                $req.headers.ConsistencyLevel = 'eventual'
                                            }
                                            $Req
                                        }
                                        break
                                    }
                                }
                            )
                            Write-Log -Message "[$InvocationName] Created batch for items $($i) to $([Math]::Min($i + $BatchSize, $TotalObjects)) of $TotalObjects total items" -Type Debug
                        }
                        catch {
                            Write-Log -Message ('[{0}] Failed to create batch with error' -f $InvocationName) -Type Error
                            throw
                        }


                        # Send the requests in a batch
                        try {
                            $Params = @{
                                Method     = 'POST'
                                Uri        = "https://graph.microsoft.com/$APIVersion/`$batch"
                                Body       = @{ 'requests' = @($BatchRequestList) } | ConvertTo-Json -Depth $JsonDepth
                                Headers    = @{ 'Content-Type' = 'application/json' }
                                OutputType = $OutputType
                                Verbose    = $false
                            }
                            $responses = Invoke-MgGraphRequest @Params

                            Write-Log -Message ('[{0}] Successfully sent the request' -f $InvocationName) -Type Debug
                        }
                        catch {
                            if ("$($_.Exception.Message)" -match 'Authentication needed|User canceled authentication') { throw "$($_.Exception.Message)" }
                            Write-Log -Message ('[{0}] Failed to send batch request [{1}]' -f $InvocationName, ($Params.Body)) -Type Error
                            throw
                        }

                        # Process the responses and verify status
                        $ResponseStatusList = $responses.responses | Group-Object -Property status
                        $responses = $null # Memory management
                        $ThrottlingDetected = ($ResponseStatusList.Name -contains 429) -eq $true
                        foreach ($response in $ResponseStatusList) {
                            $CurrentObject += $response.Count
                            $ResponseStatus = $response.Name
                            $ResponseItems = $response.group
                            $ResponseIdList = $ResponseItems.id -join ', '
                            if ((($ResponseStatus -ge 100) -and ($ResponseStatus -lt 400)) -or ($ResponseStatus -in $Script:nonRetryableHttpStatusCodes.Keys)) {
                                # Return response items in case of success or non retryable error
                                $ResponseItems
                            }
                            $ErrorCode = ''
                            if (($ResponseStatus -ge 400) -and ($ResponseStatus -lt 600)) {
                                [String]$ErrorCode = "(Status: $ResponseStatus) [$($responseitems.body.error | Select-Object -Property Code,Message -Unique | ConvertTo-Json -Compress)]" -replace ' \[\]\s+$'
                            }
                            try {
                                switch ($ResponseStatus) {
                                    200 {
                                        # GET success
                                        $CollectedObjectsCount += $response.Count
                                        Write-Log -Message "[$InvocationName] Successfully processed GET for $($response.Count) objects: $ResponseIdList" -Type Debug
                                        break
                                    }
                                    201 {
                                        # POST success
                                        $CollectedObjectsCount += $response.Count
                                        Write-Log -Message "[$InvocationName] Successfully processed POST for $($response.Count) objects: $ResponseIdList" -Type Debug
                                        break
                                    }
                                    204 {
                                        # PATCH/DELETE success
                                        $CollectedObjectsCount += $response.Count
                                        Write-Log -Message "[$InvocationName] Successfully processed $Method for $($response.Count) objects: $ResponseIdList" -Type Debug
                                        break
                                    }
                                    429 {
                                        $ResponseItems | ForEach-Object { $null = $RetryObjects.Add($_) }
                                        Write-Log -Message "[$InvocationName] (Status: $ResponseStatus) Throttling occurred for $($response.Count) objects: $ResponseIdList"
                                        break
                                    }
                                    { "$_" -in $Script:nonRetryableHttpStatusCodes.Keys } {
                                        if ($DoNotLogErrors.IsPresent -eq $false) {
                                            Write-Log -Message "[$InvocationName] $($Script:nonRetryableHttpStatusCodes["$StatusCode"]) [$($ErrorCode)] for $($response.Count) objects: $ResponseIdList" -Type Error
                                            # Re-throw the original exception to signal failure to the caller
                                            throw
                                        }
                                        break
                                    }
                                    { $_ -ge 100 -and $_ -lt 200 } {
                                        # Informal
                                        Write-Log -Message "[$InvocationName] (Status: $ResponseStatus) Unexpected informal code for $($response.Count) objects: $ResponseIdList"
                                        break
                                    }
                                    { $_ -ge 200 -and $_ -lt 300 } {
                                        # Success
                                        Write-Log -Message "[$InvocationName] (Status: $ResponseStatus) Unexpected success code for $($response.Count) objects: $ResponseIdList"
                                        break
                                    }
                                    { $_ -ge 300 -and $_ -lt 400 } {
                                        # Redirection
                                        Write-Log -Message "[$InvocationName] (Status: $ResponseStatus) Unexpected redirection code for $($response.Count) objects: $ResponseIdList" -Type Warning
                                        break
                                    }
                                    { $_ -ge 400 -and $_ -lt 500 } {
                                        # Errors
                                        $ResponseItems | ForEach-Object { $null = $RetryObjects.Add($_) }
                                        Write-Log -Message "[$InvocationName] (Status: $ResponseStatus) Unexpected error code [$ErrorCode] for $($response.Count) objects: $ResponseIdList" -Type Error
                                        break
                                    }
                                    { $_ -ge 500 -and $_ -lt 600 } {
                                        # Server error
                                        $ResponseItems | ForEach-Object { $null = $RetryObjects.Add($_) }
                                        Write-Log -Message "[$InvocationName] (Status: $ResponseStatus) Unexpected server error [$ErrorCode] for $($response.Count) objects: $ResponseIdList" -Type Error
                                        break
                                    }
                                }
                            }
                            catch {
                                Write-Log -Message ('[{0}] Failed to process response' -f $InvocationName) -Type Error
                                continue
                            }
                        }
                        $ResponseStatusList = $null # Memory management
                        # Handle throttling and progress
                        try {
                            # Show progress if not running in automation
                            if (($ManagedIdentity -eq $false) -and ($IsSystem -eq $false)) {
                                # Calculate progress and time estimates
                                $ElapsedTime = New-TimeSpan -Start $starttime -End (Get-Date)
                                $timeLeft = $(
                                    if ($CurrentObject -gt 0) {
                                        [TimeSpan]::FromMilliseconds(($ElapsedTime.TotalMilliseconds / $CurrentObject) * ($TotalObjects - $CurrentObject)) # time per object * remaining objects
                                    }
                                    else {
                                        [TimeSpan]::Zero
                                    }
                                )
                                $WPParams = @{
                                    Activity        = "$($MyInvocation.MyCommand.Name) processing Graph Requests"
                                    Status          = '{0}/{1} | Est. Time: {2:hh}:{2:mm}:{2:ss} | Throttled: {3} | Retry: {4}/{5}' -f $CurrentObject, $TotalObjects, $timeLeft, $RetryObjects.Count, $Retrycount, $MaxRetry
                                    PercentComplete = ([math]::ceiling(($CurrentObject / $TotalObjects) * 100))
                                    #SecondsRemaining = [int]$timeLeft.TotalSeconds
                                }
                                Write-Progress @WPParams
                            }

                            # Handle throttling with exponential backoff
                            $throttledResponses = $RetryObjects | Where-Object -Property status -EQ 429
                            if (($ThrottlingDetected -eq $true) -and ($throttledResponses | Measure-Object).Count -gt 0) {
                                [uint32]$recommendedWait = ($throttledResponses.headers.'retry-after' | Measure-Object -Maximum).Maximum
                                if ($recommendedWait -eq 0) { $recommendedWait = $ThrottlingDelay }
                                $backoffWait = [math]::Min($recommendedWait + ($Retrycount * 2), 60) # Max 60 second wait
                                Write-Log -Message "[$InvocationName] Throttling detected, waiting $backoffWait seconds (Recommended [$recommendedWait] | Retry [$Retrycount])" -Type Warning
                                Start-Sleep -Seconds $backoffWait
                            }
                            else {
                                # Wait the specified amount of time between batches
                                Start-Sleep -Milliseconds $WaitTime
                            }
                        }
                        catch {
                            Write-Log -Message ('[{0}] Batch failed to handle throttling' -f $InvocationName) -Type Error
                            throw
                        }
                    }

                    # Handle retries
                    if (($RetryObjects.Count -gt 0) -and ($MaxRetry -gt 0)) {
                        $Retrycount++
                        if ($MaxRetry -eq 1) { $BreakRetryLoop = $true }
                        else { $MaxRetry-- }
                        Write-Log -Message "[$InvocationName] Starting retry $Retrycount with $($RetryObjects.Count) objects"
                        # The objects to retry are the ones that had errors
                        switch ($PSCmdlet.ParameterSetName) {
                            'Hashtable' {
                                $TotalObjects = ($Hashtable | Measure-Object).Count
                                $ClonedHashTable = $Hashtable.Clone()
                                [Hashtable[]]$Hashtable = $RetryObjects | ForEach-Object { $ClonedHashTable | Where-Object -Property id -EQ $_.Id }
                            }
                            'SingleResource' {
                                $ObjectList = $RetryObjects | ForEach-Object { $ObjectList | Where-Object -Property id -EQ $_.id }
                            }
                        }
                    }
                }
                catch {
                    Write-Log -Message ('[{0}] Failed in retry loop' -f $InvocationName) -Type Error
                    throw
                }
            } while (($RetryObjects.Count -gt 0) -and ($MaxRetry -gt 0) -and ($BreakRetryLoop -eq $false))

            if ($TotalObjects -gt 0) {
                Write-Log -Message "[$InvocationName] Successfully processed $CollectedObjectsCount objects" -Type Debug
            }
        }
        catch {
            Write-Log -Message ('[{0}] Function failed in main process block with error' -f $InvocationName) -Type Error
            throw $_
        }
    }
    end {
        if (($ManagedIdentity -eq $false) -and ($IsSystem -eq $false)) {
            Write-Progress -Activity $WPParams.Activity -Completed -PercentComplete 100 -EA Ignore
        }
        # End function and report memory usage
        $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
        $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
        Write-Log -Message "[$InvocationName] Function finished. Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)" -Type Debug
        if ($RetryObjects.Count -gt 0) {
            $RetryObjects # Return the failure results
            if ($DoNotLogErrors.IsPresent -eq $false) {
                throw "Failed to process $($RetryObjects.Count) objects"
            }
        }
    }
}
#endregion Invoke-MgGraphRequest


#region Invoke-AzureRequest
function Invoke-AzureRequestSingle {
    <#
.SYNOPSIS
    Invoke an Azure REST API request.

.DESCRIPTION
    Invoke an Azure REST API request.

    This function encapsulates Invoke-AzRestMethod and offers multiple parameters to avoid having to build long queries in the uri parameter.
    Paging is handled by following the nextLink property returned by the request.
    Error handling allows for automatic retry when possible (throttling, 50x server errors, ...)
    The function also handles the common http status codes returned by Invoke-AzRestMethod (see $Script:nonRetryableHttpStatusCodes for the full list):
        400: Bad request
        403: Access denied
        404: Not found
        429: throttling, will retry a number of $MaxRetry times before exiting with an error if unsuccessful

    See https://learn.microsoft.com/en-us/rest/api/azure for more information
    Throttling: https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/request-limits-and-throttling

.PARAMETER Uri
    Uniform Resource Identifier of the Azure resources.
    The target resource needs to support Azure AD authentication and the access token is derived according to resource id.
    If resource id is not set, its value is derived according to built-in service suffixes in current Azure Environment.

.PARAMETER ResourceId
    Identifier URI specified by the REST API you are calling. It shouldn't be the resource id of Azure Resource Manager

.PARAMETER Path
    Path of target resource URL. Hostname of Resource Manager should not be added.

.PARAMETER APIVersion
    Azure provider API version.

.PARAMETER Method
    API method: GET, POST, PATCH, PUT, DELETE, HEAD.

.PARAMETER SubscriptionId
    Target Subscription Id

.PARAMETER ResourceGroupName
    Target Resource Group Name

.PARAMETER ResourceProviderName
    Target Resource Provider Name
    https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-services-resource-providers

.PARAMETER ResourceType
    Target Resource Type

.PARAMETER Name
    List of Target Resource Name (URL segments coming after the resource type)

.PARAMETER Filter
    Azure REST API filters to apply.

.PARAMETER Select
    Azure REST API properties to include.

.PARAMETER Body
    Request body for PUT/POST/PATCH operations.

.PARAMETER OrderBy
    Property to be used for sorting the results.

.PARAMETER PageSize
    Page size (max 999 objects per page)

.PARAMETER ThrottlingDelay
    Delay between requests if throttled in milliseconds
    Default is 1000.

.PARAMETER MaxRetry
    Maximum retry attempts for failed requests.
    Default is 3.

.PARAMETER OutputType
    Type of object to be returned (PSObject,HashTable,Json,HttpResponseMessage).
    Default is PSObject.

.EXAMPLE
List Automation Accounts in the resource group
    PS C:\> $Params = @{
        APIVersion           = '2024-10-23'
        SubscriptionId       = $SubscriptionId
        ResourceGroupName    = $ResourceGroupName
        ResourceProviderName = 'Microsoft.Automation'
        ResourceType         = 'automationAccounts'
    }
    PS C:\> Invoke-AzureRequestSingle @Params

.EXAMPLE
Get the content of the runbook named "Runbook1"
    PS C:\> $Params = @{
        APIVersion           = '2024-10-23'
        SubscriptionId       = $SubscriptionId
        ResourceGroupName    = $ResourceGroupName
        ResourceProviderName = 'Microsoft.Automation'
        ResourceType         = 'automationAccounts'
    }
    PS C:\> Invoke-AzureRequestSingle @Params -Name $AutomationAccountName,'runbooks','Runbook1','Content'

.EXAMPLE
List the failed jobs linked to the runbook named "Runbook1"
    PS C:\> $Params = @{
        APIVersion           = '2024-10-23'
        SubscriptionId       = $SubscriptionId
        ResourceGroupName    = $ResourceGroupName
        ResourceProviderName = 'Microsoft.Automation'
        ResourceType         = 'automationAccounts'
    }
    PS C:\> Invoke-AzureRequestSingle @Params -Name $AutomationAccountName,'Jobs' -Filter "properties/runbook/name eq 'Runbook1' and properties/status eq 'Failed'"

.EXAMPLE
List the subscription providers.
This request should fail because '2024-10-23' is not a valid version.
but the function fetches the list of approved versions for the current provider and automatically switch to the most recent one.

    PS C:\> Invoke-AzureRequestSingle -Path ('subscriptions/{0}/providers?api-version={1}' -f $SubscriptionId, '2024-10-23')

The following warning will be logged:
    The api-version '2024-10-23' is invalid. The supported versions are '2026-06-01,2025-04-01,...'. Using the latest version [2026-06-01]

.EXAMPLE


.EXAMPLE


.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-07-15
    VERSION: 1.0.0
    MODIFICATIONS:

    TODO:
    - Handle PageSize and Top parameters
    - Add the same capabilities as Invoke-AzRestMethod
        Path (string) - Path of target resource URL. Hostname of Resource Manager should not be added.

        Uri (uri) - Uniform Resource Identifier of the Azure resources. The target resource needs to support Azure AD authentication and the access token is derived according to resource id. If resource id is not set, its value is derived according to built-in service suffixes in current Azure Environment.
        ResourceId (string) - Identifier URI specified by the REST API you are calling. It shouldn't be the resource id of Azure Resource Manager.

        Method (String)
        DefaultProfile (IAzureContextContainer) - The credentials, account, tenant, and subscription used for communication with Azure
        NextLinkName (string) - Specifies the name of the next link JSON property to follow for pagination.
        Paginate (switch) - Enables server-driven pagination from paginated GET endpoints.
        PageableItemName (string) - Specifies the name of the JSON property that contains the items in a paginated response.
        FinalResultFrom (string) - Specifies the header for final GET result after the long-running operation completes
        PollFrom (string) - Specifies the polling header (to fetch from) for long-running operation status
        AsJob (switch) - Run cmdlet in the background
        WaitForCompletion (switch) - Waits for the long-running operation to complete before returning the result

    - Add asynchronous operations handling: https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/async-operations

.LINK
    https://learn.microsoft.com/en-us/azure/governance/resource-graph/concepts/query-language
    https://learn.microsoft.com/en-us/azure/governance/resource-graph/samples/starter?tabs=azure-cli
    https://nicolas-yuen.medium.com/getting-started-with-azure-resource-graph-96f42cd0aa29
    https://learn.microsoft.com/en-us/rest/api
#>


    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [Alias('azrs')]
    param(
        [Parameter(Position = 0, HelpMessage = "The HTTP method for the request(e.g., 'GET', 'PATCH', 'POST', 'PUT', 'DELETE', 'HEAD')", ParameterSetName = 'Detailed')]
        [Parameter(Position = 0, HelpMessage = "The HTTP method for the request(e.g., 'GET', 'PATCH', 'POST', 'PUT', 'DELETE', 'HEAD')", ParameterSetName = 'Path')]
        [Parameter(Position = 0, HelpMessage = "The HTTP method for the request(e.g., 'GET', 'PATCH', 'POST', 'PUT', 'DELETE', 'HEAD')", ParameterSetName = 'Uri')]
        [ValidateSet('GET', 'PATCH', 'POST', 'PUT', 'DELETE', 'HEAD')]
        [String]$Method = 'GET',

        [Parameter(Position = 1, HelpMessage = 'Uniform Resource Identifier of the Azure resources. The target resource needs to support Azure AD authentication and the access token is derived according to resource id. If resource id is not set, its value is derived according to built-in service suffixes in current Azure Environment.', ParameterSetName = 'Uri')]
        [uri]$Uri,

        [Parameter(Position = 2, HelpMessage = "Identifier URI specified by the REST API you are calling. It shouldn't be the resource id of Azure Resource Manager", ParameterSetName = 'Uri')]
        [string]$ResourceId,

        [Parameter(Position = 1, HelpMessage = 'Path of target resource URL. Hostname of Resource Manager should not be added.', ParameterSetName = 'Path')]
        [String]$Path,

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'The Azure REST API version', ParameterSetName = 'Detailed')]
        [Alias('Version')]
        [ValidateScript({ if ($_ -match '^\d{4}-\d{2}-\d{2}(-preview|-privatepreview)?$') { $true } else { throw "Failed to validate version [$_]" } })]
        [string]$APIVersion,

        [Parameter(Position = 2, HelpMessage = 'Target Subscription Id', ParameterSetName = 'Detailed')]
        [string]$SubscriptionId,

        [Parameter( Position = 3, HelpMessage = 'Target Resource Group Name', ParameterSetName = 'Detailed')]
        [string]$ResourceGroupName,

        [Parameter(Position = 4, HelpMessage = 'Target Resource Provider Name', ParameterSetName = 'Detailed')]
        [string]$ResourceProviderName,

        [Parameter(Position = 5, HelpMessage = 'Target Resource Type', ParameterSetName = 'Detailed')]
        [string]$ResourceType,

        [Parameter(Position = 6, HelpMessage = 'List of Target Resource Name', ParameterSetName = 'Detailed')]
        [string[]]$Name,

        [Parameter(Position = 7, HelpMessage = 'Request body for POST/PATCH operations', ParameterSetName = 'Detailed')]
        [Parameter(Position = 2, HelpMessage = 'Request body for POST/PATCH operations', ParameterSetName = 'Path')]
        [Parameter(Position = 2, HelpMessage = 'Request body for POST/PATCH operations', ParameterSetName = 'Uri')]
        [Alias('Payload', 'Content')]
        $Body,

        [Parameter(Position = 8, HelpMessage = 'Azure REST API filters to apply', ParameterSetName = 'Detailed')]
        [Object]$Filter,

        [Parameter(Position = 9, HelpMessage = 'Azure REST API properties to include', ParameterSetName = 'Detailed')]
        [string[]]$Select,

        [Parameter(Position = 10, HelpMessage = 'Sorting expression', ParameterSetName = 'Detailed')]
        [string]$OrderBy,

        [Parameter(Position = 11, HelpMessage = 'Page size (max 999 objects per page)', ParameterSetName = 'Detailed')]
        [Parameter(Position = 3, HelpMessage = 'Page size (max 999 objects per page)', ParameterSetName = 'Path')]
        [Parameter(Position = 3, HelpMessage = 'Page size (max 999 objects per page)', ParameterSetName = 'Uri')]
        [ValidateRange(1, 999)]
        [Alias('MaxPageSize')]
        [uint16]$PageSize = 999,

        [Parameter(Position = 12, HelpMessage = 'Delay between requests if throttled in milliseconds', ParameterSetName = 'Detailed')]
        [Parameter(Position = 4, HelpMessage = 'Delay between requests if throttled in milliseconds', ParameterSetName = 'Path')]
        [Parameter(Position = 4, HelpMessage = 'Delay between requests if throttled in milliseconds', ParameterSetName = 'Uri')]
        [ValidateRange(100, 60000)]
        [Alias('WaitTime')]
        [uint16]$ThrottlingDelay = 1000,

        [Parameter(Position = 13, HelpMessage = 'Maximum retry attempts for failed requests when throttled', ParameterSetName = 'Detailed')]
        [Parameter(Position = 5, HelpMessage = 'Maximum retry attempts for failed requests when throttled', ParameterSetName = 'Uri')]
        [Parameter(Position = 5, HelpMessage = 'Maximum retry attempts for failed requests when throttled', ParameterSetName = 'Path')]
        [ValidateRange(1, 10)]
        [uint16]$MaxRetry = 3,

        [Parameter(Position = 14, ParameterSetName = 'Detailed')]
        [Parameter(Position = 6, ParameterSetName = 'Uri')]
        [Parameter(Position = 6, ParameterSetName = 'Path')]
        [ValidateSet('PSObject', 'HashTable', 'Json', 'HttpResponseMessage')]
        [ValidateSet('PSObject', 'HashTable', 'Json', 'HttpResponseMessage')]
        [String]$OutputType = 'PSObject'
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        if ($null -eq (Get-AzAccessToken -EA Ignore)) {
            throw "[$InvocationName] Authenticate first with Azure before using this function"
        }
        # Remove the global variables used to share the results' next link and count
        Remove-Variable -Name '_AzRESTAPINextLink' -Force -EA Ignore -Scope Global -Verbose:$false
        New-Variable -Name '_AzRESTAPINextLink' -Force -EA Ignore -Scope Global -Value '' -Verbose:$false
        $ResultObjectCount = 0
        $RetryCount = 0

        if ($Global:PSDefaultParameterValues.Keys.Count -gt 0) {
            $PSDefaultParameterValues = $Global:PSDefaultParameterValues.Clone()
        }
        else {
            $PSDefaultParameterValues.Clear()
        }

        # Build base URI
        $UriBuilder = [Text.StringBuilder]::new()
        $queryParams = [System.Collections.Generic.List[String]]::new()
        #$null = $UriBuilder.Append('https://management.azure.com')
        switch ($PSCmdlet.ParameterSetName) {
            'Detailed' {
                #$Root = 'subscriptions/{0}/resourceGroups/{1}/providers/{2}/{3}/{4}' -f $SubscriptionId, $ResourceGroupName, $Provider, $ResourceType, $ResourceName
                if ("$SubscriptionId".Trim() -ne '') { $null = $UriBuilder.Append(('/subscriptions/{0}' -f $SubscriptionId)) }
                if ("$ResourceGroupName".Trim() -ne '') { $null = $UriBuilder.Append(('/resourceGroups/{0}' -f $ResourceGroupName)) }
                if ("$ResourceProviderName".Trim() -ne '') { $null = $UriBuilder.Append(('/providers/{0}' -f $ResourceProviderName)) }
                if ("$ResourceType".Trim() -ne '') { $null = $UriBuilder.Append(("/$ResourceType")) }
                if ($Name.Count -gt 0) { $null = $UriBuilder.Append(("/$($Name -join '/')")) }
                [String]$uri = "$($UriBuilder.ToString() -replace '\\+','\')".Trim('/')
                break
            }
            'Path' {
                [String]$uri = "$Path"
                break
            }
            'Uri' {
                [String]$uri = "$Uri" # TODO: Add $ResourceId to the uri
                break
            }
        }

        if ("$APIVersion" -ne '') {
            $queryParams.Add("api-version=$APIVersion")
        }
        else {
            [String]$APIVersion = $uri -replace '.+api-version=([\w-]+).*','$1'
        }
        #$UriBuilder.ToString()
        # Add properties if specified
        if ($Select.Count -gt 0) {
            $queryParams.Add("`$select=$($Select -split ',' -replace ' ' -join ',')")
        }

        # Add filters if specified
        if ($null -ne $PSBoundParameters['Filter']) {
            $queryParams.Add("`$filter=$([System.Web.HttpUtility]::UrlEncode("$($Filter -replace "'+","'")"))")
        }

        # Order properties if specified
        if ("$OrderBy".Trim() -ne '') {
            $queryParams.Add("`$orderby=$OrderBy")
        }

        # Add page size parameter
        <# if ($Method -eq 'GET') {
            if (($Top -gt 0) -and ($Top -lt 999)) {
                # Will exit the loop when the count of results is equal to $Top
                $TopEnabled = $true
                if ($Top -lt $PageSize) {
                    # $Top takes precedence over $PageSize
                    $PageSize = $Top
                }
            }
            if ($PageSize -ne 999) { $queryParams.Add("`$top=$PageSize") }

            if ($Skip -gt 0) {
                $queryParams.Add("`$skip=$Skip")
            }
        } #>

        # Combine query parameters into URI
        if ($queryParams.Count -gt 0) {
            $uri = "$uri`?$($queryParams -join '&')"
        }
        $null = $UriBuilder.Clear()
        $queryParams.Clear()
        Write-Verbose -Message "[$InvocationName] Query: $uri"
        $JsonDepth = 10
        #$JsonDepth = if ($PSVersionTable.PSVersion -ge [version]'6.0.0') { 10 } else { 2 }
    }
    process {
        :RetryLoop do {
            if ("$uri".Trim() -eq '') { return } # Exit the loop if the previous checks did not work
            try {
                Write-Log -Message "[$InvocationName] Making request to: $uri" -Type Debug
                $i = 1
                :UriLoop do {
                    $response = $null
                    if ($Method -eq 'GET') {
                        Write-Log -Message "[$InvocationName] Requesting page $i with $PageSize items" -Type Debug
                    }
                    else {
                        Write-Log -Message "[$InvocationName] Sending request with $Method method" -Type Debug
                    }
                    #Set default parameters for Invoke-AzRestMethod
                    $params = @{
                        Method      = $Method
                        Path        = $uri
                        ErrorAction = 'Stop'
                        Verbose     = $false
                    }
                    # add additional parameters based on method
                    if (($Method -in 'POST', 'PATCH', 'PUT') -and ($null -ne $Body)) {
                        if (($null -ne $Body) -and ($Body.GetType().Name -notmatch 'String')) {
                            $params.Payload = ($Body | ConvertTo-Json -Depth $JsonDepth)
                        }
                        else {
                            $params.Payload = $Body
                        }
                        if ($params.Payload.Length -lt 1000) {
                            Write-Log -Message "[$InvocationName] Request body: $($Body | ConvertTo-Json -Depth $JsonDepth)" -Type Debug
                        }
                        else {
                            Write-Log -Message "[$InvocationName] Request body is too big to be shown ($($body.count))" -Type Debug
                        }
                        $body = $null
                        $null = [System.GC]::GetTotalMemory($true)
                    }
                    #send request to Azure REST API
                    try {
                        $response = Invoke-AzRestMethod @params #-MaxPageSize $PageSize
                        $params.Clear()
                        if (("$($response.StatusCode)" -notlike '20?') -or ($response.Content -match '"(error|code)":')) {
                            throw $response.StatusCode
                        }
                        Write-Log -Message "[$InvocationName] Request successful" -Type Debug
                    }
                    catch {
                        $params.Clear()
                        throw "Request failed with error: $_"
                    }
                    # return the formated result
                    if ($Method -in ('POST','PUT','PATCH') -and ($null -eq $response.Content)) {
                        Write-Log -Message "[$InvocationName] $Method answer delivered" -Type Debug
                        return $response
                    }
                    if ($null -ne $response.Content) {
                        try {
                            if ($response.Content -match '"value":') {
                                $Content = ($response.Content | ConvertFrom-Json).value
                            }
                            else {
                                $Content = $response.Content | ConvertFrom-Json
                            }
                        }
                        catch [ArgumentException] {
                            $Global:Error.RemoveAt(0)
                            $Content = $response.Content
                        }
                    }
                    else { $Content = $response }
                    $ResultObjectCount += ($Content | Measure-Object).Count
                    switch ($OutputType) {
                        'PSObject' {
                            $Content
                            Remove-Variable -Name 'Content' -Force -EA Ignore
                            break
                        }
                        'HashTable' {
                            $ResultHash = @{}
                            foreach ($Property in $response.PsObject.Properties.Name) {
                                $ResultHash["$Property"] = $response.$Property
                            }
                            $ResultHash
                            $ResultHash.Clear()
                            break
                        }
                        'Json' {
                            if ($null -ne $response.Content) { $response.Content }
                            elseif ($null -ne $response) { $response | ConvertTo-Json -Depth $JsonDepth }
                            break
                        }
                        'HttpResponseMessage' {
                            $response
                            break
                        }
                    }
                    Write-Log -Message "[$InvocationName] Retrieved page $i, Now total: $ResultObjectCount items" -Type Debug

                    # Check for next page
                    if (($response.PSObject.Properties.Name -contains 'nextLink') -and ("$($response.nextLink)".Trim() -ne '')) {
                        if ("$Global:_AzRESTAPINextLink" -ne $response.nextLink) {
                            $uri = $response.nextLink
                            # Create a global variable to hold the nextlink
                            Set-Variable -Name '_AzRESTAPINextLink' -Value $uri -Force -Scope Global -EA Ignore
                            Write-Log -Message "[$InvocationName] Next page found: $uri" -Type Debug
                        }
                        else {
                            # The previous nextLink is equal to the current one which indicates a paging loop
                            $Global:_AzRESTAPINextLink = $uri = ''
                            Write-Log -Message "[$InvocationName] Found a paging loop, exiting." -Type Warning
                            $response = $null
                            return
                        }
                    }
                    else {
                        Write-Log -Message "[$InvocationName] No more pages found" -Type Debug
                        $uri = ''
                        $response = $null
                        return
                    }

                    <# if ($TopEnabled -eq $true) {
                        if ($ResultObjectCount -ge $Top) {
                            Write-Log -Message "[$InvocationName] Number of results has been reached, exiting." -Type Debug
                            $uri = ''
                            return
                        }
                        elseif (($ResultObjectCount + $PageSize) -gt $Top) {
                            $NewPageSize = $Top - $ResultObjectCount
                            $Uri = $Uri -replace "`$top=$PageSize", "`$top=$NewPageSize"
                            Write-Log -Message "[$InvocationName] Changing the number of result from $PageSize to ${NewPageSize}: $uri" -Type Debug
                            $PageSize = $NewPageSize
                        }
                    } #>
                    $i++
                } while ("$uri".Trim() -ne '')
                Write-Log -Message "[$InvocationName] Returning array with $ResultObjectCount items" -Type Debug
                $response = $null
            }
            catch {
                if ($response.Content -match '"(error|code)":') {
                    # Converting the json error part of the answer
                    $httpErrorJson = $response.Content | ConvertFrom-Json
                    if ($httpErrorJson.Error) { $httpErrorJson = $httpErrorJson.Error }
                    $StatusCode = $response.StatusCode
                }
                else {
                    $ErrorMessage = $_.Exception.Message
                    $httpErrorJson = $null
                    $StatusCode = $null
                    if ($ErrorMessage -match 'Request failed with error: ') {
                        $StatusCode = $ErrorMessage -replace 'Request failed with error: (\d+.*)','$1'
                    }
                }
                # Exit the function if not authenticated
                if ($ErrorMessage -match 'Authentication needed|User canceled authentication') { throw $ErrorMessage }
                $Error.Clear()
                Write-Log -Message "[$InvocationName] Request failed (Retry attempt $($RetryCount + 1)/$MaxRetry): $ErrorMessage" -Type Warning
                if (($null -eq $StatusCode) -and ($ErrorMessage -match 'HTTP/[\d\.]+\s+(?<StatusCode>\d+)')) {
                    # Parsing the error message to get the http status code (Ex: HTTP/1.1 400 ...)
                    $StatusCode = $Matches['StatusCode']
                }
                $httpErrorDesc = "(ErrorCode $StatusCode) [$($httpErrorJson.code)] $($httpErrorJson.message)" -replace ' \[\]\s+$'
                $RetryMessage = 'Waiting $Delay milliseconds before retrying. '
                if ($RetryCount -eq $MaxRetry) {
                    $RetryMessage = ''
                }
                if (($null -ne $response.Headers) -or ($StatusCode -gt 0)) {
                    # Use switch to handle specific status codes
                    switch ($StatusCode) {
                        429 {
                            # Throttling
                            $RetryAfter = $response.Headers | Where-Object -Property Key -EQ 'Retry-After' | Select-Object -ExpandProperty Value
                            if ($null -ne $RetryAfter) {
                                $Delay = $RetryAfter * 1000
                                Write-Log -Message "[$InvocationName] Throttling detected (429). $($ExecutionContext.InvokeCommand.ExpandString("$RetryMessage"))" -Type Warning
                                Start-Sleep -Milliseconds ($RetryAfter * 1000) # Convert seconds to milliseconds
                            }
                            else {
                                $Delay = [math]::Min(($ThrottlingDelay * ([math]::Pow(2, $RetryCount))), 60000) # Exponential backoff, max 60 seconds
                                Write-Log -Message "[$InvocationName] Throttling detected (429). No Retry-After header found. $($ExecutionContext.InvokeCommand.ExpandString("$RetryMessage"))" -Type Warning
                                Start-Sleep -Milliseconds $Delay
                            }
                            # Function break not needed, will fall through to retry logic below
                            break
                        }
                        { "$_" -in $Script:nonRetryableHttpStatusCodes.Keys } {
                            if (($StatusCode -eq 400) -and ($httpErrorJson.message -match 'The api-version .+ is invalid')) {
                                $APIVersion = "$($httpErrorJson.message)".TrimEnd(".'") -replace ".+The supported versions are '" -split ',' | Select-Object -First 1
                                $uri = "$uri" -replace 'api-version=[\w-]+',"api-version=$APIVersion"
                                Write-Log -Message "[$InvocationName] $($httpErrorJson.message) Using the latest version [$APIVersion]" -Type Warning
                            }
                            else {
                                Write-Log -Message "[$InvocationName] $($Script:nonRetryableHttpStatusCodes["$StatusCode"]) ($StatusCode)." -Type Error
                                # Re-throw to fail immediately
                                throw $httpErrorDesc
                            }
                        }
                        default {
                            # Other HTTP errors - Use generic retry
                            $Delay = [math]::Min(($ThrottlingDelay * ([math]::Pow(2, $RetryCount))), 60000) # Exponential backoff, max 60 seconds
                            Write-Log -Message "[$InvocationName] HTTP error $($StatusCode). $($ExecutionContext.InvokeCommand.ExpandString("$RetryMessage"))" -Type Warning
                            Start-Sleep -Milliseconds $Delay
                            # Function break not needed, will fall through to retry logic below
                            break
                        }
                    }
                }
                else {
                    # Non-HTTP errors (e.g., network issues, DNS resolution) - Use generic retry
                    $Delay = [math]::Min(($ThrottlingDelay * ([math]::Pow(2, $RetryCount))), 60000) # Exponential backoff, max 60 seconds
                    Write-Log -Message "[$InvocationName] Non-HTTP error. $($ExecutionContext.InvokeCommand.ExpandString("$RetryMessage")) Error: $ErrorMessage" -Type Warning
                    Start-Sleep -Milliseconds $Delay
                    # Fall through to retry logic below
                }

                # Increment retry count and check if max retries exceeded ONLY if not already thrown
                $RetryCount++
                if ($RetryCount -ge $MaxRetry) {
                    Write-Log -Message "[$InvocationName] Request failed after $($MaxRetry) retries. Aborting." -Type Error
                    # Throw a specific message or re-throw the last caught error
                    throw "Request failed after $($MaxRetry) retries. Last error: $ErrorMessage"
                }
                # If retries not exceeded and error was potentially retryable (e.g., 429, other HTTP, non-HTTP), the loop will continue
            }
        } while ($RetryCount -le $MaxRetry)

        $response = $null
        Write-Log -Message "[$InvocationName] Request failed after $($MaxRetry) retries. Aborting." -Type Error
        throw "Request failed after $($MaxRetry) retries. $httpErrorDesc" # Re-throw the exception after max retries
    }
    end {
        # End function and report memory usage
        $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
        $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
        Write-Log -Message "[$InvocationName] Function finished. Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)" -Type Debug
    }
}


function Invoke-AzureRequestBatch {
    <#
.SYNOPSIS
    Invoke a Azure REST API request as a batch.

.DESCRIPTION
    Invoke a Azure REST API request as a batch.

    This function encapsulates Invoke-AzRestMethod to process batches and offers multiple parameters to avoid having to build long queries in the uri parameter.
    Batching can be use to enhance the script performances.

    It also handles the common http status codes returned by Invoke-AzRestMethod (see $Script:nonRetryableHttpStatusCodes for the full list):
        200 = Success
        201 = POST success
        204 = PATCH/DELETE success
        400 = Bad request
        403 = Access denied
        404 = Resource not found
        429 = Throttling, will retry a number of times before exiting with an error if unsuccessful
        100 - 199 = Informal
        200 - 299 = Success
        300 - 399 = Redirection
        400 - 499 = Errors, will retry a number of times before exiting with an error if unsuccessful
        500 - 599 = Server errors, will retry a number of times before exiting with an error if unsuccessful

    There are 2 ways of batching requests using this function:
        - All requests point to the same resource => Use the ObjectList containing a list of objects that are either ids or objects with an id property (See EXAMPLE 1)
        - Different resources are queried => Use the HashTable parameter, and the APIVersion (See EXAMPLE 2)

    The function will return a list of objects with the following properties:
        - name = identificator of the request.
            Its value depends on the parameter used (hashtable, objectlist).
                Hashtable => the id is the same as the id provided in the hashtable, it'll otherwise be a number representing the order in which the request was made.
                ObjectList => the id is the same as the object's id.
        - httpStatusCode = http code returned by the request (2xx, 4xx)
        - headers = header returned by the request (OData-Version and Content-Type)
        - content = body of the answer.
            Has a value property representing the object returned by the request (empty if no answer was returned)
        - contentLength = Length of the content represented as a json string

.PARAMETER BatchAPIVersion
    Microsoft Azure REST API version for the batch service (Default is 2020-06-01)

.PARAMETER APIVersion
    Microsoft Azure REST API version

.PARAMETER Method
    API method: GET, POST, PATCH, PUT, DELETE, HEAD.

.PARAMETER Hashtable
    List of requests formated as hashtables with the following properties:
        - (Optinal) name = identificator for the request, can be a string, a guid, or a number
        - httpMethod = Same as the Method parameter
        - url = url of the request (resource, filters, select, count, ...)
        - (Optional) content = body if the request uses the POST, PATCH, or PUT method

    This can be used when batching multiple queries that are using different resources.

.PARAMETER Path
    Path of target resource URL. Hostname of Resource Manager should not be added.

.PARAMETER Filter
    Azure REST API filters to apply.

.PARAMETER Select
    Azure REST API properties to include.

.PARAMETER Body
    Request body for POST/PATCH/PUT operations.

.PARAMETER ObjectList
    Array of objects to process in batches.

.PARAMETER IdProperty
    Input object property to be used as the request id.
    That property name is also to be used in the Path uri prefixed with a $.
    That string will be replaced by each object's id.

.PARAMETER BatchSize
    Batch size (max 20 objects per batch).
    Default is 20.

.PARAMETER WaitTime
    Delay between batches in milliseconds.
    Default is 100.

.PARAMETER MaxRetry
    Maximum retry attempts for failed requests.
    Default is 3.

.PARAMETER DoNotLogErrors
    Requests failing with status 4xx will not be logged.

.EXAMPLE
List the packages of each runtime environment in the Automation Account

    PS C:\> $Params = @{
        APIVersion           = '2024-10-23'
        SubscriptionId       = $SubscriptionId
        ResourceGroupName    = $ResourceGroupName
        ResourceProviderName = 'Microsoft.Automation'
        ResourceType         = 'automationAccounts'
    }

Retrieve the runtime environments for the specified Automation Account
    PS C:\> $RuntimeList = Invoke-AzureRequestSingle @Params -Name $AutomationAccountName,'runtimeEnvironments'

Build the query. Notice the "$name" string (Same as -IdProperty) that will be replaced with the actual value in the batched queries
    PS C:\> $Path = 'subscriptions/{0}/resourceGroups/{1}/providers/{2}/{3}/{4}/runtimeEnvironments/$name/packages' -f $Params.SubscriptionId,$params.ResourceGroupName, $params.ResourceProviderName, $params.ResourceType,$AutomationAccountName

Send the batch request by passing the $RuntimeList variable where each object as a 'name' property which will be used to identify each query
    PS C:\> Invoke-AzureRequestBatch -APIVersion '2024-10-23' -Path $Path -ObjectList $RuntimeList -IdProperty 'name'

.EXAMPLE
List the runbooks and modules for PowerShell 5.1 in the Automation Account

    PS C:\> $APIVersion = '2024-10-23'
    PS C:\> $RootPath = 'subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Automation/automationAccounts/{2}' -f $SubscriptionId, $ResourceGroupName, $AutomationAccountName
    PS C:\> $HashTable = @(
        @{
            name = 'Runbooks'
            httpMethod = 'GET'
            url = '{0}/runbooks?api-version={1}' -f $RootPath, $APIVersion
        },
        @{
            name = 'PS5_Modules'
            httpMethod = 'GET'
            url = '{0}/runtimeEnvironments/PowerShell-5.1/packages?api-version={1}' -f $RootPath, $APIVersion
        },
        @{
            name = 'GalleryLookup'
            httpMethod = 'POST'
            url = '{0}/galleryModuleItems?api-version={1}' -f $RootPath, $APIVersion
            content = @{
                pageLink = ''
                filter   = "ImportExcel"
                orderBy  = '1' # 0=Last updated, 1=Popularity
            }
        }
    )
    PS C:\> Invoke-AzureRequestBatch -HashTable $HashTable


.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-07-15
    VERSION: 1.0.0
    MODIFICATIONS:

    TODO:
        - Batch size can be greater than 20 requests but a status code 202 (Accepted) is returned and the response header includes Retry-After and Location.
          Location can be used to poll the results after the Retry-After delay (in seconds)
        - Handle NextLink response (more than 100 requests)

.LINK
https://maciejporebski.github.io/azure-management-batch-api
https://nsftwr.com/posts/azure-batch-api/

#>


    [CmdletBinding(DefaultParameterSetName = 'SingleResource')]
    [Alias('azrb')]
    param(
        [Parameter(Position = 0, HelpMessage = 'The Azure REST API version', ParameterSetName = 'SingleResource')]
        [Parameter(Position = 0, HelpMessage = 'The Azure REST API version', ParameterSetName = 'Hashtable')]
        [ValidateScript({ if ($_ -match '^\d{4}-\d{2}-\d{2}(-preview|-privatepreview)?$') { $true } else { throw "Failed to validate version [$_]" } })]
        [string]$BatchAPIVersion = '2020-06-01',

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'The Azure REST API version', ParameterSetName = 'SingleResource')]
        [Alias('Version')]
        [ValidateScript({ if ($_ -match '^\d{4}-\d{2}-\d{2}(-preview|-privatepreview)?$') { $true } else { throw "Failed to validate version [$_]" } })]
        [string]$APIVersion,

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'List of requests in the hashtable format including httpMethod,url[,name,content]', ParameterSetName = 'Hashtable')]
        [Hashtable[]]$Hashtable,

        [Parameter(Position = 1, HelpMessage = "The HTTP method for the request(e.g., 'GET', 'PATCH', 'POST', 'PUT', 'DELETE', 'HEAD')", ParameterSetName = 'SingleResource')]
        [ValidateSet('GET', 'PATCH', 'POST', 'PUT', 'DELETE', 'HEAD')]
        [String]$Method = 'GET',

        [Parameter(Position = 3, HelpMessage = 'Azure REST API filters to apply', ParameterSetName = 'SingleResource')]
        [Object]$Path,

        [Parameter(Position = 3, HelpMessage = 'Azure REST API filters to apply', ParameterSetName = 'SingleResource')]
        [Object]$Filter,

        [Parameter(Position = 4, HelpMessage = 'Azure REST API properties to include', ParameterSetName = 'SingleResource')]
        [string[]]$Select,

        [Parameter(Position = 5, HelpMessage = 'Request body for POST/PATCH operations', ParameterSetName = 'SingleResource')]
        [Alias('Payload','Content')]
        $Body,

        [Parameter(Position = 6, Mandatory = $true, HelpMessage = 'Array of objects to process in batches', ParameterSetName = 'SingleResource')]
        [System.Object[]]$ObjectList,

        [Parameter(Mandatory = $true, Position = 7, HelpMessage = 'The property used as a unique id in the query', ParameterSetName = 'SingleResource')]
        [string]$IdProperty,

        [Parameter(Position = 9, HelpMessage = 'Batch size (max 20 objects per batch)', ParameterSetName = 'SingleResource')]
        [Parameter(Position = 2, HelpMessage = 'Batch size (max 20 objects per batch)', ParameterSetName = 'Hashtable')]
        [ValidateRange(1, 20)]
        [int]$BatchSize = 20,

        [Parameter(Position = 10, HelpMessage = 'Delay between batches in milliseconds', ParameterSetName = 'SingleResource')]
        [Parameter(Position = 3, HelpMessage = 'Delay between batches in milliseconds', ParameterSetName = 'Hashtable')]
        [ValidateRange(1, 5000)]
        [int]$WaitTime = 1,

        [Parameter(Position = 11, HelpMessage = 'Delay between requests if throttled in seconds', ParameterSetName = 'SingleResource')]
        [Parameter(Position = 4, HelpMessage = 'Delay between requests if throttled in seconds', ParameterSetName = 'Hashtable')]
        [ValidateRange(1, 60)]
        [uint16]$ThrottlingDelay = 2,

        [Parameter(Position = 12, HelpMessage = 'Maximum retry attempts for failed requests', ParameterSetName = 'SingleResource')]
        [Parameter(Position = 5, HelpMessage = 'Maximum retry attempts for failed requests', ParameterSetName = 'Hashtable')]
        [ValidateRange(1, 10)]
        [int]$MaxRetry = 3,

        [Parameter(ParameterSetName = 'SingleResource')]
        [Parameter(ParameterSetName = 'Hashtable')]
        [Switch]$DoNotLogErrors
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        if ($null -eq (Get-AzAccessToken -EA Ignore)) {
            throw "[$InvocationName] Authenticate first with Azure before using this function"
        }
        $IsSystem = [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem
        $JsonDepth = 10
        #$JsonDepth = if ($PSVersionTable.PSVersion -ge [version]'6.0.0') { 10 } else { 2 }
        $ErrorActionPreference = 'Stop'
        $starttime = [DateTime]::Now

        if ($Global:PSDefaultParameterValues.Keys.Count -gt 0) {
            $PSDefaultParameterValues = $Global:PSDefaultParameterValues.Clone()
        }
        else {
            $PSDefaultParameterValues.Clear()
        }

        try {
            $Retrycount = 0
            $CollectedObjectsCount = 0
            $RetryObjects = [System.Collections.Generic.List[PSCustomObject]]::new()

            # Check execution context
            if ($env:AUTOMATION_ASSET_ACCOUNTID) {
                [Bool]$ManagedIdentity = $true
                Write-Log -Message ('[{0}] Running in Azure Automation context' -f $InvocationName) -Type Debug
            }
            else {
                [Bool]$ManagedIdentity = $false
                Write-Log -Message ('[{0}] Running in Local PowerShell context' -f $InvocationName) -Type Debug
            }
        }
        catch {
            Write-Log -Message ('[{0}] Failed to initialize with error' -f $InvocationName) -Type Error
            throw
        }
    }

    process {
        try {
            $BreakRetryLoop = $false
            :RetryLoop do {
                try {
                    switch ($PSCmdlet.ParameterSetName) {
                        'Hashtable' {
                            $TotalObjects = ($Hashtable | Measure-Object).Count
                        }
                        'SingleResource' {
                            $TotalObjects = ($ObjectList | Measure-Object).Count
                        }
                    }

                    if ($TotalObjects -eq 0) {
                        Write-Log -Message "[$InvocationName] Cannot process an empty request" -Type Warning
                        break RetryLoop
                    }
                    Write-Log -Message "[$InvocationName] Start processing with $TotalObjects objects" -Type Debug
                    $currentObject = 0
                    # Clear RetryObjects at the beginning of each retry loop
                    $RetryObjects.Clear()

                    Write-Log -Message "[$InvocationName] Processing started with $TotalObjects objects" -Type Debug
                    # Start looping all objects and run batches
                    $Index = 0
                    for ($i = 0; $i -lt $TotalObjects; $i += $BatchSize) {
                        try {
                            # Create Requests of id, method and url
                            $batchStart = $i
                            $batchEnd = [Math]::Min($i + $BatchSize - 1, $TotalObjects - 1)
                            $BatchRequestList = $(
                                switch ($PSCmdlet.ParameterSetName) {
                                    'Hashtable' {
                                        $batchObjects = $Hashtable[$batchStart..$batchEnd]
                                        foreach ($Item in $batchObjects) {
                                            # The hashtable must have at least a method and an url property
                                            [String]$Method = ($Item.Method,$Item.httpMethod).Where({ $_ -in ('GET', 'PATCH', 'POST', 'PUT', 'DELETE', 'HEAD') }) | Select-Object -First 1
                                            $Body = ($Item.body,$Item.content,$item.Payload).Where({ "$_".Trim() -ne '' }) | Select-Object -First 1
                                            if (("$Method" -eq '') -or ($null -eq $Item.url)) {
                                                Write-Log -Message "[$InvocationName] Item is missing a parameter: $($Item | ConvertTo-Json -Compress)" -Type Warning
                                                continue
                                            }
                                            # Use the id property provided in the hashtable or an index
                                            if ($null -ne $Item.name) { $ItemId = $Item.name }
                                            else { $ItemId = $Index++ }

                                            # Build the request hashtable for the item
                                            $Req = @{
                                                name       = "$ItemId"
                                                httpMethod = "$Method".ToUpper() # The method needs to be in capital letters
                                                url        = "/$($Item.url)"
                                                content    = $Body
                                            }
                                            $Req
                                        }
                                        break
                                    }
                                    'SingleResource' {
                                        $batchObjects = $ObjectList[$batchStart..$batchEnd]
                                        foreach ($Item in $batchObjects) {
                                            [String]$ItemId = $Item.$IdProperty
                                            if (("$ItemId" -eq '') -and ($null -ne $Item)) {
                                                [String]$ItemId = $Item
                                            }

                                            # Build URL with properties and filters
                                            $url = "/$Path" -replace '/+', '/'

                                            # Add properties if specified
                                            [String[]]$urlParams = $(
                                                "api-version=$APIVersion"
                                                if ($Select.Count -gt 0) {
                                                    "`$select=$($Select -join ',')"
                                                }

                                                # Add filters if specified
                                                if ($null -ne $PSBoundParameters['Filter']) {
                                                    "`$filter=$([System.Web.HttpUtility]::UrlEncode("$($Filter -replace "'+","'")"))"
                                                }
                                            )

                                            # Combine URL parameters
                                            if ($urlParams.Count -gt 0) {
                                                $url = '{0}?{1}' -f $url, ($urlParams -join '&')
                                            }

                                            $req = @{
                                                name       = "$ItemId"
                                                httpMethod = "$Method".ToUpper() # The method needs to be in capital letters
                                                url        = "$url" -replace "\`$$IdProperty\b",$ItemId
                                            }
                                            if ($Method -in ('PATCH', 'POST', 'PUT')) {
                                                $req.content = $Body
                                            }
                                            $Req
                                        }
                                        break
                                    }
                                }
                            )
                            Write-Log -Message "[$InvocationName] Created batch for items $($i) to $([Math]::Min($i + $BatchSize, $TotalObjects)) of $TotalObjects total items" -Type Debug
                        }
                        catch {
                            Write-Log -Message ('[{0}] Failed to create batch with error' -f $InvocationName) -Type Error
                            throw $_
                        }

                        # Send the requests in a batch
                        try {
                            $Params = @{
                                Method  = 'POST'
                                Uri     = 'https://management.azure.com/batch?api-version={0}' -f $BatchAPIVersion
                                Payload = @{ 'requests' = @($BatchRequestList) } | ConvertTo-Json -Depth $JsonDepth
                                Verbose = $false
                            }
                            $responses = Invoke-AzRestMethod @Params
                            if ($responses.StatusCode -notlike '20?') {
                                throw "Status code is $($responses.StatusCode)"
                            }
                            Write-Log -Message ('[{0}] Successfully sent the request' -f $InvocationName) -Type Debug
                        }
                        catch {
                            if ($responses.Content -match '"(error|code)":') {
                                # Converting the json error part of the answer
                                $httpErrorJson = $responses.Content | ConvertFrom-Json
                                if ($httpErrorJson.Error) { $httpErrorJson = $httpErrorJson.Error }
                                $StatusCode = $responses.StatusCode
                                $ErrorMessage = $httpErrorJson.message
                            }
                            else {
                                $ErrorMessage = $_.Exception.Message
                                $httpErrorJson = $null
                                $StatusCode = $null
                                if ($ErrorMessage -match 'Request failed with error: ') {
                                    $StatusCode = $ErrorMessage -replace 'Request failed with error: (\d+.*)'
                                }
                            }
                            Write-Log -Message ('[{0}] Failed to send batch request with error: {1}' -f $InvocationName, $ErrorMessage) -Type Error
                            if (("$ErrorMessage" -match 'Authentication') -or ($httpErrorJson.code -match 'Authentication')) { throw "$ErrorMessage" }
                            throw $_
                        }

                        # Process the responses and verify status
                        $ResponseStatusList = ($responses.Content | ConvertFrom-Json).responses | Group-Object -Property httpStatusCode
                        $responses = $null # Memory management
                        $ThrottlingDetected = ($ResponseStatusList.Name -contains 429) -eq $true
                        foreach ($response in $ResponseStatusList) {
                            $CurrentObject += $response.Count
                            $ResponseStatus = $response.Name
                            $ResponseItems = $response.group
                            $ResponseIdList = $ResponseItems.name -join ', '
                            if ((($ResponseStatus -ge 100) -and ($ResponseStatus -lt 400)) -or ($ResponseStatus -in $Script:nonRetryableHttpStatusCodes.Keys)) {
                                # Return response items in case of success or non retryable error
                                $ResponseItems
                            }
                            $ErrorCode = ''
                            if (($ResponseStatus -ge 400) -and ($ResponseStatus -lt 600)) {
                                [String]$ErrorCode = "(Status: $ResponseStatus) [$($responseitems.content.error | Select-Object -Property Code,Message -Unique | ConvertTo-Json -Compress)]" -replace ' \[\]\s+$'
                            }
                            try {
                                switch ($ResponseStatus) {
                                    200 {
                                        # GET success
                                        $CollectedObjectsCount += $response.Count
                                        Write-Log -Message "[$InvocationName] Successfully processed GET for $($response.Count) objects: $ResponseIdList" -Type Debug
                                        break
                                    }
                                    201 {
                                        # POST success
                                        $CollectedObjectsCount += $response.Count
                                        Write-Log -Message "[$InvocationName] Successfully processed POST for $($response.Count) objects: $ResponseIdList" -Type Debug
                                        break
                                    }
                                    204 {
                                        # PATCH/DELETE success
                                        $CollectedObjectsCount += $response.Count
                                        Write-Log -Message "[$InvocationName] Successfully processed $Method for $($response.Count) objects: $ResponseIdList" -Type Debug
                                        break
                                    }
                                    429 {
                                        $ResponseItems | ForEach-Object { $null = $RetryObjects.Add($_) }
                                        Write-Log -Message "[$InvocationName] (Status: $ResponseStatus) Throttling occurred for $($response.Count) objects: $ResponseIdList"
                                        break
                                    }
                                    { "$_" -in $Script:nonRetryableHttpStatusCodes.Keys } {
                                        if ($DoNotLogErrors.IsPresent -eq $false) {
                                            Write-Log -Message "[$InvocationName] $($Script:nonRetryableHttpStatusCodes["$StatusCode"]) [$($ErrorCode)] for $($response.Count) objects: $ResponseIdList" -Type Error
                                            # Re-throw the original exception to signal failure to the caller
                                            throw
                                        }
                                        break
                                    }
                                    { $_ -ge 100 -and $_ -lt 200 } {
                                        # Informal
                                        Write-Log -Message "[$InvocationName] (Status: $ResponseStatus) Unexpected informal code for $($response.Count) objects: $ResponseIdList"
                                        break
                                    }
                                    { $_ -ge 200 -and $_ -lt 300 } {
                                        # Success
                                        Write-Log -Message "[$InvocationName] (Status: $ResponseStatus) Unexpected success code for $($response.Count) objects: $ResponseIdList"
                                        break
                                    }
                                    { $_ -ge 300 -and $_ -lt 400 } {
                                        # Redirection
                                        Write-Log -Message "[$InvocationName] (Status: $ResponseStatus) Unexpected redirection code for $($response.Count) objects: $ResponseIdList" -Type Warning
                                        break
                                    }
                                    { $_ -ge 400 -and $_ -lt 500 } {
                                        # Errors
                                        $ResponseItems | ForEach-Object { $null = $RetryObjects.Add($_) }
                                        Write-Log -Message "[$InvocationName] (Status: $ResponseStatus) Unexpected error code [$ErrorCode] for $($response.Count) objects: $ResponseIdList" -Type Error
                                        break
                                    }
                                    { $_ -ge 500 -and $_ -lt 600 } {
                                        # Server error
                                        $ResponseItems | ForEach-Object { $null = $RetryObjects.Add($_) }
                                        Write-Log -Message "[$InvocationName] (Status: $ResponseStatus) Unexpected server error [$ErrorCode] for $($response.Count) objects: $ResponseIdList" -Type Error
                                        break
                                    }
                                }
                            }
                            catch {
                                Write-Log -Message ('[{0}] Failed to process response' -f $InvocationName) -Type Error
                                continue
                            }
                        }
                        $ResponseStatusList = $null # Memory management
                        # Handle throttling and progress
                        try {
                            # Show progress if not running in automation
                            if (($ManagedIdentity -eq $false) -and ($IsSystem -eq $false)) {
                                # Calculate progress and time estimates
                                $ElapsedTime = New-TimeSpan -Start $starttime -End (Get-Date)
                                $timeLeft = $(
                                    if ($CurrentObject -gt 0) {
                                        [TimeSpan]::FromMilliseconds(($ElapsedTime.TotalMilliseconds / $CurrentObject) * ($TotalObjects - $CurrentObject)) # time per object * remaining objects
                                    }
                                    else {
                                        [TimeSpan]::Zero
                                    }
                                )
                                $WPParams = @{
                                    Activity        = "$($MyInvocation.MyCommand.Name) processing requests"
                                    Status          = '{0}/{1} | Est. Time: {2:hh}:{2:mm}:{2:ss} | Throttled: {3} | Retry: {4}/{5}' -f $CurrentObject, $TotalObjects, $timeLeft, $RetryObjects.Count, $Retrycount, $MaxRetry
                                    PercentComplete = ([math]::ceiling(($CurrentObject / $TotalObjects) * 100))
                                    #SecondsRemaining = [int]$timeLeft.TotalSeconds
                                }
                                Write-Progress @WPParams
                            }

                            # Handle throttling with exponential backoff
                            $throttledResponses = $RetryObjects | Where-Object -Property status -EQ 429
                            if (($ThrottlingDetected -eq $true) -and ($throttledResponses | Measure-Object).Count -gt 0) {
                                [uint32]$recommendedWait = ($throttledResponses.headers | Where-Object -Property Key -EQ 'Retry-After' | Select-Object -ExpandProperty Value | Measure-Object -Maximum).Maximum
                                if ($recommendedWait -eq 0) { $recommendedWait = $ThrottlingDelay }
                                $backoffWait = [math]::Min($recommendedWait + ($Retrycount * 2), 60) # Max 60 second wait
                                Write-Log -Message "[$InvocationName] Throttling detected, waiting $backoffWait seconds (Recommended [$recommendedWait] | Retry [$Retrycount])" -Type Warning
                                Start-Sleep -Seconds $backoffWait
                            }
                            else {
                                # Wait the specified amount of time between batches
                                Start-Sleep -Milliseconds $WaitTime
                            }
                        }
                        catch {
                            Write-Log -Message ('[{0}] Batch failed to handle throttling' -f $InvocationName) -Type Error
                            throw
                        }
                    }

                    # Handle retries
                    if (($RetryObjects.Count -gt 0) -and ($MaxRetry -gt 0)) {
                        $Retrycount++
                        if ($MaxRetry -eq 1) { $BreakRetryLoop = $true }
                        else { $MaxRetry-- }
                        Write-Log -Message "[$InvocationName] Starting retry $Retrycount with $($RetryObjects.Count) objects"
                        # The objects to retry are the ones that had errors
                        switch ($PSCmdlet.ParameterSetName) {
                            'Hashtable' {
                                $TotalObjects = ($Hashtable | Measure-Object).Count
                                $ClonedHashTable = $Hashtable.Clone()
                                [Hashtable[]]$Hashtable = $RetryObjects | ForEach-Object { $ClonedHashTable | Where-Object -Property name -EQ $_.name }
                            }
                            'SingleResource' {
                                $ObjectList = $RetryObjects | ForEach-Object { $ObjectList | Where-Object -Property name -EQ $_.name }
                            }
                        }
                    }
                }
                catch {
                    Write-Log -Message ('[{0}] Failed in retry loop' -f $InvocationName) -Type Error
                    throw
                }
            } while (($RetryObjects.Count -gt 0) -and ($MaxRetry -gt 0) -and ($BreakRetryLoop -eq $false))

            if ($TotalObjects -gt 0) {
                Write-Log -Message "[$InvocationName] Successfully processed $CollectedObjectsCount objects" -Type Debug
            }
        }
        catch {
            Write-Log -Message ('[{0}] Function failed in main process block with error' -f $InvocationName) -Type Error
            throw $_
        }
    }
    end {
        if (($ManagedIdentity -eq $false) -and ($IsSystem -eq $false)) {
            Write-Progress -Activity $WPParams.Activity -Completed -PercentComplete 100 -EA Ignore
        }
        # End function and report memory usage
        $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
        $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
        Write-Log -Message "[$InvocationName] Function finished. Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)" -Type Debug
        if ($RetryObjects.Count -gt 0) {
            $RetryObjects # Return the failure results
            if ($DoNotLogErrors.IsPresent -eq $false) {
                throw "Failed to process $($RetryObjects.Count) objects"
            }
        }
    }
}
#endregion Invoke-AzureRequest


#region EntraId

#region EntraId users

function Get-EntraIdSignInLog {
    <#
.SYNOPSIS
    Get the sign in logs for a user, a device, or by using a correlationid.

.DESCRIPTION
    Get the sign in logs for a user, a device, or by using a correlationid.

    The results are sorted by date from the most recent to the older.

.PARAMETER UserId
    id of the user object.

.PARAMETER userPrincipalName
    UPN of the user, can be partial on the left side. (Ex: givenane.surname without the @domain.com part)

.PARAMETER CorrelationId
    CorrelationId as shown in the error message.

.PARAMETER DeviceId
    id of the directory object in Entra Id (id property). Do not use the Entra Id device id.

.PARAMETER DeviceName
    Name of the device object in Entra Id, can be partial on the left side.

.PARAMETER Interactivity
    A sign-in log can be one of the following: Interactive, NonInteractive.
    Interactivity can be either one or 'both'.

.PARAMETER Last
    This parameter can be used to return only the last x logs.

.PARAMETER Before
    Return the sign-in logs before the specified date.

.PARAMETER After
    Return the sign-in logs after the specified date.

.PARAMETER AdditionalFilter
    Additional filter that can be used to filter the results even more using properties that are not natively available in the function.
    (Ex:  appDisplayName, clientAppUsed, status/errorCode, ...)

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-10-08
    MODIFICATIONS:

.LINK
    https://learn.microsoft.com/en-us/graph/api/signin-list?view=graph-rest-1.0&tabs=http
    https://learn.microsoft.com/en-us/graph/api/signin-list?view=graph-rest-beta&tabs=http
    https://blogs.aaddevsup.xyz/2022/08/using-ms-graph-to-get-both-interactive-and-non-interactive-sign-in-events-log/
    https://learn.microsoft.com/en-us/graph/api/signin-list?view=graph-rest-beta&tabs=http#example-3-retrieve-the-first-10-sign-ins-where-the-signineventtype-is-not-interactiveuser-starting-with-the-latest-sign-in

.EXAMPLE
    PS C:\>


.EXAMPLE
    PS C:\>
#>


    [CmdletBinding(DefaultParameterSetName = 'ByUserId')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByUserId')]
        [Alias('id')]
        [String]$UserId,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByUserName')]
        [String]$userPrincipalName,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByCorrelationId')]
        [String]$CorrelationId,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByDeviceId')]
        [Alias('AzureADDeviceId')]
        [String]$DeviceId,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByDeviceName')]
        [Alias('displayName')]
        [String]$DeviceName,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByUserId')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByUserName')]
        [Parameter(Position = 1, ParameterSetName = 'ByDeviceId')]
        [Parameter(Position = 1, ParameterSetName = 'ByDeviceName')]
        [ValidateSet('Interactive', 'NonInteractive', 'Both')]
        [String]$Interactivity,

        [Parameter(Position = 2, ParameterSetName = 'ByUserId')]
        [Parameter(Position = 2, ParameterSetName = 'ByUserName')]
        [Parameter(Position = 2, ParameterSetName = 'ByDeviceId')]
        [Parameter(Position = 2, ParameterSetName = 'ByDeviceName')]
        [Int]$Last = 1,

        [Parameter(Position = 3, ParameterSetName = 'ByUserId')]
        [Parameter(Position = 3, ParameterSetName = 'ByUserName')]
        [Parameter(Position = 3, ParameterSetName = 'ByDeviceId')]
        [Parameter(Position = 3, ParameterSetName = 'ByDeviceName')]
        [datetime]$Before,

        [Parameter(Position = 4, ParameterSetName = 'ByUserId')]
        [Parameter(Position = 4, ParameterSetName = 'ByUserName')]
        [Parameter(Position = 4, ParameterSetName = 'ByDeviceId')]
        [Parameter(Position = 4, ParameterSetName = 'ByDeviceName')]
        [datetime]$After,

        [Parameter(Position = 5, ParameterSetName = 'ByUserId')]
        [Parameter(Position = 5, ParameterSetName = 'ByUserName')]
        [Parameter(Position = 5, ParameterSetName = 'ByDeviceId')]
        [Parameter(Position = 5, ParameterSetName = 'ByDeviceName')]
        [String]$AdditionalFilter
    )

    process {
        $GRParams = @{
            APIVersion = 'beta'
            Resource   = 'auditLogs/signIns'
            OrderBy    = 'createdDateTime desc'
        }

        if ($Last -gt 0) {
            $GRParams.Top = $Last
        }
        [String]$Filter = $(
            switch ($PSCmdlet.ParameterSetName) {
                'ByUserId' {
                    "UserId eq '$UserId'"
                    break
                }
                'ByUserName' {
                    "startswith(userPrincipalName, '$userPrincipalName')"
                    break
                }
                'ByDeviceId' {
                    "deviceDetail/deviceId eq '{0}'" -f $DeviceId
                    break
                }
                'ByDeviceName' {
                    "startswith(deviceDetail/displayName, '{0}')" -f $deviceName
                    break
                }
            }
            switch ($Interactivity) {
                'Interactive' {
                    "signInEventTypes/any(t: t eq 'interactiveUser')"
                    break
                }
                'NonInteractive' {
                    "signInEventTypes/any(t: t ne 'interactiveUser')"
                    break
                }
                'Both' {
                    "(signInEventTypes/any(t: t ne 'interactiveUser') or signInEventTypes/any(t: t eq 'interactiveUser'))"
                    break
                }
            }
            if ("$CorrelationId".Trim() -ne '') {
                "correlationId eq '$CorrelationId'"
            }
            if ("$AdditionalFilter".Trim() -ne '') {
                $AdditionalFilter
            }
            if ($null -ne $PSBoundParameters['Before']) {
                'createdDateTime le {0}' -f "$($Before.ToUniversalTime().ToString('s'))Z"
            }
            if ($null -ne $PSBoundParameters['After']) {
                'createdDateTime gt {0}' -f "$($After.ToUniversalTime().ToString('s'))Z"
            }
        ) -join ' and '

        if ($Filter -ne '') {
            $GRParams.Filter = $Filter
        }
        Write-Verbose -Message "[$InvocationName] Quering sign-in logs using the following parameters: `r`n$($GRParams | ConvertTo-Json)"
        Invoke-MgGraphRequestSingle @GRParams <# |
            Select-Object -Property id,
            @{L = 'createdDateTime';e = {
                    $CreatedDate = ([datetime]$_.createdDateTime)
                    switch ($CreatedDate.kind) {
                        'Local' {
                            $CreatedDate.ToUniversalTime()
                        }
                        Default {
                            $CreatedDate.ToLocalTime()
                        }
                    }
                }
            },
            UserDisplayName,
            userPrincipalName,
            userId,
            appDisplayName,
            IPAddress,
            clientAppUsed,
            isInteractive,
            @{l = 'Type'; e = { $_.signInEventTypes -join '|' } },
            authenticationRequirement,
            @{l = 'status'; e = { if ($_.Status.ErrorCode -ne 0) { "Failure ($($_.Status.ErrorCode))" } else { 'Success' } } },
            @{l = 'device'; e = { $_.deviceDetail.DisplayName } },
            @{l = 'location'; e = { "$($_.location.city) ($($_.location.countryOrRegion))" } } #>
    }
    end {
        $null = [System.GC]::GetTotalMemory('forcefullcollection')
    }
}
#endregion EntraId users


#region EntraId groups
function Get-EntraIdGroupInfo {
    <#
.SYNOPSIS
    Get information about a group.

.DESCRIPTION
    Get information about a group (properties, status, member count).

    By default, only the following properties are returned:
        id = id of the group
        status = Active/Deleted/Soft-deleted
        displayName = Name of the group

    The count of members of each group can be returned by using -MembersCount.
    Also if a group was deleted less than 30 days ago, its properties can be retrieved by using -QuerySoftDeletedGroup.
    See https://learn.microsoft.com/en-us/graph/api/directory-deleteditems-list

.PARAMETER id
    Id of the group directory object in Entra Id.

.PARAMETER Property
    Group properties to be returned.

.PARAMETER MembersCount
    Add the members count to the results.

.PARAMETER OwnersCount
    Add the owners count to the results.

.PARAMETER OwnersList
    Add the owners list to the results.

.PARAMETER APIVersion
    Graph API version to be used.

.PARAMETER QuerySoftDeletedGroup
    Try to find the deleted groups in the deleted items list.

.EXAMPLE
Return the id, status and displayName of the group with the specified id.

    PS C:\> Get-EntraIdGroupInfo -id '62c50afe-366c-4e8c-953d-43ce6efad82e'

.EXAMPLE
Return the id, status, displayName, and membershiprule of the group with the specified id and look for any deleted group in the deleted items list

    PS C:\> Get-EntraIdGroupInfo -id '69b00000-f697-48e7-a81a-81c44eccb120', '62c50afe-366c-4e8c-953d-43ce6efad82e' -OwnersCount -MembersCount -Property 'displayName','membershiprule' -QuerySoftDeletedGroup

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-02-02
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [Alias('groupId')]
        [String[]]$id,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [String[]]$Property = 'displayName',

        [Switch]$MembersCount,

        [Switch]$OwnersCount,

        [Switch]$OwnersList,

        [Parameter(Position = 2)]
        [ValidateSet('v1.0', 'beta')]
        [String]$APIVersion = 'v1.0',

        [Switch]$QuerySoftDeletedGroup
    )

    begin {
        #$InvocationName = $MyInvocation.MyCommand.Name
        [String[]]$Property = $Property + 'id' | Select-Object -Unique
    }
    process {
        [String[]]$Id = $Id | Select-Object -Unique
        $GroupHash = $(
            foreach ($gid in $id) {
                @{
                    id     = "$gid"
                    method = 'GET'
                    url    = 'groups/{0}?$Select={1}' -f "$gid",($Property -join ',')
                }
                if ($MembersCount.IsPresent) {
                    @{
                        id      = "MembersCount_$gid"
                        method  = 'GET'
                        url     = 'groups/{0}/members/$count' -f "$gid"
                        headers = @{'ConsistencyLevel' = 'eventual' }
                    }
                }
                if ($OwnersList.IsPresent) {
                    @{
                        id     = "Owners_$gid"
                        method = 'GET'
                        url    = 'groups/{0}/owners?$select=userPrincipalName' -f "$gid"
                    }
                }
                elseif ($OwnersCount.IsPresent) {
                    @{
                        id      = "OwnersCount_$gid"
                        method  = 'GET'
                        url     = 'groups/{0}/owners/$count' -f "$gid"
                        headers = @{'ConsistencyLevel' = 'eventual' }
                    }
                }
            }
        )

        $GroupInfoBatch = Invoke-MgGraphRequestBatch -APIVersion $APIVersion -Hashtable $GroupHash -DoNotLogErrors -ErrorAction Stop | Convert-PSObjectArrayToHashTable -idProperty id -Verbose:$false

        [String[]]$UnknownGroups = ($GroupInfoBatch.values | Where-Object -Property Status -NE 200).id
        $SoftDeletedGroups = @{}
        if (($QuerySoftDeletedGroup.IsPresent) -and ($UnknownGroups.Count -gt 0)) {
            $SoftDeletedGroups = Invoke-MgGraphRequestBatch -APIVersion $APIVersion -Resource 'directory/deletedItems' -ObjectList $UnknownGroups -Select $Property -DoNotLogErrors | Convert-PSObjectArrayToHashTable -idProperty id -Verbose:$false
        }

        foreach ($GroupId in $Id) {
            $GroupInfo = $GroupInfoBatch["$GroupId"]
            [String]$Status = $(
                switch ($GroupInfo.status) {
                    200 { 'Active';break }
                    404 {
                        $SoftDeleted = $SoftDeletedGroups["$GroupId"]
                        if (($QuerySoftDeletedGroup.IsPresent) -and ($SoftDeleted.Status -eq 200)) {
                            $GroupInfo = $SoftDeleted
                            'Soft-deleted'
                        }
                        else {
                            'Deleted'
                        }
                        break
                    }
                    default { "Unknown ($_)" }
                }
            )
            $Group = [PSCustomObject]@{
                id     = $GroupId
                status = $Status
            }

            foreach ($PropertyName in $Property) {
                if ($PropertyName -eq 'id') { continue }
                $Group | Add-Member -MemberType NoteProperty -Name $PropertyName -Value $GroupInfo.body."$PropertyName" -Force
            }

            if ($MembersCount.IsPresent) {
                $MembersCountBody = $GroupInfoBatch["MembersCount_$GroupId"].body
                if ($null -ne $MembersCountBody.error) { $Value = -1 }
                else { [int]$Value = $MembersCountBody }
                $Group | Add-Member -MemberType NoteProperty -Name 'MembersCount' -Value $Value -Force
            }
            if ($OwnersList.IsPresent) {
                $OwnersListBody = $GroupInfoBatch["Owners_$GroupId"].body
                if ($null -ne $OwnersListBody.error) { [String[]]$Value = @() }
                else { [String[]]$Value = $OwnersListBody.value.userPrincipalName }
                if ($OwnersCount.IsPresent) {
                    $Group | Add-Member -MemberType NoteProperty -Name 'OwnersCount' -Value $Value.Count -Force
                }
                $Group | Add-Member -MemberType NoteProperty -Name 'Owners' -Value $Value -Force
            }
            elseif ($OwnersCount.IsPresent) {
                $OwnersCountBody = $GroupInfoBatch["OwnersCount_$GroupId"].body
                if ($null -ne $OwnersCountBody.error) { $Value = -1 }
                else { [int]$Value = $OwnersCountBody }
                $Group | Add-Member -MemberType NoteProperty -Name 'OwnersCount' -Value $Value -Force
            }
            $Group
        }
    }
}


function Get-EntraIdGroupMembership {
    <#
.SYNOPSIS
    Get the members of the groups specified in the parameters.

.DESCRIPTION
    Get the members of the groups specified in the parameters.

    The function returns the list of members with the following properties:
        - GroupName: name of the group
        - GroupId: id of the group directory object
        - List of properties specified in the parameters

.PARAMETER id
    Id of the group directory object in Entra Id.

.PARAMETER Name
    Name of the group directory object in Entra Id.

.PARAMETER Type
    Type of members to return (Device, User, or Group).

.PARAMETER PropertyList
    Member properties (Device, User) to return.
    By default, only the id of the directory object is returned.

.PARAMETER Recurse
    List the nested members as well.

.PARAMETER APIVersion
    "beta" can be specified when some properties cannot be retrieved in "v1.0".

.EXAMPLE
Get the device members of the 3 groups named Group1,Group2, and Group3.

    PS C:\> Get-EntraIdGroupMembership -Name 'Group1','Group2','Group3' -Type device -PropertyList 'id','displayName','deviceid'

.EXAMPLE
Get the user members of the 3 groups named Group1,Group2, and Group3.

    PS C:\> Get-EntraIdGroupMembership -Name 'Group1','Group2','Group3' -Type user -PropertyList 'id','displayName','userPrincipalName'

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-09-29
    VERSION: 1.1.0
    MODIFICATIONS:
        (2026-03-26) M-A ROBIN: Add the Recurse and APIVersion parameter

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [String[]]$Id,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [Alias('GroupName')]
        [String[]]$Name,

        [Parameter(Position = 1, ParameterSetName = 'ById')]
        [Parameter(Position = 1, ParameterSetName = 'ByName')]
        [ValidateSet('All', 'Device', 'User', 'Group')]
        [String]$Type = 'All',

        [Parameter(Position = 2, ParameterSetName = 'ById')]
        [Parameter(Position = 2, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [String[]]$PropertyList = 'id',

        [Parameter(ParameterSetName = 'ById')]
        [Parameter(ParameterSetName = 'ByName')]
        [Alias('Transitive')]
        [Switch]$Recurse,

        [Parameter(Position = 3, ParameterSetName = 'ById')]
        [Parameter(Position = 3, ParameterSetName = 'ByName')]
        [ValidateSet('v1.0', 'beta')]
        [String]$APIVersion = 'v1.0'
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        $Query = 'members'
        if ($Recurse.IsPresent) {
            $Query = 'transitiveMembers'
        }
    }
    process {
        $GRParams = @{
            Resource = 'groups'
            Select   = 'id', 'displayName'
        }
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $GroupList = Invoke-MgGraphRequestSingle @GRParams -Filter "displayName in ('$($Name -join "','")')"
        }
        else {
            $GroupList = (Invoke-MgGraphRequestBatch @GRParams -ObjectList $id).Body
        }

        if (($GroupList | Measure-Object).Count -eq 0) {
            Write-Warning -Message "[$InvocationName] Could not find any group using the specified parameters (id [$($Id -join ',')] | Name [$($Name -join ', ')])"
            return
        }

        if (($GroupList | Measure-Object).Count -eq 1) {
            $Resource = 'groups/{0}/{1}' -f $GroupList.id, $Query
            if ($Type -in ('Device','User','Group')) {
                $Resource = 'groups/{0}/{1}/microsoft.graph.{2}' -f $GroupList.id, $Query, $Type.ToLower()
            }
            Invoke-MgGraphRequestSingle -Resource $Resource -Select $PropertyList -APIVersion $APIVersion |
                Select-Object -Property (
                    @(
                        @{Label = 'GroupName'; Expression = { $GroupList.DisplayName } },
                        @{Label = 'GroupId'; Expression = { $GroupList.id } }
                    ) +
                    $PropertyList
                )
        }
        else {
            $GRParams = @{
                Resource   = 'groups'
                ObjectList = $GroupList
                Query      = $Query
                Select     = $PropertyList
                APIVersion = $APIVersion
            }
            if ($Type -in ('Device','User','Group')) {
                $GRParams.Query = '{0}/microsoft.graph.{1}' -f $Query, $Type.ToLower()
            }
            $GroupMembership = Invoke-MgGraphRequestBatch @GRParams
            $(
                foreach ($GroupItem in $GroupMembership) {
                    $GroupName = $GroupList | Where-Object -Property id -EQ $GroupItem.Id | Select-Object -ExpandProperty displayName
                    $(
                        $GroupItem.body.value
                        if ($GroupItem.body.'@odata.nextlink') {
                            Invoke-MgGraphRequestSingle -SkipToken $GroupItem.body.'@odata.nextlink'
                        }
                    ) |
                        Select-Object -Property (@(@{Label = 'GroupName'; Expression = { $GroupName } }, @{Label = 'GroupId'; Expression = { $GroupItem.id } }) + $PropertyList)
                }
            )
        }
    }
}


function New-EntraIdGroup {
    <#
.SYNOPSIS
    Create an Entra Id security group.

.DESCRIPTION
    Create an Entra Id security group.

    The new group can either be a dynamic one or assigned one.
    By defaut, the owner will be set to the current user.

    When creating an assigned group, the id of the members can be specified in the parameters.
    Otherwise, the Add-EntraIdGroupMember function can be used to add the members later.

.PARAMETER DisplayName
    Name of the group.

.PARAMETER Description
    Description of the group.

.PARAMETER MembershipRule
    String representing the dynamic query membership rule.

.PARAMETER Members
    List of ids representing the members of the group.

.PARAMETER MemberType
    Type of the new members (Device, User, or Group).

.PARAMETER Owner
    List of owners (id).
    By default the owner will be set to the current user (me).

.PARAMETER isAssignableToRole
    Define if Azure/Entra roles can be assigned to the group.

.EXAMPLE
    PS C:\> New-EntraIdGroup

.EXAMPLE
    PS C:\> New-EntraIdGroup

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-09-28
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Dynamic')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Assigned')]
        [String]$DisplayName,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Dynamic')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Assigned')]
        [String]$Description,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'Dynamic')]
        [Alias('DynamicQuery')]
        [String]$MembershipRule,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'Assigned')]
        [AllowEmptyCollection()]
        [String[]]$Members,

        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'Assigned')]
        [ValidateSet('User', 'Device', 'Group')]
        [String]$MemberType,

        [Parameter(Position = 3, ParameterSetName = 'Dynamic')]
        [Parameter(Position = 4, ParameterSetName = 'Assigned')]
        [AllowEmptyCollection()]
        [String[]]$Owner,

        [Parameter(ParameterSetName = 'Dynamic')]
        [Parameter(ParameterSetName = 'Assigned')]
        [switch]$isAssignableToRole
    )

    if ($Global:PSDefaultParameterValues.Keys.Count -gt 0) {
        $PSDefaultParameterValues = $Global:PSDefaultParameterValues.Clone()
    }
    else {
        $PSDefaultParameterValues.Clear()
    }

    $InvocationName = $MyInvocation.MyCommand.Name

    $GroupExists = $true
    $ExistingGroup = Invoke-MgGraphRequestSingle -Resource 'groups' -Filter "DisplayName eq '$DisplayName'"
    if ($null -eq $ExistingGroup) {
        $GroupExists = $false
        Write-Log -Message "[$InvocationName] Creating missing $($PSCmdlet.ParameterSetName) group [$DisplayName]"
        $GroupParam = @{
            displayName        = $DisplayName
            description        = "$Description"
            securityEnabled    = $true
            isAssignableToRole = $isAssignableToRole.IsPresent
            mailEnabled        = $false
            mailNickname       = (New-Guid).Guid.Substring(0, 10)
        }
        $GroupParam.'Owners@odata.bind' = [String[]]$(
            foreach ($OwnerId in $Owner) {
                if (($OwnerId -eq 'me') -and ((Get-MgContext).AuthType -in ('Delegated', 'UserProvidedAccessToken'))) {
                    'https://graph.microsoft.com/v1.0/me'
                }
                elseif ($OwnerId -ne 'me') {
                    'https://graph.microsoft.com/v1.0/users/{0}' -f $OwnerId
                }
            }
        )
        if (($GroupParam.'Owners@odata.bind' | Measure-Object).Count -eq 0) {
            $GroupParam.Remove('Owners@odata.bind')
        }
        switch ($PSCmdlet.ParameterSetName) {
            'Dynamic' {
                $GroupParam.GroupTypes = @('DynamicMembership')
                $GroupParam.MembershipRule = "$MembershipRule"
                $GroupParam.membershipRuleProcessingState = 'On'
            }
            'Assigned' {
                $GroupParam.GroupTypes = @()
            }
        }
        $ExistingGroup = Invoke-MgGraphRequestSingle -Method 'POST' -Resource 'groups' -Body $GroupParam
    }
    else {
        Write-Log -Message "[$InvocationName] Group [$DisplayName] already exists"
    }

    if ($PSCmdlet.ParameterSetName -eq 'Assigned') {
        # https://learn.microsoft.com/en-us/graph/api/group-post-members
        if ($GroupExists -eq $true) {
            $Resource = 'groups/{0}/members/microsoft.graph.{1}' -f $ExistingGroup.id, $MemberType
            $ExistingMembership = Invoke-MgGraphRequestSingle -Resource $Resource -Select 'id' | Select-Object -ExpandProperty Id
            $OriginalMemberCount = ($Members | Measure-Object).Count
        }
        else {
            $OriginalMemberCount = 0
            $ExistingMembership = @()
        }
        $Members = $Members | Select-Object -Unique | Where-Object { $_ -notin $ExistingMembership }
        $NotPresentMemberCount = ($Members | Measure-Object).Count
        if ((($ExistingMembership | Measure-Object).Count -eq 0) -and ($NotPresentMemberCount -eq 0)) {
            Write-Log -Message ('[{0}] No member was added to the already empty group' -f $InvocationName) -Type Warning
        }
        elseif ($NotPresentMemberCount -eq 0) {
            Write-Log -Message ('[{0}] No need to add new members' -f $InvocationName)
        }
        else {
            Write-Log -Message "[$InvocationName] Adding [$NotPresentMemberCount] members to the group ($($OriginalMemberCount - $NotPresentMemberCount) were already in the group)"

            $Hashtable = $(
                foreach ($Memberid in $Members) {
                    if ("$Memberid".Trim() -eq '') { continue }
                    @{
                        id      = "$Memberid"
                        method  = 'POST'
                        url     = 'groups/{0}/members/$ref' -f $ExistingGroup.Id
                        body    = @{
                            '@odata.id' = 'https://graph.microsoft.com/v1.0/directoryObjects/{0}' -f $Memberid
                        }
                        headers = @{'Content-Type' = 'application/json' }
                    }
                }
            )

            $BatchResults = Invoke-MgGraphRequestBatch -Hashtable $Hashtable -DoNotLogErrors
            foreach ($Failure in ($BatchResults | Where-Object -Property Status -NotIn (200, 204))) {
                $GraphError = $Failure | Convert-GraphErrorMessage
                Write-Log -Message "[$InvocationName] Failed to add [$($Failure.id)] to the group with error $($Failure.Status) [$($GraphError.ErrorCode)]: $($GraphError.Message)"
            }
            # End function/script and report memory usage, before and after cleaning it up
            $Hashtable = $GraphError = $ExistingMembership = $Members = $Failure = $BatchResults = $null
            $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
            $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
            Write-Log -Message "[$InvocationName] Function finished. Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)" -Type Debug
        }
    }

    return $ExistingGroup
}


function Add-EntraIdGroupMember {
    <#
.SYNOPSIS
    Add members to an existing Entra Id security group.

.DESCRIPTION
    Add members to an existing Entra Id security group.

    Existing extra members not specified in the Members list can also be removed by using the -Mirror switch.

.PARAMETER DisplayName
    Name of the group.

.PARAMETER id
    id of the group directory object.

.PARAMETER Members
    List of ids representing the members of the group.

.PARAMETER MemberType
    Type of the new members (Device, User, or Group).

.PARAMETER Mirror
    Add the missing members and remove the existing ones that are not part of the specified members.

.EXAMPLE
Add 2 devices ($ObjectId1, $ObjectId2) to the group with id '12345678-9abc-def0-1234-56789abcdef0'
    PS C:\> Add-EntraIdGroupMember -id '12345678-9abc-def0-1234-56789abcdef0' -Members $ObjectId1,$ObjectId2 -MemberType Device

.EXAMPLE
Add 2 users ($ObjectId1, $ObjectId2) to the group with id '12345678-9abc-def0-1234-56789abcdef0' and remove all other members than the specified 2 users
    PS C:\> Add-EntraIdGroupMember -id '12345678-9abc-def0-1234-56789abcdef0' -Members $ObjectId1,$ObjectId2 -MemberType User -Mirror

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-09-28
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByName')]
        [String]$displayName,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ById')]
        [String]$GroupId,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'ByName', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'ById', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('id')]
        [ValidateNotNullOrEmpty()]
        [String[]]$Members,

        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'ById')]
        [ValidateSet('user', 'device', 'group')]
        [String]$MemberType,

        [Parameter(Position = 4, ParameterSetName = 'ByName')]
        [Parameter(Position = 4, ParameterSetName = 'ById')]
        [switch]$Mirror
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        if ($Global:PSDefaultParameterValues.Keys.Count -gt 0) {
            $PSDefaultParameterValues = $Global:PSDefaultParameterValues.Clone()
        }
        else {
            $PSDefaultParameterValues.Clear()
        }
    }
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                $ExistingGroup = Invoke-MgGraphRequestSingle -Resource 'groups' -Filter "DisplayName eq '$DisplayName'" -Select 'id'

            }
            'ById' {
                $ExistingGroup = Invoke-MgGraphRequestSingle -Resource "groups/$GroupId" -Select 'id'
            }
        }

        if ($null -eq $ExistingGroup) {
            throw "Group is missing: displayName [$DisplayName] | Id [$GroupId]"
            return
        }

        $MembersResource = 'groups/{0}/members/microsoft.graph.{1}' -f $ExistingGroup.id, $MemberType
        $ExistingMembership = Invoke-MgGraphRequestSingle -Resource $MembersResource -Select 'id' | Select-Object -ExpandProperty Id
        $OriginalMemberCount = ($Members | Measure-Object).Count
        [String[]]$Skipped = $Members | Select-Object -Unique | Where-Object { $_ -in $ExistingMembership }
        [String[]]$AddMembers = $Members | Select-Object -Unique | Where-Object { $_ -notin $ExistingMembership }
        [String[]]$ToRemove = @()
        if ($Mirror.IsPresent -eq $true) {
            [String[]]$ToRemove = $ExistingMembership | Where-Object { $Members -notcontains $_ }
        }
        $NotPresentMemberCount = ($AddMembers | Measure-Object).Count
        if ((($ExistingMembership | Measure-Object).Count -eq 0) -and ($NotPresentMemberCount -eq 0)) {
            Write-Log -Message ('[{0}] No member was added to the already empty group [{1}]' -f $InvocationName, $ExistingGroup.id) -Type Warning
            [PSCustomObject]@{
                Result  = 'Skipped'
                Members = @()
                Comment = ''
            }
        }
        elseif ($NotPresentMemberCount -eq 0) {
            Write-Log -Message ('[{0}] No need to add new members to [{1}]' -f $InvocationName, $ExistingGroup.id)
            [PSCustomObject]@{
                Result  = 'Skipped'
                Members = $ExistingMembership
                Comment = ''
            }
        }
        else {
            # https://learn.microsoft.com/en-us/graph/api/group-post-members
            Write-Log -Message "[$InvocationName] Adding [$NotPresentMemberCount] members to the group ($($OriginalMemberCount - $NotPresentMemberCount) were already in the group)"

            $Hashtable = $(
                foreach ($Memberid in $AddMembers) {
                    if ("$Memberid".Trim() -eq '') { continue }
                    @{
                        id      = "$Memberid"
                        method  = 'POST'
                        url     = 'groups/{0}/members/$ref' -f $ExistingGroup.Id
                        body    = @{
                            '@odata.id' = 'https://graph.microsoft.com/v1.0/directoryObjects/{0}' -f $Memberid
                        }
                        headers = @{'Content-Type' = 'application/json' }
                    }
                }
            )

            $BatchResults = Invoke-MgGraphRequestBatch -Hashtable $Hashtable -DoNotLogErrors
            [String[]]$Failed = $BatchResults | Where-Object -Property Status -NotIn (200, 204) | Select-Object -ExpandProperty Id
            foreach ($Failure in ($BatchResults | Where-Object -Property Status -NotIn (200, 204))) {
                $GraphError = $Failure | Convert-GraphErrorMessage
                Write-Log -Message "[$InvocationName] Failed to add [$($Failure.id)] to the group with error $($Failure.Status) [$($GraphError.ErrorCode)]: $($GraphError.Message)"
                [PSCustomObject]@{
                    Result  = 'Failure'
                    Members = $Failure.id
                    Comment = "Error $($Failure.Status) [$($GraphError.ErrorCode)]: $($GraphError.Message)"
                }
            }
            [String[]]$Success = $BatchResults | Where-Object -Property Status -In (200, 204) | Select-Object -ExpandProperty Id
            if ($Success.Count -gt 0) {
                [PSCustomObject]@{
                    Result  = 'Success'
                    Members = $Success
                    Comment = ''
                }
            }
            if ($Skipped.Count -gt 0) {
                [PSCustomObject]@{
                    Result  = 'Skipped'
                    Members = $Skipped
                    Comment = ''
                }
            }
            Write-Log -Message "[$InvocationName] Result: $(($Success | Measure-Object).Count) success, $(($Failed | Measure-Object).Count) failure, $($OriginalMemberCount - $NotPresentMemberCount) skipped"
        }
        if (($Mirror.IsPresent -eq $true) -and ($ToRemove.Count -gt 0)) {
            Write-Log -Message "[$InvocationName] Removing [$($ToRemove.Count)] extra members from the group"

            $Hashtable = $(
                # Remove extra members
                foreach ($Memberid in $ToRemove) {
                    if ("$Memberid".Trim() -eq '') { continue }
                    @{
                        id     = "$Memberid"
                        method = 'DELETE'
                        url    = '/groups/{0}/members/{1}/$ref' -f $ExistingGroup.id, $Memberid
                    }
                }
            )

            $BatchResults = Invoke-MgGraphRequestBatch -Hashtable $Hashtable -DoNotLogErrors
            [String[]]$Failed = $BatchResults | Where-Object -Property Status -NotIn (200, 204) | Select-Object -ExpandProperty Id
            foreach ($Failure in ($BatchResults | Where-Object -Property Status -NotIn (200, 204))) {
                $GraphError = $Failure | Convert-GraphErrorMessage
                Write-Log -Message "[$InvocationName] Failed to remove [$($Failure.id)] from the group with error $($Failure.Status) [$($GraphError.ErrorCode)]: $($GraphError.Message)"
                [PSCustomObject]@{
                    Result  = 'Failure'
                    Members = $Failure.id
                    Comment = "Error $($Failure.Status) [$($GraphError.ErrorCode)]: $($GraphError.Message)"
                }
            }
            [String[]]$Removed = $BatchResults | Where-Object -Property Status -In (200, 204) | Select-Object -ExpandProperty Id
            if ($null -ne $Removed) {
                [PSCustomObject]@{
                    Result  = 'Removed'
                    Members = $Removed
                    Comment = ''
                }
            }
            Write-Log -Message "[$InvocationName] Result: $(($Removed | Measure-Object).Count) success, $(($Failed | Measure-Object).Count) failure"
        }
    }
    end {
        # End function/script and report memory usage, before and after cleaning it up
        $Hashtable = $GraphError = $Success = $Removed = $ExistingMembership = $Skipped = $AddMembers = $Failure = $BatchResults = $null
        $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
        $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
        Write-Log -Message "[$InvocationName] Function finished. Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)" -Type Debug
    }
}


function Remove-EntraIdGroupMember {
    <#
.SYNOPSIS
    Remove members from an existing Entra Id security group.

.DESCRIPTION
    Remove members from an existing Entra Id security group.

.PARAMETER DisplayName
    Name of the group.

.PARAMETER id
    id of the group directory object.

.PARAMETER Members
    List of ids representing the members of the group.

.PARAMETER MemberType
    Type of the members to remove (Device, User, or Group).

.EXAMPLE
    PS C:\> Remove-EntraIdGroupMember

.EXAMPLE
    PS C:\> Remove-EntraIdGroupMember

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-09-28
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByName')]
        [String]$displayName,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ById')]
        [String]$GroupId,

        [Parameter(Mandatory = $true, Position = 2, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $true, Position = 2, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [Alias('id')]
        [ValidateNotNullOrEmpty()]
        [String[]]$Members,

        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'ById')]
        [ValidateSet('user', 'device', 'group')]
        [String]$MemberType
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        if ($Global:PSDefaultParameterValues.Keys.Count -gt 0) {
            $PSDefaultParameterValues = $Global:PSDefaultParameterValues.Clone()
        }
        else {
            $PSDefaultParameterValues.Clear()
        }
    }
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                $ExistingGroup = Invoke-MgGraphRequestSingle -Resource 'groups' -Filter "DisplayName eq '$DisplayName'" -Select 'id'

            }
            'ById' {
                $ExistingGroup = Invoke-MgGraphRequestSingle -Resource "groups/$GroupId" -Select 'id'
            }
        }

        if ($null -eq $ExistingGroup) {
            throw "Group is missing: displayName [$DisplayName] | Id [$GroupId]"
            return
        }

        $MembersResource = 'groups/{0}/members/microsoft.graph.{1}' -f $ExistingGroup.id, $MemberType
        $ExistingMembership = Invoke-MgGraphRequestSingle -Resource $MembersResource -Select 'id' | Select-Object -ExpandProperty Id
        $OriginalMemberCount = ($Members | Measure-Object).Count
        [String[]]$Skipped = $Members | Select-Object -Unique | Where-Object { $_ -notin $ExistingMembership }
        [String[]]$RemoveMembers = $Members | Select-Object -Unique | Where-Object { $_ -in $ExistingMembership }
        $PresentMemberCount = ($RemoveMembers | Measure-Object).Count
        if ((($ExistingMembership | Measure-Object).Count -eq 0) -and ($PresentMemberCount -eq 0)) {
            Write-Log -Message ('[{0}] No member was removed from the already empty group [{1}]' -f $InvocationName, $ExistingGroup.id) -Type Warning
            [PSCustomObject]@{
                Result  = 'Skipped'
                Members = @()
            }
        }
        elseif ($PresentMemberCount -eq 0) {
            Write-Log -Message ('[{0}] No need to remove members from [{1}]' -f $InvocationName, $ExistingGroup.id)
            [PSCustomObject]@{
                Result  = 'Skipped'
                Members = $ExistingMembership
            }
        }
        else {
            # https://learn.microsoft.com/en-us/graph/api/group-delete-members
            Write-Log -Message "[$InvocationName] Removing [$PresentMemberCount] members from the group (Keeping $($OriginalMemberCount - $PresentMemberCount) members)"

            [hashtable[]]$HashTable = @(
                foreach ($Item in $RemoveMembers) {
                    if ("$Item".Trim() -eq '') { continue }
                    @{
                        id     = $Item
                        method = 'DELETE'
                        url    = '/groups/{0}/members/{1}/$ref' -f $ExistingGroup.id, $Item
                    }
                }
            )

            $Result = Invoke-MgGraphRequestBatch -Hashtable $HashTable -DoNotLogErrors
            $Failed = $Result | Where-Object -Property Status -NE 204
            if ($null -ne $Failed) {
                [PSCustomObject]@{
                    Result  = 'Failure'
                    Members = $Failed.id
                }
            }
            $Success = $Result | Where-Object -Property Status -EQ 204
            if ($null -ne $Success) {
                [PSCustomObject]@{
                    Result  = 'Success'
                    Members = $Success.id
                }
            }
            if ($Skipped.Count -gt 0) {
                [PSCustomObject]@{
                    Result  = 'Skipped'
                    Members = $Skipped
                }
            }
            Write-Log -Message "[$InvocationName] Result: $(($Success | Measure-Object).Count) success, $(($Failed | Measure-Object).Count) failure, $($OriginalMemberCount - $PresentMemberCount) skipped"
        }
    }
}


function Add-EntraIdGroupOwner {
    <#
.SYNOPSIS
    Add owners to an existing Entra Id security group.

.DESCRIPTION
    Add owners to an existing Entra Id security group.

.PARAMETER GroupName
    Name of the group.

.PARAMETER Groupid
    id of the group directory object.

.PARAMETER Owner
    List of ids representing the owners of the group.

.PARAMETER Type
    Type of the targeted owner resource.

.EXAMPLE
    PS C:\> Get-EntraIdGroupMember -id 'xxxx' -Type user | Add-EntraIdGroupOwner -id 'yyyy'

.EXAMPLE
    PS C:\> Add-EntraIdGroupOwner -GroupId 'xxxx' -Owner 'yyyy','zzzz'

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-09-28
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByName')]
        [Alias('displayName')]
        [String]$GroupName,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ById')]
        [String]$GroupId,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [Alias('id')]
        [String[]]$Owner,

        [Parameter(Position = 2, ParameterSetName = 'ById')]
        [Parameter(Position = 2, ParameterSetName = 'ByName')]
        [ValidateSet('user')]
        [String]$Type = 'user'
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            [String]$GroupId = Invoke-MgGraphRequestSingle -Resource 'groups' -Filter "displayName eq '$GroupName'" -Select id | Select-Object -ExpandProperty id
        }
        if ("$GroupId" -eq '') {
            throw "[$InvocationName] Failed to find the id of a group named [$GroupName]"
        }
        [String[]]$CurrentOwnerList = Invoke-MgGraphRequestSingle -Resource ('groups/{0}/owners/#microsoft.graph.{1}' -f $GroupId, $Type) -Select id | Select-Object -ExpandProperty id
    }
    process {
        [String[]]$Skipped = $Owner | Where-Object { $_ -in $CurrentOwnerList }
        [String[]]$AddOwner = $Owner | Where-Object { $_ -notin $CurrentOwnerList }

        if ($AddOwner.Count -eq 0) {
            Write-Log -Message "[$InvocationName] The specified ids are already owners of the group [$GroupId]"
            [PSCustomObject]@{
                Result  = 'Skipped'
                Members = $Owner
            }
            return
        }

        Write-Log -Message "[$InvocationName] Adding $($AddOwner.Count) owners to the group [$GroupId]"

        if ($Skipped.Count -gt 0) {
            [PSCustomObject]@{
                Result  = 'Skipped'
                Members = $Skipped
            }
        }

        [hashtable[]]$HashTable = @(
            foreach ($id in $AddOwner) {
                if ("$id".Trim() -eq '') { continue }
                @{
                    id      = $id
                    method  = 'POST'
                    url     = 'groups/{0}/owners/$ref' -f $Groupid
                    Body    = @{
                        '@odata.id' = 'https://graph.microsoft.com/v1.0/directoryObjects/{0}' -f $id
                    }
                    headers = @{ 'Content-Type' = 'application/json' }
                }
            }
        )
        $Result = Invoke-MgGraphRequestBatch -Hashtable $HashTable -DoNotLogErrors
        $Failed = $Result | Where-Object -Property Status -NE 204
        if ($null -ne $Failed) {
            [PSCustomObject]@{
                Result  = 'Failure'
                Members = $Failed.id
            }
        }
        $Success = $Result | Where-Object -Property Status -EQ 204
        if ($null -ne $Success) {
            [PSCustomObject]@{
                Result  = 'Success'
                Members = $Success.id
            }
        }
        Write-Log -Message "[$InvocationName] Result: $(($Success | Measure-Object).Count) success, $(($Failed | Measure-Object).Count) failure, $($Skipped.Count) skipped"
    }
}


function Remove-EntraIdGroupOwner {
    <#
.SYNOPSIS
    Remove owners from an existing Entra Id security group.

.DESCRIPTION
    Remove owners from an existing Entra Id security group.

.PARAMETER GroupName
    Name of the group.

.PARAMETER Groupid
    id of the group directory object.

.PARAMETER Owner
    List of ids representing the owners of the group.

.PARAMETER Type
    Type of the targeted owner resource.

.EXAMPLE
    PS C:\> Get-EntraIdGroupMember -id 'xxxx' -Type user | Remove-EntraIdGroupOwner -id 'yyyy'

.EXAMPLE
    PS C:\> Remove-EntraIdGroupOwner -GroupId 'xxxx' -Owner 'yyyy','zzzz'

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-09-28
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByName')]
        [Alias('displayName')]
        [String]$GroupName,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ById')]
        [String]$GroupId,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [Alias('id')]
        [String[]]$Owner,

        [Parameter(Position = 2, ParameterSetName = 'ById')]
        [Parameter(Position = 2, ParameterSetName = 'ByName')]
        [ValidateSet('user')]
        [String]$Type = 'user'
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            [String]$GroupId = Invoke-MgGraphRequestSingle -Resource 'groups' -Filter "displayName eq '$GroupName'" -Select id | Select-Object -ExpandProperty id
        }
        if ("$GroupId" -eq '') {
            throw "[$InvocationName] Failed to find the id of a group named [$GroupName]"
        }
        [String[]]$CurrentOwnerList = Invoke-MgGraphRequestSingle -Resource ('groups/{0}/owners/#microsoft.graph.{1}' -f $GroupId, $Type) -Select id | Select-Object -ExpandProperty id
        if ($CurrentOwnerList.Count -eq 0) {
            Write-Log -Message "[$InvocationName] The group [$GroupId] has no owner"
            return
        }
    }
    process {

        [String[]]$Skipped = $Owner | Where-Object { $_ -notin $CurrentOwnerList }
        [String[]]$RemoveOwner = $Owner | Where-Object { $_ -in $CurrentOwnerList }

        if ($RemoveOwner.Count -eq 0) {
            Write-Log -Message "[$InvocationName] None of the specified ids are owners of the group [$GroupId]"
            [PSCustomObject]@{
                Result  = 'Skipped'
                Members = $Owner
            }
            return
        }
        [hashtable[]]$HashTable = @(
            foreach ($id in $RemoveOwner) {
                if ("$id".Trim() -eq '') { continue }
                @{
                    id     = $id
                    method = 'DELETE'
                    url    = 'groups/{0}/owners/{1}/$ref' -f $GroupId, $id
                }
            }
        )

        Write-Log -Message "[$InvocationName] Removing $($RemoveOwner.Count) owners from the group [$GroupId]"

        if ($Skipped.Count -gt 0) {
            [PSCustomObject]@{
                Result  = 'Skipped'
                Members = $Skipped
            }
        }

        $Result = Invoke-MgGraphRequestBatch -Hashtable $HashTable -DoNotLogErrors
        $Failed = $Result | Where-Object -Property Status -NE 204
        if ($null -ne $Failed) {
            [PSCustomObject]@{
                Result  = 'Failure'
                Members = $Failed.id
            }
        }
        $Success = $Result | Where-Object -Property Status -EQ 204
        if ($null -ne $Success) {
            [PSCustomObject]@{
                Result  = 'Success'
                Members = $Success.id
            }
        }
        Write-Log -Message "[$InvocationName] Result: $(($Success | Measure-Object).Count) success, $(($Failed | Measure-Object).Count) failure, $($Skipped.Count) skipped"
    }
}
#endregion EntraId groups
#endregion EntraId


#region Intune
function Get-IntuneAuditLog {
    <#
.SYNOPSIS
    Parse Intune audit logs.

.DESCRIPTION
    Parse Intune audit logs.


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


    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [ValidateSet('Application', 'AssignmentFilter', 'Compliance', 'ConditionalAccess', 'Device', 'DeviceConfiguration', 'DeviceIntent', 'DeviceIntentSetting', 'DeviceInventory', 'DeviceSecurity', 'DeviceSetupConfiguration', 'EBookManagement', 'EndpointPrivilegeMgmt', 'Enrollment', 'GroupPolicyAnalytics', 'OnPremiseAccess', 'Other', 'RemoteHelp', 'Role', 'SoftwareUpdates')]
        [String[]]$Category,

        [Parameter()]
        [ValidateRange(1, 998)]
        [Alias('Top')]
        [uint16]$Last,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [datetime]$After = (Get-Date).Date.AddDays(-7),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [datetime]$Before = (Get-Date),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$activityOperationType,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$Target,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$TargetId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$userPrincipalName
    )

    begin {
        $InvocationName = $MyInvocation.InvocationName
    }
    process {
        $GRParams = @{
            APIVersion = 'beta'
            Resource   = 'deviceManagement/auditEvents'
            OrderBy    = 'activityDateTime desc'
            Select     = 'activityDateTime', 'resources', 'displayName', 'category', 'componentName', 'activityType', 'activityOperationType', 'activityResult', 'actor'
            Advanced   = 'count', 'ConsistencyLevel'
        }
        if (($null -ne $PSBoundParameters['Last']) -and ($Last -gt 0)) {
            $GRParams.Top = $Last
        }
        <#

id                    : d2ff9acd-f1e9-403d-b2a1-27d10955d0f2
displayName           : ClientCertificate stored in certificate inventory
componentName         : CertificateAuthority
activity              :
activityDateTime      : 08/10/2023 16:28:23
activityType          : Create ClientCertificate
activityOperationType : Create
activityResult        : Success
correlationId         : 569f4a5a-8061-4926-897f-bf37db85cda8
category              : Enrollment
actor                 : @{auditActorType=ItPro; userPermissions=System.Object[]; applicationId=; applicationDisplayName=;
                        userPrincipalName=xxxx; servicePrincipalName=; ipAddress=; userId=46afe23e-1569-4354-a62e-b2e58698acea}
resources             : {@{displayName=; auditResourceType=Microsoft.Management.Services.CertVNextCommonLibrary.ClientCertificate;
                        resourceId=2B69EE509CB218A6842FF0C6E8F152A206D8C660; modifiedProperties=System.Object[]}}


        actor
auditActorType         : ItPro
userPermissions        : {}
applicationId          :
applicationDisplayName :
userPrincipalName      : xxxx
servicePrincipalName   :
ipAddress              :
userId                 : 46afe23e-1569-4354-a62e-b2e58698acea


        resources
displayName        :
auditResourceType  : Microsoft.Management.Services.CertVNextCommonLibrary.ClientCertificate
resourceId         : 2B69EE509CB218A6842FF0C6E8F152A206D8C660
modifiedProperties : {@{displayName=AccountContextId; oldValue=; newValue=6113e532-f814-4bb9-ae61-898381e45aec}, @{displayName=deviceID; oldValue=; newValue=bf92f8e8-2d64-426c-a818-14710c71f3ae},
                     @{displayName=DeviceEnrollmentType; oldValue=; newValue=24}, @{displayName=Thumbprint; oldValue=; newValue=2B69EE509CB218A6842FF0C6E8F152A206D8C660}}


        resources.modifiedproperties
displayName          oldValue newValue
-----------          -------- --------
AccountContextId              6113e532-f814-4bb9-ae61-898381e45aec
deviceID                      bf92f8e8-2d64-426c-a818-14710c71f3ae
DeviceEnrollmentType          24
Thumbprint                    2B69EE509CB218A6842FF0C6E8F152A206D8C660


$target = 'WKS WIN SecurityBaseline WIN11 Virtual'
#>

        if ($After -ge $Before) {
            [int]$TimeSpan = 7
            Write-Warning -Message ("[$InvocationName] Start date [{0}] is more recent that the end date [{1}], setting the start date to [{2}]" -f $After.ToString('s'), $Before.ToString('s'), $Before.AddDays(-$TimeSpan).ToString('s'))
            $After = $Before.AddDays(-$TimeSpan)
        }
        $GRParams.Filter = $(
            "activityDateTime gt $($After.ToUniversalTime().ToString('s'))Z and activityDateTime le $($Before.ToUniversalTime().ToString('s'))Z"

            if ("$activityOperationType".Trim() -ne '') {
                "activityOperationType eq '$activityOperationType'"
            }
            if ("$userPrincipalName".Trim() -ne '') {
                "actor/userPrincipalName eq '$userPrincipalName'"
            }
            if ("$Target".Trim() -ne '') {
                "resources/any (r:r/displayName eq '$Target')"
            }
            elseif ("$Targetid".Trim() -ne '') {
                "resources/any (r:r/resourceId eq '$TargetId')"
            }
            if ($Category.Count -gt 0) {
                $(foreach ($CatItem in $Category) {
                        "category eq '{0}'" -f $CatItem
                    }) -join ' or '
            }
        ) -join ' and '

        Invoke-MgGraphRequestSingle @GRParams |
            Select-Object -Property activityDateTime,
            @{Label = 'Target'; Expression = { $_.resources.displayName | Where-Object { $_ -ne '<null>' } } },
            displayName,
            category,
            componentName,
            activityType,
            activityOperationType,
            activityResult,
            @{Label = 'UserPrincipalName'; Expression = { $_.actor.userPrincipalName } },
            @{Label = 'modifiedProperties'; Expression = { $_.resources.modifiedProperties } },
            actor,
            resources
        <#
        [HashTable[]]$BatchHashTable = $(
            foreach ($CategoryItem in $Category) {
                @{
                    id      = "$CategoryItem"
                    method  = 'Get'
                    url     = "/deviceManagement/auditEvents/getAuditActivityTypes(category='$CategoryItem')"
                    body    = @{}
                    Headers = @{'Content-Type' = 'application/json' }
                }
            }
        )
#>
    }
    end {}
}

#region Intune policies
function Resolve-CloudResourceId {
    <#
.SYNOPSIS


.DESCRIPTION


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

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String[]]$Objectid,

        [Parameter(Position = 1)]
        [ValidateSet('Assignable','NonAssignable','EntraId')]
        [String[]]$Type,

        [Parameter(Position = 2)]
        [ValidateSet('Compliance','Configuration policies','Updates','Enrollment','Scripts','Windows 365 Cloud PC','Applications','Application Configurations','Endpoint Security','Tenant administration','Devices','Directory')]
        [String[]]$Category
    )

    begin {

    }
    process {
        $ResourceMapList = $(
            switch ($Type) {
                'Assignable' { $Script:AssignableIntuneResourceMap }
                'NonAssignable' { $Script:NonAssignableIntuneResourceMap }
                'EntraId' { $Script:EntraResourceMap }
                default {
                    $Script:AssignableIntuneResourceMap
                    $Script:NonAssignableIntuneResourceMap
                    $Script:EntraResourceMap
                }
            }
        )

        if ($Category.Count -gt 0) {
            $ResourceMapList = $ResourceMapList | Where-Object -Property Category -In $Category
        }
        $ResourceList = $ResourceMapList.Resource | Select-Object -Unique | Where-Object { "$_".Trim() -ne '' }
        $HashTable = $(
            foreach ($Resource in $ResourceList) {
                $SuffixList = @('')
                if ($Resource -eq 'deviceManagement/deviceEnrollmentConfigurations') {
                    $SuffixList = $EnrollementIdSuffix
                }
                foreach ($Suffix in $SuffixList) {
                    foreach ($id in $Objectid) {
                        if ($id | Select-String -Pattern $EnrollementIdSuffix) {
                            @{
                                id     = ('{0}_{1}' -f $id, $Resource.Replace('/','_'))
                                method = 'GET'
                                url    = ("{0}('{1}')" -f $Resource, $id, $Suffix).TrimEnd('_')
                            }
                        }
                        else {
                            @{
                                id     = ('{0}_{1}-{2}' -f $id, $Resource.Replace('/','_'), $Suffix.TrimStart('_')).TrimEnd('-')
                                method = 'GET'
                                url    = ("{0}('{1}{2}')" -f $Resource, $id, $Suffix).TrimEnd('_')
                            }
                        }
                    }
                }
            }
        )
        $ResultList = Invoke-MgGraphRequestBatch -APIVersion beta -DoNotLogErrors -Hashtable $HashTable | Where-Object -Property Status -NE 404

        foreach ($id in $Objectid) {
            $Result = $ResultList | Where-Object -Property id -Like "${Id}_*"
            if ($Result.Status -contains 200) {
                $Result |
                    Where-Object -Property Status -EQ 200 |
                    Where-Object -Property Body |
                    ForEach-Object {
                        $Resource = ($_.Id -split '_' | Select-Object -Skip 1) -join '/' -replace '-.+$'
                        $TypeAndPlatform = $_.Body | Get-IntunePolicyPlatformAndType -Resource $Resource
                        [PSCustomObject]@{
                            id       = $id
                            Resource = $Resource
                            Platform = $TypeAndPlatform.platform
                            Type     = $TypeAndPlatform.type
                            Object   = $_.body
                        }
                    }
            }
            elseif ($null -eq $Result) {
                Write-Warning -Message "Failed to find [$id]"
                [PSCustomObject]@{
                    id       = $id
                    Resource = 'Unknown'
                    Platform = ''
                    Type     = ''
                    Object   = $null
                }
            }
            else {
                Write-Warning -Message "Errors occured while looking for [$id]"
                $Result |
                    Select-Object -Property Status, @{Label = 'Error'; Expression = { $_.Body.Error.code } } -Unique |
                    Where-Object -Property Error -NotIn ('BadRequest','ResourceNotFound') |
                    ForEach-Object {
                        [PSCustomObject]@{
                            id       = $id
                            Resource = 'Unknown'
                            Platform = ''
                            Type     = ''
                            Object   = $_
                        }
                    }

            }
        }
    }
}


function ConvertFrom-IntuneAssignmentTarget {
    <#
.SYNOPSIS
    Convert the target object of Intune assignments to PSCustomObject.

.DESCRIPTION
    Convert the target object of Intune assignments to PSCustomObject with the following properties:
        Action = Include/Exclude
        TargetType = All devices/All users/Group
        Target = Name of the target (All devices/All users/Group name)
            If the Groups parameter is not used, the group will be queried using its id.
            If the group was deleted, the function will look for it in the deleted items list (Entra ID "recycle bin").
        TargetId = Id of the targeted group
        FilterType = Type of filter used (none, include, exclude)
        Filter = Name or id of the filter (if -Filters is not used)
        MemberCount = Number of targeted objects (group members, all devices, all users)
            If the group is not found or DeviceCount or UserCount are not defined, MemberCount will be -1

    TODO: Find a way to get the real number of targets
        https://github.com/microsoftgraph/microsoft-graph-docs-contrib/blob/main/api-reference/beta/api/intune-shared-deviceconfiguration-gettargetedusersanddevices.md

.PARAMETER Target
    Target object (target, targetGroupId)

.PARAMETER Groups
    List of groups to be used as reference.
    The function Get-EntraIdGroupInfo can be used to query these groups.

.PARAMETER Filters
    List of filters to be used as reference.
    If not specified, only the id of the filters will be returned.

.PARAMETER DeviceCount
    Number of devices in Intune.

.PARAMETER UserCount
    Number of users in Entra ID.

.EXAMPLE
    PS C:\> # Get the policy assignments
    PS C:\> $PolicyAssignment = Invoke-MgGraphRequestSingle -APIVersion beta -Resource 'deviceManagement/configurationPolicies/62c50afe-366c-4e8c-953d-43ce6efad82e/assignments'

    PS C:\> # Gather information abount the groups, filters, devices, and user count
    PS C:\> $GroupList = Get-EntraIdGroupInfo -id $PolicyAssignment.Target.groupid -MembersCount -QuerySoftDeletedGroup
    PS C:\> $FilterList = Invoke-MgGraphRequestSingle -APIVersion beta -Resource 'deviceManagement/assignmentFilters' -Select 'id','displayName'
    PS C:\> $null = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/managedDevices' -Select id -Advanced Count -EA SilentlyContinue -Verbose:$false
    PS C:\> $AllDevicesCount = $_GraphAPICount # Intune devices count (the variable $_GraphAPICount is created by Invoke-MgGraphRequestSingle to hold @odata.count)
    PS C:\> $AllUsersCount = Invoke-MgGraphRequestSingle -Resource 'users/$count' -Advanced ConsistencyLevel -EA SilentlyContinue -Verbose:$false # Users count

    PS C:\> $PolicyAssignment | ConvertFrom-IntuneAssignmentTarget -Groups $GroupList -Filters $FilterList -DeviceCount $AllDevicesCount -UserCount $AllUsersCount

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-12-18
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [AllowNull()]
        [Object]$Target,

        [Parameter(Position = 1)]
        [Object[]]$Groups,

        [Parameter(Position = 2)]
        [Object[]]$Filters,

        [int32]$DeviceCount = -1,

        [int32]$UserCount = -1
    )

    process {
        if ($null -eq $Target) { return }
        [HashTable]$AdditionalProperties = @{}
        $Target.psobject.members.where({ ($_.MemberType -eq 'NoteProperty') -and (([string]$_.Value) -ne '') }) |
            Select-Object -Property Name,Value |
            Where-Object -Property Name -NotIn ('id','target','targetGroupId','intent','source') |
            ForEach-Object { $AdditionalProperties."$($_.Name)" = $_.Value }
        <#
createdDateTime (W365 User settings)
lastModifiedDateTime (Administrative Templates)
runRemediationScript (Remediation)
runSchedule (Remediation)
settings (Applications)
source (=direct)
sourceId (=?)
#>

        [String]$Intent = $Target.intent -replace '^$','apply'
        if ($Target.Target) { $Target = $Target.Target }
        elseif ($Target.targetGroupId) { $Target = $Target.targetGroupId }

        $TargetAction = 'Include'
        $TargetId = ''
        $MemberCount = -1
        [String]$DataType = "$($target.'@odata.type')"
        if (($DataType -eq '') -and ($Target.GetType().Name -eq 'String')) { $DataType = 'group' }
        [String]$TargetName = $(
            switch -Regex ($DataType) {
                'devices' {
                    'All devices'
                    $AssignmentType = 'All devices'
                    $MemberCount = $DeviceCount
                }
                'users' {
                    'All users'
                    $MemberCount = $UserCount
                    $AssignmentType = 'All users'
                }
                'group' {
                    $AssignmentType = 'Group'
                    [String]$TargetId = $target.groupid
                    if ($TargetId -eq '') { $TargetId = $target }
                    if (($Groups | Measure-Object).Count -eq 0) {
                        $Group = Get-EntraIdGroupInfo -id $TargetId -MembersCount -QuerySoftDeletedGroup
                    }
                    else {
                        $Group = $Groups | Where-Object -Property id -EQ $target.groupid
                    }

                    if (($null -eq $Group) -or ("$($Group.displayName)" -eq '') -or ($Group.Status -in (404, 'Deleted'))) {
                        '<Group deleted from Microsoft Entra ID>'
                    }
                    elseif ($Group.status -eq 'Soft-deleted') {
                        '<SOFT-DELETED> {0}' -f $Group.displayName
                    }
                    else {
                        $Group.displayname
                        $MemberCount = $Group.memberscount
                    }
                    if ($_ -match 'exclu') {
                        $TargetAction = 'Exclude'
                    }
                }
            }
        )

        if ($Filters.Count -eq 0) {
            [String]$Filter = $target.deviceAndAppManagementAssignmentFilterId
        }
        else {
            [String]$Filter = $Filters | Where-Object -Property id -EQ $target.deviceAndAppManagementAssignmentFilterId | Select-Object -ExpandProperty displayname
        }

        [PSCustomObject]@{
            Action               = $TargetAction
            Intent               = $Intent
            TargetType           = [String]$AssignmentType
            Target               = [String]$TargetName
            TargetId             = [String]$TargetId
            FilterType           = [String]$target.deviceAndAppManagementAssignmentFilterType -replace '^$','none'
            Filter               = "$Filter".Replace('00000000-0000-0000-0000-000000000000','')
            MemberCount          = $MemberCount
            AdditionalProperties = $AdditionalProperties
        }
    }
}


function Get-IntuneAssignment {
    <#
.SYNOPSIS
    Get a list of assignments for every assignable object in Intune.

.DESCRIPTION
    Get a list of assignments for every assignable object in Intune.

    The function returns a list of objects with the following properties:
        Category = Category of object (Compliance, Configuration policies, Enrollment, Scripts, Windows 365 Cloud PC, Applications, Application Configurations, Endpoint Security, Tenant administration)
        SubCategory = Sub category on the main one
        Type = Real type of the object
        Platform = Target platform (Windows, iOS/iPad, macOS, Android, Linux, All, ...)
        status = Status of the assignment
            No resource found: No object of this type was found
            Error <StatusCode> (<ErrorCode>): Means that the resource failed to be queried
            No assignment: No assignment was found for the object
            Assigned: The object is assigned
        id = Id of the object
        displayName = Display name of the object
        lastModifiedDateTime = Date where the object was last modified
        ScopeTags = Name of the scope tags linked to the object (only ids will be returned if the RBAC read permission is not present)
        AssignmentType = Type of assignment (Include/Exclude)
        AssignmentTargetType = Type of target (Device, User, Group)
        AssignmentTarget = Name of the target (All devices, All users, group name)
        AssignmentTargetid = id of the targeted group (Empty for "all devices" and "all users")
        AssignmentFilterType = Filter type (Include/Exclude) if present
        AssignmentFilter = Name of the filter (id if the RBAC read permission is missing)
        AssignmentMemberCount = Count of targeted group members (-1 means that group membership count could not be obtained)
        AssignmentInfo = Additional properties of the assignment

    Necessary permissions:
        DeviceManagementConfiguration.Read.All
            deviceManagement/deviceCompliancePolicies
            deviceManagement/deviceConfigurations
            deviceManagement/deviceShellScripts
            deviceManagement/groupPolicyConfigurations
            deviceManagement/intents
            deviceManagement/policySets
            deviceManagement/windowsFeatureUpdateProfiles
            deviceManagement/windowsInformationProtectionPolicies
            deviceManagement/windowsDriverUpdateProfiles
            deviceManagement/windowsQualityUpdateProfiles
            deviceManagement/inventoryPolicies

        DeviceManagementServiceConfig.Read.All
            deviceManagement/appleUserInitiatedEnrollmentProfiles
            deviceManagement/deviceEnrollmentConfigurations
            deviceManagement/notificationMessageTemplates
            deviceManagement/termsAndConditions

        DeviceManagementScripts.Read.All
            deviceManagement/deviceHealthScripts
            deviceManagement/deviceManagementScripts
            deviceManagement/deviceCustomAttributeShellScripts

        CloudPC.Read.All
            deviceManagement/virtualEndpoint/provisioningPolicies
            deviceManagement/virtualEndpoint/userSettings
            deviceManagement/virtualEndpoint/maintenanceWindow

        DeviceManagementApps.Read.All
            deviceAppManagement/androidManagedAppProtections
            deviceAppManagement/iosManagedAppProtections
            deviceAppManagement/managedEBooks
            deviceAppManagement/mdmWindowsInformationProtectionPolicies
            deviceAppManagement/mobileAppConfigurations
            deviceAppManagement/mobileApps
            deviceAppManagement/targetedManagedAppConfigurations
            deviceAppManagement/wdacSupplementalPolicies
            deviceAppManagement/windowsInformationProtectionPolicies
            deviceManagement/intuneBrandingProfiles
            deviceAppManagement/iosLobAppProvisioningConfigurations

        DeviceManagementRBAC.Read.All
            deviceManagement/roleassignments
            deviceManagement/roleDefinitions
            deviceManagement/roleScopeTags
            deviceManagement/operationApprovalPolicies

    TODO:
        - Implement the DeviceId and UserId filters
        - When a filter is used and DeviceId or UserId are too, check if the filter matches against any one of them
            https://learn.microsoft.com/en-us/graph/api/intune-policyset-devicemanagement-getassignmentfiltersstatusdetails?view=graph-rest-beta

.PARAMETER Objectid
    Filter on Intune objects' ids.

.PARAMETER GroupId
    Filter on targeted group ids (not implemented yet).

.PARAMETER DeviceId
    Returns the assignments linked to particular devices (not implemented yet)

.PARAMETER UserId
    Returns the assignments linked to particular users (not implemented yet)

.PARAMETER Category
    Returns only the assignments for the specified categories.

.EXAMPLE
    PS C:\> Get-IntuneAssignment

.EXAMPLE
    PS C:\> Get-IntuneAssignment -Category 'Configuration policies', 'Scripts'

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-12-18
    VERSION: 1.1.0
    MODIFICATIONS:
        2026-02-16 - M-A ROBIN: Added the role assignments

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'NoFilter')]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByGroupId')]
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByDeviceId')]
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByUserId')]
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'NoFilter')]
        [Alias('id')]
        [String[]]$Objectid,

        [Parameter(Position = 1, ParameterSetName = 'ByGroupId')]
        [ValidateNotNullOrEmpty()]
        [String[]]$GroupId,

        [Parameter(Position = 1, ParameterSetName = 'ByDeviceId')]
        [ValidateNotNullOrEmpty()]
        [String[]]$DeviceId,

        [Parameter(Position = 1, ParameterSetName = 'ByUserId')]
        [ValidateNotNullOrEmpty()]
        [String[]]$UserId,

        [Parameter(Position = 2, ParameterSetName = 'ByGroupId')]
        [Parameter(Position = 2, ParameterSetName = 'ByDeviceId')]
        [Parameter(Position = 2, ParameterSetName = 'ByUserId')]
        [Parameter(Position = 2, ParameterSetName = 'NoFilter')]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Application Configurations', 'Applications', 'Compliance', 'Configuration policies', 'Endpoint Security', 'Enrollment', 'Scripts', 'Tenant administration', 'Updates', 'Windows 365 Cloud PC')]
        [String[]]$Category
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        if ((Get-MgContext).scopes | Where-Object { $_ -like 'DeviceManagementManagedDevices.Read*' }) {
            $null = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/managedDevices' -Select id -Advanced Count -EA Stop -Verbose:$false
            $AllDevicesCount = $_GraphAPICount # Intune devices count (the variable $_GraphAPICount is created by Invoke-MgGraphRequestSingle to hold @odata.count)
        }
        elseif ((Get-MgContext).scopes | Where-Object { $_ -like 'device.Read*' }) {
            Write-Warning -Message "[$InvocationName] Could not get the Intune device count due to a lack of permission (DeviceManagementManagedDevices.Read.All), defaulting to retrieve the Entra device count"
            $AllDevicesCount = Invoke-MgGraphRequestSingle -Resource 'devices/$count' -Advanced ConsistencyLevel -ErrorAction Stop # Entra ID devices count
        }
        else {
            throw "[$InvocationName] Failed to get the devices count"
        }
        $AllUsersCount = Invoke-MgGraphRequestSingle -Resource 'users/$count' -Advanced ConsistencyLevel -EA SilentlyContinue -Verbose:$false # Users count

        [String[]]$RequiredPermissions = @(
            'CloudPC.Read.All'
            'DeviceManagementApps.Read.All'
            'DeviceManagementConfiguration.Read.All'
            'DeviceManagementRBAC.Read.All'
            'DeviceManagementScripts.Read.All'
            'DeviceManagementServiceConfig.Read.All'
        )

        foreach ($Permission in $RequiredPermissions) {
            if ($null -eq ((Get-MgContext).Scopes | Where-Object { $_ -like ($Permission -replace '\.Read\.','.*.') })) {
                Write-Warning -Message "[$InvocationName] Missing permission: $Permission"
            }
        }
    }
    process {
        # Get the id, name and scopetags and optionally the assignments for each type of policy
        $BatchResults = $(
            $HashTable = $(
                foreach ($Item in $Script:AssignableIntuneResourceMap) {
                    if (($Category.Count -gt 0) -and ($Item.Category -notin $Category)) { continue }
                    $PropertyList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                    $NameProperty = 'displayName'
                    $ScopeTagProperty = 'roleScopeTagIds'
                    $null = $PropertyList.Add($ScopeTagProperty)
                    $ExpandProperty = ''
                    $AdditionalProperty = ''
                    # Some resources don't have the default property name for policy name and scope tags
                    switch ($Item.Resource) {
                        { $_ -in (
                                'deviceManagement/appleUserInitiatedEnrollmentProfiles',
                                'deviceAppManagement/policySets',
                                'deviceAppManagement/managedEBooks',
                                'deviceManagement/roleScopeTags',
                                'deviceManagement/operationApprovalPolicies',
                                'deviceManagement/virtualEndpoint/userSettings'
                            ) } {
                            # There is no scope tag property for these resources
                            $ScopeTagProperty = ''
                        }
                        { $_ -in ('deviceManagement/configurationPolicies','deviceManagement/inventoryPolicies') } {
                            $NameProperty = 'name'
                        }
                        { $_ -in ('deviceManagement/configurationPolicies') } {
                            $AdditionalProperty = 'templateReference,platforms,technologies'
                        }
                        { $_ -in ('deviceManagement/intents') } {
                            $AdditionalProperty = 'templateId'
                        }
                        'deviceManagement/roleAssignments' { $AdditionalProperty = 'members,resourceScopes,scopeMembers' }
                        'deviceManagement/virtualEndpoint/provisioningPolicies' { $ScopeTagProperty = 'scopeIds'; $ExpandProperty = 'assignments'; break }
                        'deviceManagement/virtualEndpoint/userSettings' { $ExpandProperty = 'assignments'; break }
                    }

                    if ("$ExpandProperty" -ne '') {
                        [String]$url = '{0}?$expand={1}' -f "$($Item.Resource)".Trim(), $ExpandProperty
                    }
                    else {
                        $PropertyList = @('id', $NameProperty, $ScopeTagProperty, $AdditionalProperty).Where({ "$_" -ne '' }) -join ','

                        if ($Item.Resource -notin ('deviceManagement/roleDefinitions', 'deviceManagement/roleassignments', 'deviceManagement/roleScopeTags')) {
                            $PropertyList = '{0},{1}' -f $PropertyList, 'lastModifiedDateTime'
                        }
                        [String]$url = "$('{0}?$select={1}' -f "$($Item.Resource)".Trim(),$PropertyList)"
                    }

                    if ("$($Item.Filter)".Trim() -ne '') {
                        $url = '{0}&$filter={1}' -f $url, "$($Item.Filter)".Trim()
                    }
                    @{
                        id     = "$($Item.Category -replace '\s+','_')-$($Item.SubCategory -replace '\s+','_')"
                        method = 'GET'
                        url    = $url
                    }
                }
            )
            Invoke-MgGraphRequestBatch -APIVersion beta -Hashtable $HashTable -DoNotLogErrors |
                Select-Object -Property *,
                @{Label = 'Category'; Expression = { ("$($_.id)" -split '-')[0] -replace '_',' ' } },
                @{Label = 'SubCategory'; Expression = { (("$($_.id)" -split '-') | Select-Object -Skip 1) -join '-' -replace '_',' ' } }
        )

        # Fetch every scope tags and role assignments
        [PSCustomObject[]]$ScopeTagList = ($BatchResults | Where-Object -Property SubCategory -EQ 'Scope tags').body.value
        [PSCustomObject[]]$RoleAssignments = ($BatchResults | Where-Object -Property SubCategory -EQ 'Role assignments').body.value
        # Fetch every assignment filters
        try {
            $FilterList = Invoke-MgGraphRequestSingle -APIVersion beta -Resource 'deviceManagement/assignmentFilters' -Select 'id','displayName' -EA Stop
        }
        catch {
            Write-Warning -Message "[$InvocationName] Failed to list the assignment filters: $($_.Exception.Message)"
        }
        $AssignmentList = $(
            # List the assignments for each policy
            :NextBatchResult foreach ($Item in $BatchResults) {
                if (($Objectid.Count -gt 0) -and ($(switch ($ObjectId) { { $_ -in $Item.body.value.id } { $true ; break } }) -notcontains $true)) {
                    continue NextBatchResult
                }
                [String]$CategoryName = $Item.Category
                [String]$SubCategory = $Item.SubCategory
                if ($Item.Body.Error) {
                    $GraphError = $Item | Convert-GraphErrorMessage
                    $Status = 'Error {0} ({1})' -f $Item.Status, $GraphError.ErrorCode
                    Write-Warning -Message "[$InvocationName] Failed to get [$($CategoryName): $($SubCategory)] with ${Status}: $($GraphError.Message)"
                    [PSCustomObject]@{
                        Category              = $CategoryName
                        SubCategory           = $SubCategory
                        Type                  = ''
                        Platform              = ''
                        status                = $Status
                        id                    = ''
                        displayName           = ''
                        lastModifiedDateTime  = $null
                        ScopeTags             = [String[]]''
                        AssignmentIntent      = ''
                        AssignmentType        = ''
                        AssignmentTargetType  = ''
                        AssignmentTarget      = ''
                        AssignmentTargetid    = ''
                        AssignmentFilterType  = ''
                        AssignmentFilter      = ''
                        AssignmentMemberCount = -1
                        AssignmentInfo        = @{}
                    }
                    continue NextBatchResult
                }

                $PolicyList = $Item.Body.Value

                if (($PolicyList | Measure-Object).Count -eq 0) {
                    Write-Warning -Message "[$InvocationName] Could not find any [$($CategoryName): $($SubCategory)] policy"
                    [PSCustomObject]@{
                        Category              = $CategoryName
                        SubCategory           = $SubCategory
                        Type                  = ''
                        Platform              = ''
                        status                = 'No resource found'
                        id                    = ''
                        displayName           = ''
                        lastModifiedDateTime  = $null
                        ScopeTags             = [String[]]''
                        AssignmentIntent      = ''
                        AssignmentType        = ''
                        AssignmentTargetType  = ''
                        AssignmentTarget      = ''
                        AssignmentTargetid    = ''
                        AssignmentFilterType  = ''
                        AssignmentFilter      = ''
                        AssignmentMemberCount = -1
                        AssignmentInfo        = @{}
                    }
                    continue NextBatchResult
                }

                Write-Verbose -Message "[$InvocationName] Processing [$($CategoryName): $($SubCategory)] policies"
                # Using the @odata.context to parse the resource and properties of the query
                if ($Item.body.'@odata.context' -match '\$metadata#(?<Resource>[^\(]+)\((?<Properties>[^\(]+)') {
                    $Resource = $Matches['Resource']
                    # deviceManagement/roleassignments is only used to get link a role to its assignment as $expand=roleassignments does not yield any result
                    if ($Resource -eq 'deviceManagement/roleassignments') { continue NextBatchResult }

                    [String[]]$Properties = $Matches['Properties'] -split ',' -replace '\W+'
                    [String]$AssignmentProperty = $Properties | Where-Object { $_ -match 'assign' } | Select-Object -First 1

                    if ($Item.Body.'@odata.nextLink') {
                        # Nextlink means that all results have not been loaded so we need to query the endpoint again to get all of them
                        # The nextLink itself could also be used in a loop
                        Write-Warning -Message "[$InvocationName] @odata.nextLink present for [$($CategoryName): $($SubCategory)], querying again"
                        $PM = $Script:AssignableIntuneResourceMap | Where-Object -Property SubCategory -EQ $SubCategory
                        $GRParams = @{
                            APIVersion = 'beta'
                            Resource   = $Resource
                        }
                        if ("$($PM.Filter)".Trim() -ne '') { $GRParams.Filter = "$($PM.Filter)".Trim() }
                        if ($AssignmentProperty -eq '') { $GRParams.Select = $Properties }
                        $PolicyList = Invoke-MgGraphRequestSingle @GRParams
                    }
                    if ($AssignmentProperty -ne '') {
                        # Actual properties are not listed in the data context, we need to get them from the objects'
                        [String[]]$Properties = $PolicyList | Get-Member -MemberType Properties -EA Ignore | Select-Object -ExpandProperty Name
                        [String]$NameProperty = $Properties | Where-Object { $_ -in ('displayName','name') } | Select-Object -First 1
                        [String]$ScopeProperty = $Properties | Where-Object { $_ -in ('roleScopeTagIds', 'scopeIds') } | Select-Object -First 1
                        [String[]]$GroupIdList = $PolicyList.$AssignmentProperty.target |
                            ForEach-Object {
                                if ($_.groupid) { $_.GroupId }
                                elseif ($_.targetGroupId) { $_.targetGroupId }
                                elseif (("$_" -match '\w{8}-\w{4}-\w{4}-\w{4}-\w{12}') ) { $_ }
                            } | Select-Object -Unique
                        Remove-Variable -Name 'GroupList' -ErrorAction Ignore -Force
                        if ($GroupIdList.Count -gt 0) {
                            Write-Verbose -Message "[$InvocationName] Querying ($($GroupidList.count)) group names for [$($CategoryName): $($SubCategory)] assignments"
                            $GroupList = Get-EntraIdGroupInfo -Id $GroupIdList -MembersCount -Property 'displayName' -QuerySoftDeletedGroup
                        }

                        :NextPolicy foreach ($Policy in $PolicyList) {
                            Write-Verbose -Message "[$InvocationName] Getting assignments for [$($Policy.$NameProperty)] of type [$($CategoryName): $($SubCategory)]"
                            [String[]]$PolicyScopeTags = $Policy.$ScopeProperty
                            if ($null -ne $Policy.lastModifiedDateTime) { $LastModified = [datetime]$Policy.lastModifiedDateTime }
                            else { $LastModified = [datetime]::MinValue }
                            $ItemPlatformAndType = $Policy | Get-IntunePolicyPlatformAndType -Resource $Resource -Verbose:$false # Get the platform and the type of policy
                            if ($ScopeTagList.Count) {
                                [String[]]$PolicyScopeTags = ($ScopeTagList | Where-Object -Property id -In $PolicyScopeTags).displayName
                            }
                            if (($null -eq $Policy.$AssignmentProperty) -or ($Policy.$AssignmentProperty | Measure-Object).Count -eq 0) {
                                Write-Warning -Message "[$InvocationName] No assignment found for [$($CategoryName): $($SubCategory)] [$($Policy.$NameProperty)]"
                                [PSCustomObject]@{
                                    Category              = [String]$CategoryName
                                    SubCategory           = [String]$SubCategory
                                    Type                  = $ItemPlatformAndType.Type
                                    Platform              = $ItemPlatformAndType.Platform
                                    status                = 'No assignment'
                                    id                    = [String]$Policy.id
                                    displayName           = [String]$Policy.$NameProperty
                                    lastModifiedDateTime  = $LastModified
                                    ScopeTags             = $PolicyScopeTags
                                    AssignmentIntent      = ''
                                    AssignmentType        = ''
                                    AssignmentTargetType  = ''
                                    AssignmentTarget      = ''
                                    AssignmentTargetid    = ''
                                    AssignmentFilterType  = ''
                                    AssignmentFilter      = ''
                                    AssignmentMemberCount = -1
                                    AssignmentInfo        = @{}
                                }
                                $ItemPlatformAndType = $Policy = $LastModified = $GroupList = $GroupIdList = $null
                                [System.GC]::Collect()
                                continue NextPolicy
                            }

                            $TargetList = $Policy.$AssignmentProperty | ConvertFrom-IntuneAssignmentTarget -Filters $FilterList -Groups $GroupList -DeviceCount $AllDevicesCount -UserCount $AllUsersCount

                            foreach ($Target in $TargetList) {
                                [PSCustomObject]@{
                                    Category              = [String]$CategoryName
                                    SubCategory           = [String]$SubCategory
                                    Type                  = $ItemPlatformAndType.Type
                                    Platform              = $ItemPlatformAndType.Platform
                                    status                = 'Assigned'
                                    id                    = [String]$Policy.id
                                    displayName           = [String]$Policy.$NameProperty
                                    lastModifiedDateTime  = $LastModified
                                    ScopeTags             = $PolicyScopeTags
                                    AssignmentIntent      = [String]$Target.Intent
                                    AssignmentType        = [String]$Target.Action
                                    AssignmentTargetType  = [String]$Target.TargetType
                                    AssignmentTarget      = [String]$Target.Target
                                    AssignmentTargetid    = [String]$Target.TargetId
                                    AssignmentFilterType  = [String]$Target.FilterType
                                    AssignmentFilter      = [String]$Target.Filter
                                    AssignmentMemberCount = $Target.MemberCount
                                    AssignmentInfo        = $Target.AdditionalProperties
                                }
                            }
                        }
                        $TargetList = $Target = $PolicyList = $Policy = $GroupList = $GroupIdList = $null
                        [System.GC]::Collect()
                        continue NextBatchResult
                    }

                    [String]$NameProperty = $Properties | Where-Object { $_ -match 'name' } | Select-Object -First 1
                    [String]$ScopeProperty = $Properties | Where-Object { $_ -match 'scope' } | Select-Object -First 1
                    [String]$Query = $(
                        switch ($Resource) {
                            'deviceManagement/roleDefinitions' { 'roleAssignments'; break }
                            'deviceManagement/deviceShellScripts' { 'groupAssignments'; break }
                            Default { 'assignments'; break }
                        }
                    )
                    Write-Verbose -Message "[$InvocationName] Querying assignments for $($PolicyList.Count) policies of type [$($CategoryName): $($SubCategory)]"
                    $BatchAssignments = Invoke-MgGraphRequestBatch -APIVersion beta -Resource $Resource -Query $Query -ObjectList $PolicyList -DoNotLogErrors
                    Remove-Variable -Name 'GroupList' -ErrorAction Ignore -Force
                    if ($Resource -ne 'deviceManagement/roleDefinitions') {
                        [String[]]$GroupIdList = $BatchAssignments.body.value.target |
                            ForEach-Object {
                                if ($_.groupid) { $_.GroupId }
                                elseif ($_.targetGroupId) { $_.targetGroupId }
                                elseif (("$_" -match '\w{8}-\w{4}-\w{4}-\w{4}-\w{12}') ) { $_ }
                            } |
                            Select-Object -Unique
                    }
                    else {
                        [String[]]$GroupIdList = @($RoleAssignments.members) + @($RoleAssignments.resourceScopes) + @($RoleAssignments.scopeMembers) | Select-Object -Unique
                    }

                    if ($GroupIdList.Count -gt 0) {
                        Write-Verbose -Message "[$InvocationName] Querying ($($GroupIdList.count)) group names for [$($CategoryName): $($SubCategory)] assignments"
                        $GroupList = Get-EntraIdGroupInfo -Id $GroupIdList -MembersCount -Property 'displayName' -QuerySoftDeletedGroup
                    }
                    :NextAssignment foreach ($Assignment in $BatchAssignments) {
                        $Policy = $PolicyList | Where-Object -Property id -EQ $Assignment.id
                        if ($null -ne $Policy.lastModifiedDateTime) { $LastModified = [datetime]$Policy.lastModifiedDateTime }
                        else { $LastModified = [datetime]::MinValue }
                        [String[]]$PolicyScopeTags = $Policy.$ScopeProperty
                        $ItemPlatformAndType = $Policy | Get-IntunePolicyPlatformAndType -Resource $Resource -Verbose:$false # Get the platform and the type of policy
                        if ($ScopeTagList.Count) {
                            [String[]]$PolicyScopeTags = ($ScopeTagList | Where-Object -Property id -In $PolicyScopeTags).displayName
                        }
                        if ($Assignment.Body.Error) {
                            $GraphError = $Assignment | Convert-GraphErrorMessage
                            $AssignmentStatus = 'Error {0} ({1})' -f $Assignment.Status, $GraphError.ErrorCode
                            Write-Warning -Message "[$InvocationName] Failed to get [$($CategoryName): $($SubCategory)] for [$($Assignment.Id)] with error ${AssignmentStatus}: $($GraphError.Message)"
                            [PSCustomObject]@{
                                Category              = [String]$CategoryName
                                SubCategory           = [String]$SubCategory
                                Type                  = $ItemPlatformAndType.Type
                                Platform              = $ItemPlatformAndType.Platform
                                status                = [String]$AssignmentStatus
                                id                    = [String]$Assignment.id
                                displayName           = [String]$Policy.$NameProperty
                                lastModifiedDateTime  = $LastModified
                                ScopeTags             = $PolicyScopeTags
                                AssignmentIntent      = ''
                                AssignmentType        = ''
                                AssignmentTargetType  = ''
                                AssignmentTarget      = ''
                                AssignmentTargetid    = ''
                                AssignmentFilterType  = ''
                                AssignmentFilter      = ''
                                AssignmentMemberCount = -1
                                AssignmentInfo        = @{}
                            }
                            continue NextAssignment
                        }
                        if (($null -eq $Assignment.Body.value) -or ($Assignment.Body.value | Measure-Object).Count -eq 0) {
                            Write-Warning -Message "[$InvocationName] No assignment found for [$($Policy.$NameProperty)] of type [$($CategoryName): $($SubCategory)]"
                            [PSCustomObject]@{
                                Category              = [String]$CategoryName
                                SubCategory           = [String]$SubCategory
                                Type                  = $ItemPlatformAndType.Type
                                Platform              = $ItemPlatformAndType.Platform
                                status                = 'No assignment'
                                id                    = [String]$Assignment.id
                                displayName           = [String]$Policy.$NameProperty
                                lastModifiedDateTime  = $LastModified
                                ScopeTags             = $PolicyScopeTags
                                AssignmentIntent      = ''
                                AssignmentType        = ''
                                AssignmentTargetType  = ''
                                AssignmentTarget      = ''
                                AssignmentTargetid    = ''
                                AssignmentFilterType  = ''
                                AssignmentFilter      = ''
                                AssignmentMemberCount = -1
                                AssignmentInfo        = @{}
                            }
                            continue NextAssignment
                        }
                        Write-Verbose -Message "[$InvocationName] Listing assignments for [$($Policy.$NameProperty)] of type [$($CategoryName): $($SubCategory)]"
                        foreach ($Target in $Assignment.Body.value) {
                            if ($Resource -ne 'deviceManagement/roleDefinitions') {
                                $ConvertedTarget = $Target | ConvertFrom-IntuneAssignmentTarget -Filters $FilterList -Groups $GroupList -DeviceCount $AllDevicesCount -UserCount $AllUsersCount
                                [PSCustomObject]@{
                                    Category              = [String]$CategoryName
                                    SubCategory           = [String]$SubCategory
                                    Type                  = $ItemPlatformAndType.Type
                                    Platform              = $ItemPlatformAndType.Platform
                                    status                = 'Assigned'
                                    id                    = [String]$Assignment.id
                                    displayName           = [String]$Policy.$NameProperty
                                    lastModifiedDateTime  = $LastModified
                                    ScopeTags             = $PolicyScopeTags
                                    AssignmentIntent      = [String]$ConvertedTarget.Intent
                                    AssignmentType        = [String]$ConvertedTarget.Action
                                    AssignmentTargetType  = [String]$ConvertedTarget.TargetType
                                    AssignmentTarget      = [String]$ConvertedTarget.Target
                                    AssignmentTargetid    = [String]$ConvertedTarget.TargetId
                                    AssignmentFilterType  = [String]$ConvertedTarget.FilterType
                                    AssignmentFilter      = [String]$ConvertedTarget.Filter
                                    AssignmentMemberCount = $ConvertedTarget.MemberCount
                                    AssignmentInfo        = $ConvertedTarget.AdditionalProperties
                                }
                            }
                            else {
                                $RA = $RoleAssignments | Where-Object -Property Id -EQ $Target.id
                                foreach ($Property in ('resourceScopes','members')) {
                                    foreach ($RoleGroupId in $RA.$Property) {
                                        $GroupInfo = $GroupList | Where-Object -Property id -EQ $RoleGroupId
                                        [PSCustomObject]@{
                                            Category              = [String]$CategoryName
                                            SubCategory           = [String]$SubCategory
                                            Type                  = $ItemPlatformAndType.Type
                                            Platform              = $ItemPlatformAndType.Platform
                                            status                = 'Assigned'
                                            id                    = [String]$Assignment.id
                                            displayName           = [String]"$($Policy.$NameProperty) | $($RA.displayName)"
                                            lastModifiedDateTime  = $LastModified
                                            ScopeTags             = $PolicyScopeTags + @($ScopeTagList | Where-Object -Property id -In $RA.roleScopeTagIds | Select-Object -ExpandProperty displayName) | Select-Object -Unique
                                            AssignmentIntent      = 'RBAC'
                                            AssignmentType        = $(switch ($Property) { 'resourceScopes' { 'Scope (Groups)' } 'members' { 'Role members' } })
                                            AssignmentTargetType  = 'Group'
                                            AssignmentTarget      = [String]($GroupInfo.DisplayName)
                                            AssignmentTargetid    = $RoleGroupId
                                            AssignmentFilterType  = 'N/A'
                                            AssignmentFilter      = ''
                                            AssignmentMemberCount = $GroupInfo.MembersCount
                                            AssignmentInfo        = @{}
                                        }
                                    }
                                }
                            }
                        }
                    }
                    $BatchAssignments = $ConvertedTarget = $Assignment = $PolicyList = $Policy = $GroupList = $GroupIdList = $null
                    [System.GC]::Collect()
                }
                else {
                    Write-Warning -Message "[$InvocationName] Failed to parse data context for [$($CategoryName): $($SubCategory)]: $($Item.body.'@odata.context')"
                }
            }
        )

        if ($GroupId.Count -gt 0) {
            $AssignmentList | Where-Object -Property AssignmentTargetid -In $GroupId
        }
        else {
            $AssignmentList
        }
        $BatchResults = $AssignmentList = $Item = $null
        [System.GC]::Collect()
        $null = [System.GC]::GetTotalMemory($true)
    }
}


function Get-IntunePolicyChangeLog {
    <#
.SYNOPSIS


.DESCRIPTION


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


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$id,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [datetime]$After = (Get-Date).Date.AddDays(-7),

        [Parameter(Position = 2)]
        [ValidateNotNullOrEmpty()]
        [datetime]$Before = (Get-Date),

        [Parameter(Position = 3)]
        [ValidateRange(1, 998)]
        [Alias('Top')]
        [uint16]$Last
    )

    begin {
        #$InvocationName = $MyInvocation.InvocationName
    }
    process {
        $Policy = Invoke-MgGraphRequestSingle -Resource ('deviceManagement/configurationPolicies/{0}' -f $id) -APIVersion 'beta'

        if ($null -ne $Policy) {
            $Params = @{
                Category = 'DeviceConfiguration'
                After    = $After
                Before   = $Before
            }
            if ($Last -gt 0) {
                $Params.Last = $Last
            }
            $ChangeLog = Get-IntuneAuditLog @Params -TargetId $id
            $( foreach ($Item in $ChangeLog) {
                    $actor = $Item.UserPrincipalName
                    if ($null -eq $actor) {
                        #$actor = $Item.actor.
                    }
                    foreach ($resource in $Item.resources) {
                        foreach ($Modified in $resource.modifiedProperties) {
                            [PSCustomObject]@{
                                TargetName            = $Item.Target
                                Targetid              = $Id
                                activityDateTime      = $Item.activityDateTime
                                activityType          = $Item.activityType
                                activityOperationType = $Item.activityOperationType
                                activityResult        = $Item.activityResult
                                Actor                 = $actor
                                ResourceType          = $resource.Type
                                Property              = $Modified.displayName
                                oldValue              = $Modified.oldValue
                                newValue              = $Modified.newValue
                            }
                        }
                    }
                })
        }
    }
    end {}
}


function Get-IntunePolicyPlatformAndType {
    <#
.SYNOPSIS
    Return the type and targeted platform of an Intune policy/object.

.DESCRIPTION
    Return the type and targeted platform of an Intune policy/object.

    This function relies on several properties of the Intune object.

    To determine the targeted platform, it first tries to parse the @odata.type.
    Configuration Policies (deviceManagement/configurationPolicies) have 2 other properties named 'platforms' and 'templateReference' which can help with getting the platform.
    If needed, the resource will be parsed (Ex: deviceManagement/groupPolicyConfigurations).

    To determine the object type, the @odata.type is the main source.
    If missing we can rely on the templateName and templateId properties, or use the resource

.PARAMETER Policy
    Policy or object which properties will be used to determine the platform and the type.

.PARAMETER id
    Object id

.PARAMETER displayName
    Object display name

.PARAMETER @odata.type
    Object @odata.type property

.PARAMETER platforms
    Object platforms property

.PARAMETER technologies
    Object technologies property

.PARAMETER templateReference
    Object templateReference property

.PARAMETER templateid
    Object templateid property

.PARAMETER Resource
    Resource used to query the object

.EXAMPLE
    PS C:\> Invoke-MgGraphRequestSingle -Resource 'deviceManagement/groupPolicyConfigurations' -top 1 | Get-IntunePolicyPlatformAndType -Resource 'deviceManagement/groupPolicyConfigurations'

    id = 00000000-0000-0000-0000-000000000000
    platform = 'Windows'
    Type = 'Administrative templates'

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-01-24
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ByObject')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'ByObject')]
        [PSObject]$Policy,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByProperty')]
        [String]$id,

        [Parameter(Position = 1, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByProperty')]
        [Alias('Name')]
        [String]$displayName,

        [Parameter(Position = 2, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByProperty')]
        [String]${@odata.Type},

        [Parameter(Position = 3, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByProperty')]
        [String]$platforms,

        [Parameter(Position = 4, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByProperty')]
        [String]$technologies,

        [Parameter(Position = 5, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByProperty')]
        [PSObject]$templateReference,

        [Parameter(Position = 6, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByProperty')]
        [String]$templateid,

        [Parameter(Position = 1, ParameterSetName = 'ByObject' )]
        [Parameter(Position = 7, ParameterSetName = 'ByProperty' )]
        [String]$Resource
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
    }
    process {
        Write-Verbose -Message "[$InvocationName] Parameter set name: $($PSCmdlet.ParameterSetName)"
        # Get the platform based on the @odata.type
        if ($PSCmdlet.ParameterSetName -eq 'ByObject') {
            [String]$id = $Policy.id
            [String]$odataType = $Policy.'@odata.type'
            [String]$platforms = $Policy.platforms -join ', '
            [String]$technologies = $Policy.technologies
            [String]$templateName = $Policy.templateReference.templatedisplayName
            [String]$templateid = $Policy.templateId
            [String]$DisplayName = $Policy.displayName
            if (("$displayName" -eq '') -and ($Policy.Name)) {
                [String]$DisplayName = $Policy.name
            }
        }
        else {
            [String]$odataType = ${@odata.Type}
            [String]$templateName = $templateReference.templatedisplayName
        }
        if (("$templateid" -ne '') -and ("$templateName" -eq '')) {
            # deviceManagement/intents
            [String]$TemplateName = (Get-IntuneTemplate -id $templateid -NameOnly).TemplateName
        }
        Write-Verbose -Message "[$InvocationName] id [$id], ODataType [$odataType], Platforms [$platforms], Technologies [$technologies], TemplateName [$templateName], templateId [$templateid]"

        [String]$PlatformName = $(
            switch -Regex ($odataType) {
                'androidWorkProfile' { 'Android Work Profile'; break }
                'androidDeviceOwner' { 'Android Enterprise'; break }
                'android' { 'Android'; break }
                'macOS|mac' { 'macOS'; break }
                'ios|iPad|iPhone' { 'iOS/iPadOS'; break }
                'windowsPhone' { 'Windows Phone'; break }
                'windows' { 'Windows'; break }
                'aosp' { 'Android (AOSP)'; break }
                'linux|unix' { 'Linux'; break }
                'officeSuiteApp' { 'Windows' ; break }
                'winGetApp' { 'Windows' ; break }
                'win32LobApp' { 'Windows' ; break }
                'webApp' { 'All' ; break }
                'deviceEnrollmentPlatformRestrictionsConfiguration' { 'All' ; break }
                'deviceAndAppManagementRoleDefinition' { 'N/A' ; break }
                default {
                    if ("$platforms" -ne '') { $platforms -replace 'Windows\d+','Windows' }
                    elseif ($Resource -in ('deviceManagement/roleassignments', 'deviceManagement/roleScopeTags')) { 'N/A' }
                    elseif ($Resource -match 'ios|apple') { 'iOS/iPadOS' }
                    elseif ($Resource -match 'deviceShellScripts') { 'macOS' }
                    elseif ($Resource -match 'android') { 'Android' }
                    elseif ($Resource -match 'windows|groupPolicyConfigurations|deviceManagementScripts|deviceHealthScripts|virtualEndpoint') { 'Windows' }
                    elseif ($Resource -match 'targetedManagedAppConfigurations|intuneBrandingProfiles|termsAndConditions') { 'All' }
                    elseif ($templateName -match 'Windows') { 'Windows' }
                    else {
                        $(
                            switch -regex ($displayName) {
                                '\bWindows' { 'Windows' }
                                '\bandroid' { 'Android' }
                                '\b(macOS|mac)\b' { 'macOS' }
                                '\b(ios|iPad|iPhone|apple)' { 'iOS/iPadOS' }
                                '\b(linux|unix)' { 'Linux' }
                                Default {
                                    if ($id -match 'DefaultLimit') { 'All' }
                                    else {
                                        "Unknown ($odataType | $Resource)" -replace ' \( \|',' (' -replace '\| \)',')'
                                    }
                                }
                            }
                        ) -join ', '
                    }
                }
            }
        )
        [String]$PolicyType = $(
            if ("$TemplateName" -ne '') {
                # deviceManagement/configurationPolicies
                $templateName
            }
            elseif (("$TemplateName" -eq '') -and ("$technologies" -ne '')) {
                # Settings catalog have technologies property
                'Settings Catalog'
            }
            elseif ("$odataType" -ne '') {
                switch -regex ($odataType) {
                    'macOSDmgApp' { 'macOS app (DMG)'; break }
                    'androidLobApp' { 'Android line-of-business app'; break }
                    'androidStoreApp' { 'Android store app' ; break }
                    'androidManagedStoreWebApp' { 'Managed Google Play web link' ; break }
                    'androidManagedStoreApp' { 'Managed Google Play store app' ; break }
                    'iosiPadOSWebClip' { 'iOS/iPadOS web clip' ; break }
                    'iosLobApp' { 'iOS line-of-business app' ; break }
                    'iosStoreApp' { 'iOS store app' ; break }
                    'iosVppApp' { 'iOS volume purchase program app' ; break }
                    'macOSMicrosoftEdgeApp' { 'Microsoft Edge (macOS)' ; break }
                    'macOSOfficeSuiteApp' { 'macOS Office Suite' ; break }
                    'macOSLobApp' { 'macOS line-of-business app' ; break }
                    'macOSPkgApp' { 'macOS app (PKG)' ; break }
                    'macOsVppApp' { 'macOS volume purchase program app' ; break }
                    'macOSEndpointProtectionConfiguration' { 'Endpoint protection' ; break }
                    'managedAndroidStoreApp' { 'Managed Google Play store app' ; break }
                    'managedIOSStoreApp' { 'Built-in iOS app' ; break }
                    'mobileLobApp' { 'macOS app (PKG)' ; break }
                    'webApp' { 'Web link' ; break }
                    'win32LobApp' { 'Windows app (Win32)' ; break }
                    'officeSuiteApp' { 'Microsoft 365 Apps (Windows 10 and later)' ; break }
                    'winGetApp' { 'Microsoft Store app (new)' ; break }
                    'VpnConfiguration' { 'VPN' ; break }
                    'deviceEnrollmentPlatformRestrictions*Configuration' { 'Enrollment restrictions' ; break }
                    'deviceEnrollmentLimitConfiguration' { 'Enrollment device limit restrictions' ; break }
                    'deviceEnrollmentNotificationConfiguration' { 'Enrollment notifications' ; break }
                    'deviceEnrollmentWindowsHelloForBusinessConfiguration' { 'Windows Hello for Business' ; break }
                    'windowsRestoreDeviceEnrollmentConfiguration' { 'Windows Backup and Restore' ; break }
                    'azureADWindowsAutopilotDeploymentProfile' { 'Windows Autopilot Deployment profiles' ; break }
                    'windows10EnrollmentCompletionPageConfiguration' { 'Enrollment status page' ; break }
                    'CompliancePolicy' { 'Compliance policy' ; break }
                    'General(Device)*Configuration' { 'Device restrictions' ; break }
                    'activeDirectoryWindowsAutopilotDeploymentProfile' { 'Autopilot deployment profile (hybrid)' ; break }
                    'CustomConfiguration' { 'Custom' ; break }
                    'WiFiConfiguration|windowsWifiEnterpriseEAPConfiguration' { 'Wi-Fi' ; break }
                    'ScepCertificateProfile' { 'SCEP certificate' ; break }
                    'TrustedRootCertificate' { 'Trusted certificate' ; break }
                    'FeaturesConfiguration' { 'Device features' ; break }
                    'iosUpdateConfiguration' { 'iOS/iPadOS updates (deprecated)' ; break }
                    'macOSSoftwareUpdateConfiguration' { 'macOS updates (deprecated)' ; break }
                    'windowsDomainJoinConfiguration' { 'Domain join'; break }
                    'windowsHealthMonitoringConfiguration' { 'Windows health monitoring'; break }
                    'windowsUpdateForBusinessConfiguration' { 'Update ring for Windows 10 and later'; break }
                    'macOSCustomAppConfiguration' { 'Preference file'; break }
                    'AppConfiguration' { 'Managed devices'; break }
                    'deviceAndAppManagementRoleDefinition' { 'Role definition' ; break }
                    'windowsWiredNetworkConfiguration' { 'Wired network' ; break }
                    Default { $odataType; break }
                }
            }
            else {
                switch -regex ($Resource) {
                    'deviceManagement/roleassignments' { 'Role assignment' }
                    'deviceManagement/roleScopeTags' { 'Scope tag' }
                    'windowsFeatureUpdateProfiles' { 'Feature Update Profiles'; break }
                    'windowsQualityUpdateProfiles' { 'Quality Update Profiles'; break }
                    'windowsDriverUpdateProfiles' { 'Driver Update Profiles'; break }
                    'groupPolicyConfigurations' { 'Administrative Templates'; break }
                    'targetedManagedAppConfigurations' { 'Managed apps'; break }
                    'iosLobAppProvisioningConfigurations' { 'iOS app provisioning profiles'; break }
                    'AppProtections' { 'App protection'; break }
                    'appleUserInitiatedEnrollmentProfiles' { 'Enrollment types'; break }
                    'deviceHealthScripts' { 'Remediation'; break }
                    'deviceManagementScripts' { 'Platform PowerShell script'; break }
                    'deviceShellScripts' { 'Platform Shell script'; break }
                    'virtualEndpoint/provisioningPolicies' { 'W365 Provisioning policies'; break }
                    'virtualEndpoint/userSettings' { 'W365 User settings'; break }
                    default { $Resource; break }
                }
            }
        )

        [PSCustomObject]@{
            id       = $id
            Platform = $PlatformName
            Type     = $PolicyType
        }
    }
}


function Resolve-IntuneConfigurationPolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$PolicyId,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [PSCustomObject[]]$Instance,

        [Parameter(Mandatory = $true, Position = 1)]
        [PSCustomObject[]]$Definition,

        [Parameter(Position = 2)]
        [AllowEmptyString()]
        [String]$SettingParentName,

        [Parameter(Position = 3)]
        [Hashtable]$CategoryList
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        $PropertyList = ('choiceSettingValue', 'simpleSettingCollectionValue', 'simpleSettingValue', 'choiceSettingCollectionValue', 'groupSettingCollectionValue')
    }
    process {
        foreach ($SettingInstance in $Instance) {
            if ($null -eq $SettingInstance) { continue }
            # Get the type of setting
            [String]$SettingType = $SettingInstance | Get-Member -MemberType Properties -Name $PropertyList | Select-Object -ExpandProperty Name -First 1 # |Where-Object { $_ -notin ('@odata.type', 'settingDefinitionId', 'settingInstanceTemplateReference', 'auditRuleInformation') }
            if (($SettingType -eq '') -and ($null -eq $SettingInstance.children)) {
                Write-Warning -Message "[$InvocationName] {$PolicyId} Could not find any actionable property for this setting instance: $($SettingInstance | ConvertTo-Json -Depth 5 -Compress)"
                continue
            }
            # SettingDefinition holds all the information about a setting (display name, path, registry, default, etc.)
            $SettingDefinition = $Definition | Where-Object -Property id -EQ $SettingInstance.settingDefinitionId
            [String]$SettingDefDisplayName = "$($SettingDefinition.displayName)".Trim()
            [String]$SettingDefName = "$($SettingDefinition.name)".Trim()
            [String[]]$Keywords = $SettingDefinition.keywords
            # The registry key associated with the setting is also listed in the keywords (grab the one keyword that starts with either SOFTWARE or SYSTEM and that is followed by "\")
            [String]$RedirectKey = $Keywords.where({ $_ -match '^(SOFTWARE|SYSTEM)\\' })
            if ("$RedirectKey" -eq '') {
                [String[]]$Keywords = $Definition.keywords
                [String]$RedirectKey = ($Keywords.where({ $_ -match '^(SOFTWARE|SYSTEM)\\' })) | Select-Object -First 1
            }
            if ("$RedirectKey" -eq '') { $RedirectedValue = '' }
            else {
                $KeyIndex = $Keywords.IndexOf($RedirectKey)
                if (($KeyIndex -ne -1) -and (($KeyIndex + 1) -lt $Keywords.Count)) {
                    # The registry value name comes right after the key in the keyword list
                    [String]$RedirectedValue = $Keywords[($KeyIndex + 1)]
                }
                else {
                    [String]$RedirectedValue = $SettingDefName
                }
            }
            # The setting path is usually the keyword that starts with \
            if (($CategoryList.Count -gt 0) -and ("$($SettingDefinition.categoryId)" -ne '')) {
                [String]$SettingPath = $CategoryList["$($SettingDefinition.categoryId)"]
            }
            if ("$SettingPath" -eq '') {
                [String]$SettingPath = "$(($SettingDefinition.keywords).where({$_ -like '\*'}))".Trim('\')
                if ("$SettingPath" -eq '') {
                    # The setting path is the last keyword that does not match the setting name
                    [String]$SettingPath = (($SettingDefinition.keywords).Where({ $_ -notin ($SettingDefDisplayName, $SettingDefName, $RedirectKey, $RedirectedValue, ($SettingDefName -replace '\s+'), ($SettingDefDisplayName -replace ' \((User|device)\)')) })) | Select-Object -Last 1
                }
            }

            # settingInstanceTemplateReference is null when the policy is a "Settings Catalog"
            [String]$TemplateId = $SettingInstance.settingInstanceTemplateReference.settingInstanceTemplateId
            if (("$TemplateId" -eq '') -and ($SettingDefinition.offsetUri -match '/ADMX_(?<ADMX>[^/]+)')) {
                [String]$TemplateId = "$($Matches['ADMX']).admx"
                #[String]$SettingPath = "Administrative Templates\$SettingPath"
            }
            # The documentation url can be obtained by using the infoUrls property along with the offsetUri
            # This is not 100% reliable but it can still help to get to the doc faster
            [String]$SettingUri = "$($SettingDefinition.baseUri)$($SettingDefinition.offsetUri)".Trim()
            [String]$infoUrl = $(
                [String]$url = ''
                # ToLower() has to be used for the link to work
                if (($SettingDefinition.infoUrls | Measure-Object).Count -gt 0) {
                    [String]$url = ($SettingDefinition.infoUrls).where({ "$_".Trim() -ne '' })[0]
                }
                else {
                    [String]$url = $Definition.infoUrls | Select-Object -Unique | Where-Object { "$_" -ne '' } | Select-Object -First 1
                }
                if ($SettingUri -match '\.\/(?<Scope>User|Device)?\/?Vendor\/(?<Vendor>[^\/]+)(?<Policy>\/Policy)?(?<Config>\/Config)?\/(?<AreaName>[^\/]+)\/?(?<End>.*)') {
                    [String]$AreaName = $Matches['AreaName'] # Retrieve the area name and remove it from the setting part in the url
                    [String]$url = "$Url" -replace "#$AreaName", '#'
                }
                [String]$url = "$Url" -replace '#admx-[^-]+-', '#' # Remove "admx-<name>-" from the setting part in the url
                if ("$url" -eq '') {
                    # Use the Resolve-SettingUriToUrl function to try and resolve the url, otherwise set it blank
                    # "~" in the uri indicates that the setting is part of an admx which has no documentation (Ex: Office)
                    if (($SettingUri.StartsWith('.')) -and ($SettingUri.IndexOf('~') -eq -1)) { (Resolve-SettingUriToUrl -settingUri "$SettingUri").Url }
                    else { '' }
                }
                elseif ("$url".IndexOf('#') -gt 0) { "$url" } # The url is already formatted to point to a single setting
                elseif ($SettingDefinition.offsetUri -match '\{[^\}]+\}') {
                    $MatchHash = @{}
                    $OffsetUri = $SettingDefinition.offsetUri
                    # Retrieve all the index names from the id property
                    ($_.id | Select-String -Pattern '\{[^\}]+\}' -AllMatches).Matches.Groups |
                        ForEach-Object -Begin { $index = 0 } -Process { $MatchHash["$index"] = "$($_.Value -replace '[\{\}]')"; $index++ }
                    # Replace the indexes in the offsetUri
                    ($OffsetUri | Select-String -Pattern '\{[^\}]+\}' -AllMatches).Matches.Groups |
                        ForEach-Object -Begin { $index = 0 } -Process { $OffsetUri = $OffsetUri.Replace("$($_.Value)",$MatchHash["$index"]); $index++ }
                    $MatchHash.Clear()
                    "$("$url".TrimEnd('/'))#$("$Offseturi".ToLower().Replace('-','_'))"
                }
                elseif (($SettingDefinition.rootDefinitionId.Split('_')[-1] -eq $SettingDefinition.offsetUri.Split('/')[-1])) {
                    "$("$url".TrimEnd('/'))#$("$($SettingDefinition.offsetUri.Split('/')[-1])".ToLower().Replace('-','_'))"
                }
                else { "$("$url".Split('#')[0].TrimEnd('/'))#$("$SettingDefName".ToLower().Replace('-','_'))".TrimEnd('#') }
            )
            $PossibleValues = $null
            $SettingInstanceItem = $SettingInstance.$SettingType
            switch -regex ($SettingType) {
                'choiceSetting(Collection)*Value' {
                    $PossibleValues = $SettingDefinition.options | Select-Object -Property itemId, displayName, @{Label = 'Value'; Expression = { $_.optionValue.value } }
                    $Default = $PossibleValues | Where-Object -Property itemid -EQ $SettingDefinition.defaultOptionId
                    $Value = $PossibleValues | Where-Object -Property itemid -In $SettingInstanceItem.value
                    break
                }
                'groupSettingCollectionValue' {
                    if ($null -eq $SettingInstanceItem.Children) {
                        Write-Warning -Message "[$PolicyId] Could not find any child in $($SettingInstanceItem | ConvertTo-Json -Compress -Depth 15)"
                    }
                    break
                }
                'simpleSettingCollectionValue|simpleSettingValue' {
                    $Default = [PSCustomObject]@{value = $SettingDefinition.defaultValue.value; displayName = '' }
                    $Value = [PSCustomObject]@{value = $SettingInstanceItem.value; displayName = '' }
                    break
                }
                Default {
                    Write-Warning -Message "[$PolicyId] Unknown type: $_"
                }
            }

            if ("$SettingDefDisplayName" -eq '') {
                # Default to the name of the settings when display name is not available (should not occur but it does with Bitlocker policies for example)
                $SettingDefDisplayName = "$($SettingDefinition.Name)".Trim()
            }
            if ($SettingType -ne 'groupSettingCollectionValue') {
                [PSCustomObject]@{
                    DefinitionId      = $SettingInstance.settingDefinitionId
                    Type              = $SettingType
                    SettingPath       = "$SettingPath".Trim('\')
                    TemplateId        = $TemplateId
                    scope             = $(
                        switch -Wildcard ($SettingDefinition.baseUri) {
                            './Device*' { 'Device'; break }
                            './User*' { 'User'; break }
                            default { 'Device'; break }
                        }
                    )
                    ParentSettingName = $SettingParentName
                    Name              = $SettingDefDisplayName
                    Enabled           = $true
                    Value             = $Value.Value
                    ValueText         = "$($Value.displayName)"
                    defaultValue      = $Default.Value
                    defaultValueText  = "$($Default.displayName)"
                    possibleValues    = $PossibleValues | Select-Object -Property displayName, Value
                    RegistryKey       = $RedirectKey
                    RegistryName      = $RedirectedValue
                    infoUrl           = "$infoUrl"
                    settingUri        = $SettingUri
                    applicability     = $SettingDefinition.applicability
                    description       = $SettingDefinition.description
                    #settingUsage        = $SettingDefinition.settingUsage
                }
            }

            if (($SettingInstanceItem.Children | Measure-Object).Count -gt 0) {
                $CParams = @{
                    PolicyId     = $PolicyId
                    Definition   = $Definition
                    CategoryList = $CategoryList
                }
                if ($settingdefinition.id -match '_firewallrules_') {
                    <# if ($SettingInstanceItem.Children.Count -le ($SettingInstanceItem.Children.settingDefinitionId | Select-Object -Unique | Measure-Object).Count) {
                        # Single rule in the policy
                        [String]$SettingParentName = ($SettingInstanceItem.Children).where({ $_.settingDefinitionId -like '*_name' }).simpleSettingValue.value
                        Resolve-IntuneConfigurationPolicy -PolicyId $PolicyId -Instance $($SettingInstanceItem.Children | Sort-Object -Property settingDefinitionId) -Definition $Definition -SettingParentName $SettingParentName
                    }
                    else { #>
                    # Several rules in the policy.
                    # Rules' settings are not always in the same order.
                    # Sometimes the name setting comes after the other settings related to a rule, sometimes it's the first setting
                    $GroupedChild = New-Object -TypeName 'System.Collections.ArrayList'
                    foreach ($Child in $SettingInstanceItem.Children) {
                        $Index = $GroupedChild.Add($Child)
                        if (($Child.settingDefinitionId -like '*_name') -and ($GroupedChild.Count -gt 1)) {
                            # The name is located after the other settings
                            [String]$SettingParentName = $Child.simpleSettingValue.value
                            Resolve-IntuneConfigurationPolicy -Instance $($GroupedChild | Sort-Object -Property settingDefinitionId) -SettingParentName $SettingParentName @CParams
                            $GroupedChild.Clear()
                            $SettingParentName = ''
                        }
                        elseif ($Child.settingDefinitionId -like '*_name') {
                            # The name is the first setting
                            [String]$SettingParentName = $Child.simpleSettingValue.value
                        }
                        elseif (($Child -eq $SettingInstanceItem.Children[-1])) {
                            # Last child setting
                            Resolve-IntuneConfigurationPolicy -Instance $($GroupedChild | Sort-Object -Property settingDefinitionId) -SettingParentName $SettingParentName @CParams
                            $GroupedChild.Clear()
                            $SettingParentName = ''
                        }
                        elseif (($SettingInstanceItem.Children[($Index + 1)].settingDefinitionId -like '*_name') -and ($SettingParentName -ne '')) {
                            # The name is the first setting so this instance is the last setting of the current group
                            Resolve-IntuneConfigurationPolicy -Instance $($GroupedChild | Sort-Object -Property settingDefinitionId) -SettingParentName $SettingParentName @CParams
                            $GroupedChild.Clear()
                            $SettingParentName = ''
                        }
                    }
                    $GroupedChild.Clear()
                    #}
                }
                else {
                    [String]$SettingParentName = $SettingDefDisplayName
                    Resolve-IntuneConfigurationPolicy -Instance $($SettingInstanceItem.Children | Sort-Object -Property settingDefinitionId) -SettingParentName $SettingParentName @CParams
                }
                $CParams.Clear()
            }
        }
    }
}


function Resolve-SettingUriToUrl {
    <#
.SYNOPSIS
    Parse a CSP setting uri (OmaUri) to retrieve the link to its documentation.

.DESCRIPTION
    Parse a CSP setting uri (OmaUri) to retrieve the link to its documentation on https://learn.microsoft.com/en-us/windows/client-management/mdm.

.PARAMETER settingUri
    Uri of the setting

.EXAMPLE
    PS C:\> Resolve-SettingUriToUrl -SettingUri './Device/Vendor/MSFT/Policy/Config/Accounts/AllowAddingNonMicrosoftAccountsManually','./Device/Vendor/MSFT/Policy/Config/ADMX_AppxPackageManager/AllowDeploymentInSpecialProfiles'

.EXAMPLE
    PS C:\> @(
        './Device/Vendor/MSFT/DMClient/Provider/MS DM Server/FirstSyncStatus/SkipUserStatusPage'
        './Device/Vendor/MSFT/RootCATrustedCertificates/TrustedPublisher/f987e6da17db44a4a5d96167bcb9efa7/EncodedCertificate'
        './Vendor/MSFT/AppLocker/ApplicationLaunchRestrictions/apprulset0001/StoreApps/Policy'
        './Vendor/MSFT/AppLocker/ApplicationLaunchRestrictions/apps/DLL/Policy'
        './Vendor/MSFT/AppLocker/ApplicationLaunchRestrictions/apps/EXE/Policy'
        './Vendor/MSFT/AppLocker/ApplicationLaunchRestrictions/apps/MSI/Policy'
        './Vendor/MSFT/AppLocker/ApplicationLaunchRestrictions/apps/Script/Policy'
        './Vendor/MSFT/AppLocker/ApplicationLaunchRestrictions/apps/StoreApps/Policy'
        './Vendor/MSFT/WiFi/Profile/WifiSSID/WlanXml'
    ) | Resolve-SettingUriToUrl | ft -AutoSize

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-04-01
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('CSP','uri')]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [String[]]$settingUri
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        $CSPBaseUrl = 'https://learn.microsoft.com/en-us/windows/client-management/mdm'
        # Some uri contain a named id
        $UriExceptionList = @(
            @{Pattern = '(DMClient/Provider)/[^\/]+'; id = 'ProviderId' }
            @{Pattern = '(WiFi/Profile)/[^\/]+'; id = 'ssid' }
            @{Pattern = '(RootCATrustedCertificates/[^\/]+)/[^\/]+'; id = 'certhash' }
            @{Pattern = '(ApplicationLaunchRestrictions)/app[A-Za-z\d]+'; id = 'grouping' }
            @{Pattern = '(MdmStore/FirewallRules)/[^\/]+'; id = 'firewallrulename' }
            @{Pattern = '(MdmStore/HyperVFirewallRules)/[^\/]+'; id = 'firewallrulename' }
            @{Pattern = '(MdmStore/HyperVVMSettings)/[^\/]+'; id = 'VMCreatorId' }
            @{Pattern = '(MSFT/MultiSIM)/[^\/]+/Slots/[^\/]+'; id = 'modemidslotsslotid' }
            @{Pattern = '(MSFT/MultiSIM)/[^\/]+'; id = 'modemid' }
            @{Pattern = '(eUICCs/Default/DownloadServers)/[^\/]+'; id = 'servername' }
            @{Pattern = '(eUICCs/Default/Profiles)/[^\/]+'; id = 'iccid' }
            @{Pattern = '(WirelessNetworkPreference/ConnectionProfiles)/[^\/]+'; id = 'connectionprofileid' }
            @{Pattern = '(PrinterProvisioning/UPPrinterInstalls)/[^\/]+'; id = 'printersharedid' }
            @{Pattern = '(MSFT/PassportForWork)/[^\/]+'; id = 'tenantid' }
            @{Pattern = '(MSFT/AgentGovernance)/[^\/]+'; id = 'policyid' }
        )
        # Some policy names change in the url
        $PolicyNameExceptionList = @{
            'RootCATrustedCertificates' = 'rootcacertificates'
        }
        # Some url end must contain the scope (device) before the name of the setting
        $IncludeScopeFor = @(
            'PassportForWork'
            'WiFi'
        )
    }
    process {
        foreach ($Item in $settingUri) {
            if ("$Item".Trim() -eq '') { continue }
            if ($Item -like '*PrivilegeManagement/Elevation*') {
                # No CSP documentation for Endpoint Privilege Management
                [PSCustomObject]@{
                    settingUri  = $Item
                    PolicyName  = 'PrivilegeManagement'
                    url         = 'https://learn.microsoft.com/en-us/intune/intune-service/protect/epm-overview'
                    SettingName = $Item.Split('/')[-1]
                }
                continue
            }
            if ($Item -like './enrollment/autopilot*') { continue }
            $CurrentItem = $Item
            foreach ($Exception in $UriExceptionList) {
                if ($CurrentItem -match $Exception.Pattern) {
                    $CurrentItem = $CurrentItem -replace $Exception.Pattern, ('$1/{0}' -f $Exception.id)
                    break
                }
            }
            if ($CurrentItem -match '/(\{[^\}]+\})') {
                Write-Warning -Message "[$InvocationName] uri [$Item] contains an id ($($Matches[1])) that can't be translated automatically (Add it to `$UriExceptionList)"
            }
            switch -Regex ($CurrentItem) {
                '\.\/(?<Scope>User|Device)?\/?Vendor\/(?<Vendor>[^\/]+)(?<Policy>\/Policy)?(?<Config>\/Config)?\/(?<PolicyName>[^\/]+)\/?(?<End>.*)' {
                    [String]$PolicyName = $Matches['PolicyName']
                    $Scope = ''
                    if ($null -ne $Matches['Scope']) {
                        [String]$Scope = $Matches['Scope']
                    }
                    if (($Scope -eq '') -and ($PolicyName -in $IncludeScopeFor)) {
                        $Scope = 'device'
                    }
                    [String]$End = $Matches['End']
                    if ($PolicyNameExceptionList["$PolicyName"]) {
                        $PolicyName = $PolicyNameExceptionList["$PolicyName"]
                    }
                    if ($PolicyName -like 'ADMX_*') {
                        $url = "$CSPBaseUrl/policy-csp-$($PolicyName.Replace('ADMX_','admx-'))"
                        #$End = $End.Replace("admx-$($PolicyName.Split('_')[-1])")
                    }
                    elseif ($Matches['Config'] -eq '/Config') {
                        $Url = "$CSPBaseUrl/policy-csp-$PolicyName"
                    }
                    else {
                        $Url = "$CSPBaseUrl/$PolicyName-csp"
                    }

                    [String[]]$SplitedEnd = "$End".Split('/')
                    if ($SplitedEnd.Count -gt 0) {
                        if (($Matches['Policy'] -ne '/Policy') -or ($PolicyName -in $IncludeScopeFor)) {
                            $Url = "$Url#$Scope$($SplitedEnd -join '')"
                        }
                        else {
                            $Url = "$Url#$($SplitedEnd -join '')"
                        }
                    }
                    break
                }
                Default {
                    $PolicyName = ''
                    $url = ''
                    break
                }
            }

            #$policyDetailsURL = "$CSPBaseUrl/policy-csp-$policyAreaName#$(($policyAreaName).tolower())-$(($settingName).tolower())"
            #https://learn.microsoft.com/en-us/deployedge/configure-edge-with-mdm
            #https://learn.microsoft.com/en-us/windows/client-management/win32-and-centennial-app-policy-configuration
            [PSCUstomObject]@{
                settingUri  = $Item
                AreaName    = "$PolicyName"
                URL         = "$URL".ToLower()
                SettingName = $Item.Split('/')[-1]
            }
        }
    }
}


function Get-IntunePolicy {
    <#
.SYNOPSIS
    Get information about Intune policies.

.DESCRIPTION
    Get information about Intune policies including the following:
        - Type: policy type (Ex: Settings Catalog, Administrative template, ...)
        - createdDateTime: Policy's creation date time (ISO 8601)
        - creationSource:
        - description
        - lastModifiedDateTime: Policy's last modification date time (ISO 8601)
        - Name: Name of the policy
        - platforms (Windows, android, iOS, macOS, Linux)
        - ScopeTags
        - settingsCount: Number of settings configured in the policy
        - technologies
        - id
        - settings: List of the settings configured in the policy
                DefinitionId        = Definition id of the setting
                Type                = Type of the setting
                SettingPath         = Setting path as shown in the portal
                Templateid          = id of the policy template
                scope               = Device/User
                ParentSettingName   = Parent setting name, if any
                Name                = Name of the setting
                Enabled             = True/False
                Value               = Raw value
                ValueText           = Text associated with the value, if any
                defaultValue        = Raw default value
                defaultValueText    = Text associated with the default value, if any
                possibleValues      = Possible values of the setting (raw value, display name)
                RegistryKey         = Registry key associated with the setting, if any
                RegistryName        = Registry value name associated with the setting, if any
                infoUrl             = Link to the setting's documentation
                settingUri          = OMA-URI linked to the setting
                applicability       = Setting's applicability information
                description         = Description of the setting

        - assignments: List of assignments linked to the policy (Empty if -Assignment is not used)
                AssignmentType = Include/Exclude
                Target         = Name of the target (All devices, All users, group name)
                FilterType     = Filter type (Include/Exclude)
                FilterName     = Name of the filter

.PARAMETER id
    Id of the policy.

.PARAMETER Platform
    Policy target platform (Windows, android, iOS, macOS, Linux)

.PARAMETER Assignment
    Add the policy assignments to the result.

.EXAMPLE
    PS C:\>

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-09-30
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('id')]
        [String[]]$Policyid,

        [Parameter(Position = 1)]
        [ValidateSet('Windows', 'android', 'iOS', 'macOS', 'Linux')]
        [String[]]$Platform,

        [Switch]$Assignment
    )

    begin {
        $InvocationName = $MyInvocation.InvocationName

        $OmaPlainTextValueAuthorized = (Get-MgContext).Scopes -contains 'DeviceManagementConfiguration.ReadWrite.All'
        $RBACAuthorized = (Get-MgContext).Scopes -match 'DeviceManagementRBAC'
        if ($RBACAuthorized -eq $false) {
            Write-Warning -Message "[$InvocationName] You are not authorized to list Intune RBAC roles (missing DeviceManagementRBAC.Read.All)"
        }
        if ($OmaPlainTextValueAuthorized -eq $false) {
            Write-Warning -Message "[$InvocationName] You are not authorized to translate OmaURI encrypted values (missing DeviceManagementConfiguration.ReadWrite.All). They will appear as **** in the value filed."
        }
        if ($Platform.Count -eq 0) {
            $Platform = 'Windows', 'android', 'iOS', 'macOS'
        }
        $TextInfo = (Get-Culture).TextInfo
        if ((Get-MgContext).scopes | Where-Object { $_ -like 'DeviceManagementManagedDevices.Read*' }) {
            $null = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/managedDevices' -Select id -Advanced Count -EA Stop -Verbose:$false
            $AllDevicesCount = $_GraphAPICount # Intune devices count (the variable $_GraphAPICount is created by Invoke-MgGraphRequestSingle to hold @odata.count)
        }
        elseif ((Get-MgContext).scopes | Where-Object { $_ -like 'device.Read*' }) {
            Write-Warning -Message "[$InvocationName] Could not get the Intune device count due to a lack of permission (DeviceManagementManagedDevices.Read.All), defaulting to retrieve the Entra device count"
            $AllDevicesCount = Invoke-MgGraphRequestSingle -Resource 'devices/$count' -Advanced ConsistencyLevel -ErrorAction Stop -Verbose:$false # Entra ID devices count
        }
        else {
            throw "[$InvocationName] Failed to get the devices count"
        }
        $AllUsersCount = Invoke-MgGraphRequestSingle -Resource 'users/$count' -Advanced ConsistencyLevel -EA SilentlyContinue -Verbose:$false # Users count
    }
    process {
        if ($Policyid.Count -eq 0) {
            Write-Verbose -Message "[$InvocationName] Fetching every Configuration policies"
            [String[]]$ConfPolicyid = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/configurationPolicies' -APIVersion 'beta' -Select id | Select-Object -ExpandProperty id
            if (($Platform.Count -eq 0) -or ($Platform -contains 'Windows')) {
                Write-Verbose -Message "[$InvocationName] Fetching every Group Policy policies"
                [String[]]$AdminTemplateId = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/groupPolicyConfigurations' -APIVersion 'beta' -Select id | Select-Object -ExpandProperty id
            }
            Write-Verbose -Message "[$InvocationName] Fetching every Device Configuration policies"
            [String[]]$CustomId = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/deviceConfigurations' -APIVersion 'beta' -Select id | Select-Object -ExpandProperty id
            #[String[]]$MobileAppId = Invoke-MgGraphRequestSingle -Resource 'deviceAppManagement/mobileAppConfigurations' -APIVersion 'beta' -Select id | Select-Object -ExpandProperty id
            #[String[]]$AccessResourceId = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/resourceAccessProfiles' -APIVersion 'beta' -Select id | Select-Object -ExpandProperty id
        }
        else {
            # Verify the type of each id (configurationPolicies, groupPolicyConfigurations, deviceConfigurations, resourceAccessProfiles, ...)
            [hashtable[]]$Hashtable = $(
                foreach ($id in $Policyid) {
                    @{
                        id     = '{0}_ConfPolicyid' -f $id
                        method = 'GET'
                        url    = 'deviceManagement/configurationPolicies/{0}?$select=id' -f $id
                    }
                    @{
                        id     = '{0}_AdminTemplateId' -f $id
                        method = 'GET'
                        url    = 'deviceManagement/groupPolicyConfigurations/{0}?$select=id' -f $id
                    }
                    @{
                        id     = '{0}_CustomId' -f $id
                        method = 'GET'
                        url    = 'deviceManagement/deviceConfigurations/{0}?$select=id' -f $id
                    }
                }
            )
            Write-Verbose -Message "[$InvocationName] Mapping $($Policyid.Count) policy ids to their respective type"
            [String[]]$PolicyType = Invoke-MgGraphRequestBatch -APIVersion beta -DoNotLogErrors -Hashtable $Hashtable -MaxRetry 6 | Where-Object -Property Status -EQ 200 | Select-Object -ExpandProperty id
            [String[]]$ConfPolicyid = ($PolicyType | Where-Object { $_ -like '*_ConfPolicyid' }) -replace '_ConfPolicyid'
            [String[]]$AdminTemplateId = ($PolicyType | Where-Object { $_ -like '*_AdminTemplateId' }) -replace '_AdminTemplateId'
            [String[]]$CustomId = ($PolicyType | Where-Object { $_ -like '*_CustomId' }) -replace '_CustomId'
        }
        [String[]]$Policyid = $ConfPolicyid + $AdminTemplateId + $CustomId

        if ($ConfPolicyid.Count -gt 0) {
            $CategoryList = Get-IntuneSettingCategory -AsHashtable -NameOnly
        }
        else {
            $CategoryList = @{}
        }

        # Prepare the batch hashtable
        [HashTable[]]$HashTable = $(
            foreach ($id in $ConfPolicyid) {
                # https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceconfigv2-devicemanagementconfigurationpolicy?view=graph-rest-beta
                @{
                    id     = 'ConfProfile_policy_{0}' -f $id
                    method = 'GET'
                    url    = "/deviceManagement/configurationPolicies('$id')"
                }

                @{
                    id     = 'ConfProfile_settings_{0}' -f $id
                    method = 'GET'
                    url    = "/deviceManagement/configurationPolicies('$id')/settings?`$expand=settingDefinitions"
                }

                if ($Assignment.IsPresent) {
                    @{
                        id     = 'ConfProfile_assignments_{0}' -f $id
                        method = 'GET'
                        url    = "/deviceManagement/configurationPolicies('$id')/assignments"
                    }
                }
            }
            foreach ($id in $CustomId) {
                # https://learn.microsoft.com/en-us/graph/api/resources/intune-shared-deviceconfiguration?view=graph-rest-beta
                @{
                    id     = 'Custom_policy_{0}' -f $id
                    method = 'GET'
                    url    = "/deviceManagement/deviceConfigurations('$id')"
                }

                if ($Assignment.IsPresent) {
                    @{
                        id     = 'Custom_assignments_{0}' -f $id
                        method = 'GET'
                        url    = "/deviceManagement/deviceConfigurations('$id')/assignments"
                    }
                }
            }
            foreach ($id in $AdminTemplateId) {
                # https://learn.microsoft.com/en-us/graph/api/resources/intune-grouppolicy-grouppolicyconfiguration?view=graph-rest-beta
                @{
                    id     = 'ADMX_policy_{0}' -f $id
                    method = 'GET'
                    url    = "/deviceManagement/groupPolicyConfigurations('$id')"
                }

                @{
                    id     = 'ADMX_settings_{0}' -f $id
                    method = 'GET'
                    url    = "/deviceManagement/groupPolicyConfigurations('$id')/definitionValues?`$expand=definition,presentationValues"
                }

                if ($Assignment.IsPresent) {
                    @{
                        id     = 'ADMX_assignments_{0}' -f $id
                        method = 'GET'
                        url    = "/deviceManagement/groupPolicyConfigurations('$id')/assignments"
                    }
                }
            }

            if ($Assignment.IsPresent) {
                if ($RBACAuthorized) {
                    @{
                        id     = 'ScopeTags'
                        method = 'GET'
                        url    = '/deviceManagement/roleScopeTags?$select=id,displayname'
                    }
                }
                @{
                    id     = 'Filters'
                    method = 'GET'
                    url    = '/deviceManagement/assignmentFilters?$select=id,displayName'
                }
            }
        )
        Write-Verbose -Message "[$InvocationName] Fetching every individual policy along with its settings and assignments ($($Hashtable.Count) requests). This can take a while..."
        $BatchResult = Invoke-MgGraphRequestBatch -APIVersion beta -Hashtable $HashTable -MaxRetry 4 -DoNotLogErrors

        $ScopeTagList = ($BatchResult | Where-Object -Property id -EQ 'ScopeTags').Body.Value
        $FilterList = ($BatchResult | Where-Object -Property id -EQ 'Filters').Body.Value
        [String[]]$ADMXCategoryIdList = ($BatchResult | Where-Object -Property id -Like 'ADMX_settings_*').Body.Value.definition.groupPolicyCategoryId | Select-Object -Unique | Where-Object { "$_" -ne '' }
        $ADMXPresValue = ($BatchResult | Where-Object -Property id -Like 'ADMX_settings_*').Body.Value.'presentationValues@odata.context' -replace '.+\$metadata#' | Select-Object -Unique |
            Select-Object -Property @{Label = 'BatchHashtable'; Expression = {
                    @{
                        # regex keeps only both guids xxxx_yyyy from: deviceManagement/groupPolicyConfigurations('xxxx')/definitionValues('yyyy')/presentationValues
                        id     = "$_" -replace "[^']+'([\w-]+)'[^']+'([\w-]+).+", '$1_$2'
                        method = 'GET'
                        url    = "$($_)?`$expand=presentation"
                    }
                }
            }
        if ($ADMXPresValue.keys.count -gt 0) {
            Start-Sleep -Seconds 5
            Write-Verbose -Message "[$InvocationName] Fetching $($ADMXPresValue.count) policy presentation value"
            # This endpoint is prown to throttling, hence the 2.5 seconds wait between each batch
            $ADMXPresentationValueList = Invoke-MgGraphRequestBatch -APIVersion beta -Hashtable $ADMXPresValue.BatchHashtable -WaitTime 2500 -MaxRetry 6 -DoNotLogErrors | Convert-PSObjectArrayToHashTable -idProperty id -Verbose:$false
        }
        if ($ADMXCategoryIdList.Count -gt 0) {
            Write-Verbose -Message "[$InvocationName] Fetching $($ADMXCategoryIdList.count) policy categories"
            $ADMXCategoryList = Invoke-MgGraphRequestBatch -APIVersion beta -Resource 'deviceManagement/groupPolicyCategories' -ObjectList $ADMXCategoryIdList -Select 'displayName','definitions' -Expand 'definitions($select=categoryPath,classType)' -DoNotLogErrors | Convert-PSObjectArrayToHashTable -idProperty id -Verbose:$false
        }

        if ($Assignment.IsPresent) {
            Write-Verbose -Message "[$InvocationName] Fetching every assignments"
            [String[]]$GroupIdList = ($BatchResult | Where-Object -Property id -Like '*assignments*').body.value.target |
                ForEach-Object {
                    if ($_.groupid) { $_.GroupId }
                    elseif ($_.targetGroupId) { $_.targetGroupId }
                    elseif (("$_" -match '\w{8}-\w{4}-\w{4}-\w{4}-\w{12}') ) { $_ }
                } | Select-Object -Unique
            Write-Verbose -Message "[$InvocationName] $($GroupIdList.Count) groups are used in assignments"
            if ($GroupIdList.Count -gt 0) {
                $GroupList = Get-EntraIdGroupInfo -id $GroupIdList -MembersCount -QuerySoftDeletedGroup
            }
        }
        foreach ($id in $Policyid) {
            $ResultSettingList = ($BatchResult | Where-Object -Property id -Like ('*_settings_{0}' -f $id)).body.value
            $SettingList = $(
                switch ($id) {
                    { $_ -in $ConfPolicyid } {
                        foreach ($Setting in $ResultSettingList) {
                            Resolve-IntuneConfigurationPolicy -PolicyId $id -Instance $setting.settingInstance -Definition $Setting.settingDefinitions -SettingParentName '' -CategoryList $CategoryList
                        }
                        break
                    }
                    { $_ -in $CustomId } {
                        $ResultSettingList = $null
                        $Policy = ($BatchResult | Where-Object -Property id -Like ('*_policy_{0}' -f $id)).body
                        if ($null -ne $Policy.omaSettings) {
                            foreach ($Setting in $Policy.omaSettings) {
                                [String]$infoUrl = (Resolve-SettingUriToUrl -settingUri "$($Setting.omaUri)").Url
                                $Value = $Setting.Value
                                if (($Setting.isEncrypted) -and ($OmaPlainTextValueAuthorized)) {
                                    $Value = Invoke-MgGraphRequestSingle -Resource ("/deviceManagement/deviceConfigurations/{0}/getOmaSettingPlainTextValue(secretReferenceValueId='{1}')" -f $Policy.id, $Setting.secretReferenceValueId) -APIVersion beta
                                }
                                [PSCustomObject]@{
                                    Type              = $Setting.'@odata.type'.Split('.')[-1] # Ex: #microsoft.graph.omaSettingInteger
                                    scope             = $(
                                        switch -Wildcard ($Setting.omaUri) {
                                            '*/Device/*' { 'Device'; break }
                                            '*/User/*' { 'User'; break }
                                            default { 'Device' }
                                        }
                                    )
                                    ParentSettingName = ''
                                    Name              = $Setting.displayName
                                    Enabled           = $true
                                    Value             = $value
                                    infoUrl           = "$infoUrl"
                                    settingUri        = $Setting.omaUri
                                    applicability     = [PSCustomObject]@{
                                        deviceManagementApplicabilityRuleOsEdition  = $Policy.deviceManagementApplicabilityRuleOsEdition
                                        deviceManagementApplicabilityRuleOsVersion  = $Policy.deviceManagementApplicabilityRuleOsVersion
                                        deviceManagementApplicabilityRuleDeviceMode = $Policy.deviceManagementApplicabilityRuleDeviceMode
                                    }
                                    description       = $Setting.description
                                }
                            }
                        }
                        else {
                            [String[]]$SettingNameList = $Policy |
                                Get-Member -MemberType Properties |
                                Where-Object -Property Name -NotIn ('@odata.context', '@odata.type', 'id', 'lastModifiedDateTime', 'roleScopeTagIds', 'supportsScopeTags', 'createdDateTime', 'displayName', 'version', 'deviceManagementApplicabilityRuleOsEdition', 'deviceManagementApplicabilityRuleOsVersion', 'deviceManagementApplicabilityRuleDeviceMode') |
                                Select-Object -ExpandProperty Name

                            foreach ($SettingName in $SettingNameList) {
                                [PSCustomObject]@{
                                    Type              = "$($Policy.'@odata.type')".Split('.')[-1]
                                    scope             = $(
                                        switch -Wildcard ($SettingDefinition.baseUri) {
                                            './Device*' { 'Device'; break }
                                            './User*' { 'User'; break }
                                            default { 'Device' }
                                        }
                                    )
                                    ParentSettingName = $Policy.displayName
                                    Name              = $SettingName
                                    Enabled           = $true
                                    Value             = $Policy.$SettingName
                                    infoUrl           = ''
                                    applicability     = [PSCustomObject]@{
                                        deviceManagementApplicabilityRuleOsEdition  = $Policy.deviceManagementApplicabilityRuleOsEdition
                                        deviceManagementApplicabilityRuleOsVersion  = $Policy.deviceManagementApplicabilityRuleOsVersion
                                        deviceManagementApplicabilityRuleDeviceMode = $Policy.deviceManagementApplicabilityRuleDeviceMode
                                    }
                                }
                            }
                            $AdditionalSettings = $(
                                switch -regex ($Policy.'@odata.type') {
                                    'CertificateProfile' {
                                        # Every certificate profile has a root certificate attatched but it needs to be queried
                                        $RootCertificate = Invoke-MgGraphRequestSingle -APIVersion 'beta' -Resource ('devicemanagement/deviceConfigurations/{0}/{1}/rootcertificate' -f $Policy.id, $Policy.'@odata.type'.TrimStart('#')) -Select displayName
                                        [PSCustomObject]@{Name = 'RootCertificate'; Value = $RootCertificate.displayName }
                                        break
                                    }
                                    'Wifi' {
                                        # Every Wifi profile has a root certificate attatched but it needs to be queried
                                        $HashTable = $(
                                            foreach ($CertType in ('rootCertificateForClientValidation','rootCertificatesForServerValidation')) {
                                                @{
                                                    id     = "$($Policy.id)-$CertType"
                                                    method = 'GET'
                                                    url    = 'devicemanagement/deviceConfigurations/{0}/{1}/{2}?$select=displayName' -f $Policy.id, $Policy.'@odata.type'.TrimStart('#'), $CertType
                                                }
                                            }
                                        )
                                        Invoke-MgGraphRequestBatch -APIVersion 'beta' -Hashtable $Hashtable -DoNotLogErrors |
                                            Where-Object -Property Status -EQ 200 |
                                            ForEach-Object {
                                                [PSCustomObject]@{Name = "$($_.id)".Split('-')[-1]; Value = $_.body.value.displayName }
                                            }
                                        $HashTable.Clear()
                                        break
                                    }
                                }
                            )
                            foreach ($AS in $AdditionalSettings) {
                                [PSCustomObject]@{
                                    Type              = $Policy.'@odata.type'.Split('.')[-1]
                                    scope             = $(
                                        switch -Wildcard ($SettingDefinition.baseUri) {
                                            './Device*' { 'Device'; break }
                                            './User*' { 'User'; break }
                                            default { 'Device' }
                                        }
                                    )
                                    ParentSettingName = $Policy.displayName
                                    Name              = $AS.Name
                                    Enabled           = $true
                                    Value             = $AS.Value
                                    infoUrl           = ''
                                    applicability     = [PSCustomObject]@{
                                        deviceManagementApplicabilityRuleOsEdition  = $Policy.deviceManagementApplicabilityRuleOsEdition
                                        deviceManagementApplicabilityRuleOsVersion  = $Policy.deviceManagementApplicabilityRuleOsVersion
                                        deviceManagementApplicabilityRuleDeviceMode = $Policy.deviceManagementApplicabilityRuleDeviceMode
                                    }
                                }
                            }
                            $AdditionalSettings = $null
                        }
                        break
                    }
                    { $_ -in $AdminTemplateId } {
                        # https://learn.microsoft.com/en-us/graph/api/resources/intune-grouppolicy-grouppolicycategory?view=graph-rest-beta
                        # https://learn.microsoft.com/en-us/graph/api/resources/intune-grouppolicy-grouppolicyconfiguration?view=graph-rest-beta
                        # https://learn.microsoft.com/en-us/graph/api/resources/intune-grouppolicy-grouppolicydefinition?view=graph-rest-beta
                        # https://learn.microsoft.com/en-us/graph/api/resources/intune-grouppolicy-grouppolicydefinitionfile?view=graph-rest-beta
                        # https://learn.microsoft.com/en-us/graph/api/resources/intune-grouppolicy-grouppolicydefinitionvalue?view=graph-rest-beta
                        # https://learn.microsoft.com/en-us/graph/api/resources/intune-grouppolicy-grouppolicypresentation?view=graph-rest-beta
                        # https://learn.microsoft.com/en-us/graph/api/resources/intune-grouppolicy-grouppolicyuploadeddefinitionfile?view=graph-rest-beta
                        #
                        foreach ($Setting in $ResultSettingList) {
                            $PresentationId = ($setting.'presentationValues@odata.context' -split "\('" | Select-Object -Last 1) -replace "'\).+"
                            $ADMXPresentation = $ADMXPresentationValueList["${id}_$PresentationId"].body.value
                            [String]$SettingPath = $Setting.definition.categoryPath
                            if (("$SettingPath" -eq '') -and ($Setting.definition.groupPolicyCategoryId)) {
                                [String]$SettingPath = $ADMXCategoryList["$($Setting.definition.groupPolicyCategoryId)"].body.definitions |
                                    Where-Object -Property classType -EQ $Setting.definition.classType |
                                    Select-Object -ExpandProperty categoryPath -First 1
                            }
                            if (($ADMXPresentation | Measure-Object).Count -eq 0) {
                                [PSCustomObject]@{
                                    DefinitionId      = $Setting.definition.groupPolicyCategoryId
                                    Type              = $Setting.definition.policyType
                                    SettingPath       = "$SettingPath".Trim('\')
                                    id                = $Setting.id
                                    scope             = $TextInfo.ToTitleCase("$($Setting.definition.classType -replace 'machine','Device')")
                                    ParentSettingName = ''
                                    Name              = "$($Setting.definition.displayName)".TrimEnd(':')
                                    Enabled           = $Setting.enabled
                                    Value             = $null
                                    ValueText         = ''
                                    defaultValue      = $null
                                    defaultValueText  = ''
                                    possibleValues    = $null
                                    RegistryKey       = '' # TODO
                                    RegistryName      = '' # TODO
                                    applicability     = [PSCustomObject]@{
                                        SupportedOn = $Setting.definition.supportedOn
                                    }
                                    description       = $Setting.definition.explainText
                                }
                            }
                            else {
                                foreach ($p in $ADMXPresentation) {
                                    $PossibleValues = $p.presentation.items | Select-Object -Property displayName, value
                                    <#
                                    $p.'@odata.type'
                                        #microsoft.graph.groupPolicyPresentationValueList
                                        #microsoft.graph.groupPolicyPresentationValueText
                                        #microsoft.graph.groupPolicyPresentationValueDecimal
                                        #microsoft.graph.groupPolicyPresentationValueBoolean
                                    $p.presentation.'@odata.type'
                                        '#microsoft.graph.groupPolicyPresentationTextBox
                                        '#microsoft.graph.groupPolicyPresentationDecimalTextBox
                                        '#microsoft.graph.groupPolicyPresentationCheckBox
                                        '#microsoft.graph.groupPolicyPresentationListBox
                                        '#microsoft.graph.groupPolicyPresentationDropdownList
                                    #>
                                    if ($null -ne $p.values) {
                                        # microsoft.graph.groupPolicyPresentationValueList
                                        $Value = $p.values
                                    }
                                    elseif ($null -ne $p.value) {
                                        $Value = $p.value
                                        $ValueText = ''
                                        if ($null -ne $PossibleValues) {
                                            $ValueText = ($PossibleValues | Where-Object -Property value -EQ $value | Select-Object -ExpandProperty displayName) -replace "^$Value\s*-\s*"
                                        }
                                    }
                                    [PSCustomObject]@{
                                        DefinitionId      = $Setting.definition.groupPolicyCategoryId
                                        Type              = $Setting.definition.policyType
                                        SettingPath       = "$SettingPath".Trim('\')
                                        id                = $Setting.id
                                        scope             = $TextInfo.ToTitleCase("$($Setting.definition.classType -replace 'machine','Device')")
                                        ParentSettingName = $Setting.definition.displayName
                                        Name              = "$($p.presentation.label)".TrimEnd()
                                        Enabled           = $Setting.enabled
                                        Value             = $value
                                        ValueText         = $ValueText
                                        defaultValue      = $p.presentation.defaultItem.value
                                        defaultValueText  = "$($p.presentation.defaultItem.displayName)" -replace "^$($p.presentation.defaultItem.value)\s*-\s*"
                                        possibleValues    = $PossibleValues
                                        RegistryKey       = '' # TODO
                                        RegistryName      = '' # TODO
                                        applicability     = [PSCustomObject]@{
                                            SupportedOn = $Setting.definition.supportedOn
                                        }
                                        description       = $Setting.definition.explainText
                                    }
                                }
                            }
                        }
                        break
                    }
                }
            )

            if ($Assignment.IsPresent) {
                $AssignmentList = ($BatchResult | Where-Object -Property id -Like ('*_assignments_{0}' -f $id)).body.value | ConvertFrom-IntuneAssignmentTarget -Groups $GroupList -Filters $FilterList -DeviceCount $AllDevicesCount -UserCount $AllUsersCount
            }

            ($BatchResult | Where-Object -Property id -Like ('*_Policy_{0}' -f $id)).body |
                Select-Object -Property @{
                    Label      = 'Type'
                    Expression = {
                        if ($_.'@odata.context' -match 'groupPolicyConfigurations') { 'Administrative template' }
                        else { ($_ | Get-IntunePolicyPlatformAndType -Verbose:$false).Type }
                    }
                },
                @{Label = 'createdDateTime'; Expression = { if ($null -eq $_.createdDateTime) { '0001-01-01T00:00:00.0000001Z' } else { "$($_.createdDateTime.ToString('s')).$($_.createdDateTime.ToString('fffffff').TrimEnd('0'))Z" } } },
                'creationSource',
                'description',
                @{Label = 'lastModifiedDateTime'; Expression = { if ($null -eq $_.lastModifiedDateTime) { '0001-01-01T00:00:00.0000001Z' } else { "$($_.lastModifiedDateTime.ToString('s')).$($_.lastModifiedDateTime.ToString('fffffff').TrimEnd('0'))Z" } } },
                @{
                    Label      = 'Name'
                    Expression = { [String]$($_.Name, $_.displayName | Where-Object { "$_" -ne '' }) | Select-Object -First 1 }
                },
                @{
                    Label      = 'platforms'
                    Expression = {
                        if ($null -eq $_.platforms) {
                            if ($_.'@odata.context' -match 'groupPolicyConfigurations') { 'Windows' }
                            else { ($_ | Get-IntunePolicyPlatformAndType -Verbose:$false).Platform }
                            <# if ("$($_.'@odata.type')".Split('.')[-1] -match '^(Windows|macOS|iOS|aosp|Android)') {
                                [String]($Matches[1] -replace 'aosp', 'Android')
                            } #>
                        }
                        else { "$($_.platforms)" }
                    }
                },
                @{
                    Label      = 'ScopeTags'
                    Expression = {
                        if ($null -ne $ScopeTagList) { $ScopeTagList | Where-Object -Property id -In $_.roleScopeTagIds | Select-Object -ExpandProperty displayName }
                        else { $_.roleScopeTagIds }
                    }
                },
                @{
                    Label      = 'settingCount'
                    Expression = {
                        if ($null -eq $_.settingCount) { ($SettingList | Measure-Object).Count }
                        else { $_.settingCount }
                    }
                },
                'technologies',
                'id',
                @{Label = 'settings'; Expression = { $SettingList } },
                @{
                    Label      = 'resource'
                    Expression = {
                        switch ($_.id) {
                            { $_ -in $ConfPolicyid } { 'configurationPolicies'; break }
                            { $_ -in $AdminTemplateId } { 'groupPolicyConfigurations'; break }
                            { $_ -in $CustomId } { 'deviceConfigurations'; break }
                        }
                    }
                },
                @{
                    Label      = 'targeted'
                    Expression = {
                        $TargetCount = ($AssignmentList | Where-Object -Property Action -EQ 'Include' | Where-Object -Property MemberCount -GE 0 | Measure-Object -Property MemberCount -Sum).Sum

                        if ($Assignment.IsPresent) { $TargetCount -gt 0 }
                        else { 'N/A' }
                    }
                },
                @{Label = 'assignments'; Expression = { $AssignmentList } } |
                Where-Object { Select-String -Pattern $Platform -InputObject $_.platforms -Quiet }
        }
    }
    end {
        $PSDefaultParameterValues.Clear()
    }
}


function Export-IntunePolicy {
    <#
.SYNOPSIS
    Export an Intune policy in a json file.

.DESCRIPTION
    Export an Intune policy in a json file.

.PARAMETER id
    Id of the policy.

.PARAMETER Destination
    Download folder.

.EXAMPLE
    PS C:\>

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-09-30
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [String]$id,

        [Parameter(Mandatory = $true, Position = 1)]
        [String]$Destination
    )

    begin {
        $InvocationName = $MyInvocation.InvocationName

        if (! (Test-Path -Path $Destination)) {
            $null = New-Item -Path $Destination -ItemType Directory -Force
        }

        $PropertyList = @(
            @{Label = '@odata.context'; Expression = { $_.'@odata.context'.Replace('(settings())', '') } },
            @{Label = 'createdDateTime'; Expression = { if ($null -eq $_.createdDateTime) { '0001-01-01T00:00:00.0000001Z' } else { "$($_.createdDateTime.ToString('s')).$($_.createdDateTime.ToString('fffffff').TrimEnd('0'))Z" } } },
            'creationSource',
            'description',
            @{Label = 'lastModifiedDateTime'; Expression = { if ($null -eq $_.lastModifiedDateTime) { '0001-01-01T00:00:00.0000001Z' } else { "$($_.lastModifiedDateTime.ToString('s')).$($_.createdDateTime.ToString('fffffff').TrimEnd('0'))Z" } } },
            'name',
            'platforms',
            'priorityMetaData',
            'roleScopeTagIds',
            'settingCount',
            'technologies',
            'id',
            'templateReference',
            'settings'
        )
    }
    process {
        $ExportDate = Get-Date
        try {
            $Policy = Invoke-MgGraphRequestSingle -APIVersion 'beta' -Resource ("deviceManagement/configurationPolicies('{0}')" -f $id) -Expand 'settings' -EA Ignore | Select-Object -Property $PropertyList
        }
        catch {
            $Policy = Invoke-MgGraphRequestSingle -APIVersion 'beta' -Resource ("deviceManagement/deviceConfigurations('{0}')" -f $id)
        }

        $FileName = '{0}_{1}.{2}Z.json' -f $Policy.Name, $ExportDate.ToString('s').Replace(':', '_'), $ExportDate.ToString('fff')
        Write-Verbose -Message "[$InvocationName] Exporting $($Policy.Name) ($id) to [$Destination\$FileName]"
        $Policy |
            ConvertTo-Json -Depth 15 |
            Out-File -FilePath "$Destination\$FileName" -Force -Encoding utf8
    }
    end {}
}


function Import-IntunePolicy {
    <#
.SYNOPSIS
    Import an Intune policy in a json file.

.DESCRIPTION
    Import an Intune policy in a json file.

.PARAMETER Path
    Path of the json file.

.PARAMETER Name
    New name of the policy.
    The current name will be kept, but the import will fail if the name is already used for the same type of resource.

.EXAMPLE
    PS C:\>

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-03-09
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({ ($_ -like '*.json') -and (Test-Path -LiteralPath $_) })]
        [String]$Path,

        [Parameter(Mandatory = $true, Position = 1)]
        [String]$Name
    )

    begin {
        $InvocationName = $MyInvocation.InvocationName
        $PolicyTemplates = Get-IntunePolicyTemplate
        $Template = Get-IntuneTemplate
        $ExcludePropertyList = @('@odata.context','id','SettingsCount','createdDateTime','lastModifiedDateTime','priorityMetaData','creationSource')
    }
    process {
        $json = Get-Content -LiteralPath $Path | ConvertFrom-Json

        $NameProperty = 'displayName'
        if ($json.templateReference) {
            $Resource = 'deviceManagement/configurationPolicies'
            $NameProperty = 'Name'
        }
        elseif ($json.'@odata.type') {
            if ($json.'@odata.type' -match 'compliance') {
                $Resource = 'deviceManagement/deviceCompliancePolicies'
            }
            else {
                $Resource = 'deviceManagement/deviceconfigurations'
            }
        }
        elseif ($json.policyConfigurationIngestionType) {
            $Resource = 'deviceManagement/groupPolicyConfigurations'
        }

        $HashTable = $(
            @{
                id     = "$($json.id)_ById"
                method = 'GET'
                url    = '{0}/{1}' -f $Resource, $json.id
            }
            @{
                id     = "$($json.id)_ByName"
                method = 'GET'
                url    = "{0}?`$filter={1} eq '{2}'" -f $Resource, $NameProperty, $json.$NameProperty
            }
        )

        $Existing = Invoke-MgGraphRequestBatch -APIVersion beta -Hashtable $HashTable -DoNotLogErrors | Where-Object -Property Status -EQ 200
        if ($null -eq $Existing) {
            Write-Warning -Message "[$InvocationName] The policy [$($json.id)] named [$($json.$NameProperty)] already exists: $($Existing.Body | ConvertTo-Json -Depth 10 -Compress)"
            if (("$Name" -ne '') -and ($Name -ne $json.$NameProperty)) {
                $json.$NameProperty = $Name
            }
            else {
                $json.$NameProperty = "$($json.$NameProperty)_$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            }
        }
        else {

        }
        Invoke-MgGraphRequestSingle -APIVersion 'beta' -Resource $Resource -Method 'POST' -Body ($Json | Select-Object -Property * -ExcludeProperty $ExcludePropertyList | ConvertTo-HashTable)
    }
    end {}
}


function Export-IntunePolicyToExcel {
    <#
.SYNOPSIS
    Export Intune policies and their respective settings into an Excel file.

.DESCRIPTION
    Export Intune policies and their respective settings into an Excel file (Relies on the ImportExcel PowerShell module).

    Most of the information is filled automatically but some require user input.
    That manual input is kept when the file is updated using that same function.

    The Excel file contains several worksheets and conditional formatting is used to highlight relevant information.

        - Summary worksheet (name defined by the -SummaryWorksheetName parameter)
            Policy id = Id of the policy (Linked to the detailed worksheet of policy settings)
            Policy name = Name of the policy
            Policy type = Type of the policy
            Platform = Operating system targeted by the policy
            Description = Description of the policy (Depends on the -DescriptionInfo parameter)
            Status = Policy's status (Test policy, To be removed, To be reviewed, Production, ...) (Automatic or manual input)
                     That value is replicated to the other worksheets so the settings are highlighted the same way.
            Policy scope = Identify policies that are targeted globally or on a subset of devices/users (Manual input, automatically replicated to the other worksheets)
            Setting count = Number of settings in the policy
            Scope tags = Scope tags attached to the policy
            Created on = Date of creation
            Modified on = Date of modification
            Targeted = Indicates whether the policy is targeted or not
            Included members = Number of included targets (Does not take filters into accounts)
            Include = List of included targets (filters are also shown)
            Excluded members = Number of excluded targets (Does not take filters into accounts)
            Exclude = List of excluded targets (filters are also shown)
            Comment = Comment regarding the policy to be added by an administrator for further action (Manual input)

    The following worksheets detail the settings for each policy depending on the policy type.
    Duplicated values are highlighted to spot potentiel conflicts.

        - Configuration profiles (Settings Catalog, Administrative templates, and Security Baselines policies)
            Policy name = Name of the policy where the setting is configured (Linked to the summay worksheet)
            Setting path = Path of the setting in the catalog (Category)
            Setting name = Name of the setting (The comment can contain the setting's description depending on -DescriptionInfo)
            Description = Description of the setting (Depends on the -DescriptionInfo parameter)
            Policy scope = Identify settings that are targeted globally or on a subset of devices/users (Same as specified in the summary worksheet)
            Scope = Type of target (Device or user)
            Enabled = Indicates whether the setting is enabled or not
            Value = Configured value for the setting
            Default = Default value for the setting
            Registry key = Registry key where the setting is configured
            Registry name = Registry value where the setting is configured
            Uri = Setting's uri (Linked to the setting's documentation)
            Comment = Comment regarding the setting to be added by an administrator for further action (Manual input)
            Policy status = Status of the policy (Same as specified in the summary worksheet, hidden column)

        - OMA-URI (Custom policies)
            Policy name = Name of the policy where the setting is configured (Linked to the summay worksheet)
            Setting name = Name of the setting (The comment can contain the setting's description depending on -DescriptionInfo)
            Description = Description of the setting (Depends on the -DescriptionInfo parameter)
            Policy scope = Identify settings that are targeted globally or on a subset of devices/users (Same as specified in the summary worksheet)
            Scope = Type of target (Device or user)
            Type = Indicates whether the setting is enabled or not
            Value = Configured value for the setting
            Uri = Setting's uri (Linked to the setting's documentation)
            Comment = Comment regarding the setting to be added by an administrator for further action (Manual input)
            Policy status = Status of the policy (Same as specified in the summary worksheet, hidden column)

        - Firewall (Windows Firewall Rules)
            Policy name = Name of the policy where the setting is configured (Linked to the summay worksheet)
            Policy scope = Identify settings that are targeted globally or on a subset of devices/users (Same as specified in the summary worksheet)
            Rule name
            Action (Allow, block)
            Direction (IN, OUT)
            Interfaces
            Local Address
            Local Port
            Remote Address
            Remote Port
            Network Types
            Protocol
            File Path
            Description
            Policy status

        - Templates (Any other type of policies)
            Policy name = Name of the policy where the setting is configured (Linked to the summay worksheet)
            Setting path = Path of the setting in the catalog (Category)
            Setting name = Name of the setting (The comment can contain the setting's description depending on -DescriptionInfo)
            Description = Description of the setting (Depends on the -DescriptionInfo parameter)
            Policy scope = Identify settings that are targeted globally or on a subset of devices/users (Same as specified in the summary worksheet)
            Scope = Type of target (Device or user)
            Enabled = Indicates whether the setting is enabled or not
            Value = Configured value for the setting
            Default = Default value for the setting
            Uri = Setting's uri (Linked to the setting's documentation)
            Comment = Comment regarding the setting to be added by an administrator for further action (Manual input)
            Policy status = Status of the policy (Same as specified in the summary worksheet, hidden column)



.PARAMETER Destination
    Destination folder or file.

    If a file path is specified and that file already exists, the previous status and comments are kept.
    Otherwise, if a folder path is specified, a new file will be created using the name "<Platforms>-IntunePolicies-<Date>.xlsx"

.PARAMETER Platform
    Operating system(s) for which settings are to be exported (android,iOS,Linux,macOS,Windows).
    All policies are fetched if no plaform is specified.

.PARAMETER InputObject
    (Optional) Pass the result of "Get-IntunePolicy" to the function.
    Get-IntunePolicy is used to query the settings related to the specified platforms if no object is passed to the function.
    In that case, you need to connect to the Microsoft Graph API before calling the function.

.PARAMETER MinTargetThreshold
    The number of targets below which a policy can be considered a test.
    Default is 0 (=not used).

.PARAMETER TestNamePattern
    Regex pattern used on the policy's name to determine whether the policy is a test or not.

.PARAMETER ProductionPattern
    Regex pattern used on the policy's description to determine whether the policy went through the production deployment workflow.
    Consider adopting a clear description structure for all Intune policies to make it easier to identify their status (test, production, developpement, rings, ...)

.PARAMETER DescriptionInfo
    Determine whether the description (policy and settings) is available and, if so, where it should be written.
    Possible value(s):
        None = No description is stored in the Excel file
        Comment = The description is stored in the "Policy name" or "Setting name" cell's comment
        SeparateColumn = The description is stored in a separate column
        SeparateColumnHidden = The description is stored in a separate hidden column

.PARAMETER SummaryWorksheetName
    Name of the summary worksheet.

.PARAMETER Show
    Open the Excel file.

.EXAMPLE
    PS C:\>

.EXAMPLE
    PS C:\>

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-05-19
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>



    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$Destination,

        [Parameter(Position = 1)]
        [ValidateSet('android','iOS','Linux','macOS','Windows')]
        [String[]]$Platform,

        [Parameter(Position = 2)]
        [PSCustomObject[]]$InputObject,

        [Parameter(Position = 3)]
        [uint32]$MinTargetThreshold = 0,

        [Parameter(Position = 4)]
        [String[]]$TestNamePattern,

        [Parameter(Position = 5)]
        [String[]]$ProductionPattern,

        [Parameter(Position = 6)]
        [ValidateSet('None', 'Comment', 'SeparateColumn', 'SeparateColumnHidden')]
        [String]$DescriptionInfo = 'Comment',

        [Parameter(Position = 6)]
        [String]$SummaryWorksheetName = 'Intune configuration (Summary)',

        [Switch]$Show
    )

    if ($Global:PSDefaultParameterValues.Keys.Count -gt 0) {
        $PSDefaultParameterValues = $Global:PSDefaultParameterValues.Clone()
    }
    else {
        $PSDefaultParameterValues.Clear()
    }

    #region variables
    $InvocationName = $MyInvocation.MyCommand.Name
    if (($null -eq (Get-MgContext)) -and ($null -eq $PSBoundParameters['InputObject'])) {
        throw 'Connect to the Graph API before using this function'
    }
    try {
        $null = Get-Command -Name 'Open-ExcelPackage','Import-Excel' -EA Stop
    }
    catch {
        throw 'The ImportExcel module is missing use the following command to install it: Install-Module -Name "ImportExcel" -Scope CurrentUser -Force -AllowClobber'
    }

    # Path of the Excel file
    if (Test-Path -LiteralPath $Destination -PathType Container) {
        [String]$Path = '{0}\{1}-IntunePolicies-{2}.xlsx' -f $Destination, ($Platform -join '_'), (Get-Date -Format 'yyyyMMdd_HHmm')
    }
    else {
        [String]$Path = $Destination
    }
    $PrevSummaryHash = @{}
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $PrevSummaryHash = Import-Excel -Path "$Path" -WorksheetName $SummaryWorksheetName -AsText '*' | Convert-PSObjectArrayToHashTable -idProperty 'Policy id' -Property 'Status', 'Comment', 'Policy scope' -Verbose:$false
    }

    #region Excel conditional formatting
    $SummaryColor = [System.Drawing.Color]::BlueViolet # Color of the Summary tab
    $DetailColor = [System.Drawing.Color]::Green # Color of the details tab

    # Add-ExcelTable default parameters
    $ETParams = @{
        TableStyle = 'Medium2'
        ShowHeader = $true
        ShowFilter = $true
    }

    # Add-ConditionalFormatting default parameters
    # Duplicated values
    $DuplicatedConditionFormula = '=COUNTIFS(${0}$1:${0}${1}, ${0}1, ${2}$1:${2}${1}, ${2}1)>1'
    $DuplicatedCF = @{
        RuleType        = 'DuplicateValues'
        ForegroundColor = [System.Drawing.Color]::DarkRed
        BackgroundColor = [System.Drawing.Color]::LightPink
    }
    # Policies to be reviewed
    $ToBeReviewedCF = @{
        RuleType        = 'Equal'
        ForegroundColor = [System.Drawing.Color]::Black
        BackgroundColor = [System.Drawing.Color]::Orange
        ConditionValue  = 'To be reviewed' # MODIFY THIS VALUE IF NEEDED
    }
    # Policies to be removed
    $ToBeRemovedCF = @{
        RuleType        = 'Equal'
        ForegroundColor = [System.Drawing.Color]::Black
        BackgroundColor = [System.Drawing.Color]::LightGray
        ConditionValue  = 'To be removed' # MODIFY THIS VALUE IF NEEDED
    }
    # Test policies
    $TestPolicyCF = @{
        RuleType        = 'Equal'
        ForegroundColor = [System.Drawing.Color]::Black
        BackgroundColor = [System.Drawing.Color]::Cyan
        ConditionValue  = 'Test policy' # MODIFY THIS VALUE IF NEEDED
    }
    # Test policies
    $ProdPolicyCF = @{
        RuleType        = 'Equal'
        ForegroundColor = [System.Drawing.Color]::Black
        BackgroundColor = [System.Drawing.Color]::GreenYellow
        ConditionValue  = 'Production' # MODIFY THIS VALUE IF NEEDED
    }
    # Policies that are either not targeted (no included target) or where targeted groups are empty
    $NoTargetedCF = @{
        RuleType        = 'ContainsText'
        ForegroundColor = [System.Drawing.Color]::Black
        BackgroundColor = [System.Drawing.Color]::LightGray
        ConditionValue  = 'FALSE'
    }
    # Included or excluded groups that are either removed of in the soft deletion state
    $DeletedGroupCF = @{
        RuleType        = 'ContainsText'
        ForegroundColor = [System.Drawing.Color]::Red
        ConditionValue  = '<Group deleted from Microsoft Entra ID>'
    }
    $MissingGroupCF = @{
        RuleType        = 'ContainsText'
        ForegroundColor = [System.Drawing.Color]::Red
        ConditionValue  = '<SOFT-DELETED>'
    }

    # Format the detail worksheet depending on the corresponding Status column in the Summary sheet
    # Even though referencing another sheet in a formatting condition works when entered manually in Excel, it doesn't not work programmatically
    #$StatusConditionFormula = 'XLOOKUP($A1, Summary!$B:$B, Summary!$E:$E, "") = "{0}"'
    # As a result we have to add an hidden column to each sheet with the corresponding policy status and use that column for the conditional formatting
    $StatusFormula = '=FILTER(Summary[Status],Summary[Policy name] = [@[Policy name]],"") & ""'
    $ScopeFormula = '=FILTER(Summary[Policy scope],Summary[Policy name] = [@[Policy name]],"") & ""'
    $DetailToBeRemovedCF = @{
        RuleType        = 'Expression'
        ForegroundColor = $NoTargetedCF.ForegroundColor
        BackgroundColor = $NoTargetedCF.BackgroundColor
        #ConditionValue  = "OR($($StatusConditionFormula -f $ToBeRemovedCF.ConditionValue),$($StatusConditionFormula -f $ToBeReviewedCF.ConditionValue))"
    }
    $DetailToBeReviewedCF = @{
        RuleType        = 'Expression'
        ForegroundColor = $NoTargetedCF.ForegroundColor
        BackgroundColor = $ToBeReviewedCF.BackgroundColor
        #ConditionValue  = $StatusConditionFormula -f $ToBeReviewedCF.ConditionValue
    }
    $DetailTestCF = @{
        RuleType        = 'Expression'
        ForegroundColor = $TestPolicyCF.ForegroundColor
        BackgroundColor = $TestPolicyCF.BackgroundColor
        #ConditionValue  = $StatusConditionFormula -f $TestPolicyCF.ConditionValue
    }
    $DetailProdCF = @{
        RuleType        = 'Expression'
        ForegroundColor = $ProdPolicyCF.ForegroundColor
        BackgroundColor = $ProdPolicyCF.BackgroundColor
        #ConditionValue  = $StatusConditionFormula -f $TestPolicyCF.ConditionValue
    }
    #endregion Excel conditional formatting
    #endregion variables


    #region functions
    function New-RowItem {
        param (
            [Parameter(Mandatory = $True, HelpMessage = 'Worksheet object')]
            [OfficeOpenXml.ExcelWorksheet]$Worksheet,
            [Parameter(Mandatory = $True, HelpMessage = 'Content in Cell')]
            [AllowNull()]
            $Content,
            [Parameter(Mandatory = $True)]
            [uint32]$Row,
            [Parameter(Mandatory = $True)]
            [uint32]$Column,
            [Parameter(Mandatory = $True)]
            [ValidateSet('Center', 'Right', 'Left')]
            $HorizontalAlignment,
            [Parameter()]
            [ValidateSet('Bottom','Center','Distributed','Justify','Top')]
            $VerticalAlignment = 'Top',
            [Parameter(Mandatory = $True, HelpMessage = 'Please Enter Font Size')]
            [int]$FontSize,
            [Parameter(Mandatory = $false, HelpMessage = 'Bold Font?')]
            [switch]$FontBold,
            [Parameter(Mandatory = $false, HelpMessage = 'Wrap text?')]
            [switch]$WrapText,
            [Parameter(Mandatory = $false, HelpMessage = 'Cell format')]
            [String]$NumberFormat = 'Text',
            [Parameter()]
            [AllowEmptyString()]
            [String]$Comment,
            [Parameter()]
            [AllowEmptyString()]
            [String]$Hyperlink
        )

        <#
ArrayFormula
AutoSize
BackgroundColor
BackgroundPattern
BorderAround
BorderBottom
BorderColor
BorderLeft
BorderRight
BorderTop
FontColor
FontName
FontShift
Height
Hidden
Italic
Locked
Merge
PatternColor
ResetFont
StrikeThru
TextRotation
Underline
UnderLineType
Width
    #>

        $CellId = "$((Get-ExcelColumnName -ColumnNumber $Column).ColumnName)$Row"
        $Range = $Worksheet.Cells[$CellId]
        $ValueProperty = 'Value'
        if ($Content -match '^=') {
            # If the content starts with a "=" sign, consider the content to be a formula
            $ValueProperty = 'Formula'
            $NumberFormat = 'General'
            # Replace the equal sign by _xlfn._xlws. and replace the local sheet reference [@[ColumnName]] by CurrentTableName[[#This Row],[ColumnName]]
            $Content = $Content -replace '^=','_xlfn._xlws.' -replace '\[@\[([^\]]+)\]\]',"$($Worksheet.Tables[0].Name)[[#This Row],[`$1]]"
        }
        $Params = @{
            WrapText            = $WrapText
            Range               = $Range
            Bold                = $FontBold
            HorizontalAlignment = $HorizontalAlignment
            VerticalAlignment   = $VerticalAlignment
            FontSize            = $FontSize
            NumberFormat        = $NumberFormat
            $ValueProperty      = $Content
            Verbose             = $false
        }

        if (($NumberFormat -eq 'Number') -and ($Content -eq 0)) {
            $Params.$ValueProperty = $null
        }
        elseif (($NumberFormat -eq 'Text') -and ("$Content".Trim() -eq '')) {
            $Params.Remove($ValueProperty)
        }
        Set-ExcelRange @Params

        if ("$Comment".Trim() -ne '') {
            # Add the comment and split its text every 80 characters (whole word) to enhance readability
            if ("$Comment" -notmatch 'Expand-ByteArray') {
                $Comment = Split-String -String $Comment -Width 80 -Verbose:$false
            }
            Set-CellComment -Worksheet $Worksheet -Range $Range -Text "$($Comment -join "`r`n")" -Verbose:$false
        }

        # if hyperlink is either an https link, a reference cell link (WorksheetName!Cell), or an uri
        if (("$Hyperlink".Trim() -ne '') -and (($Hyperlink -match 'https://') -or ($Hyperlink -match '^[^!]+![A-Z]+\d+$') -or ($Hyperlink -is [uri]))) {
            #Write-Verbose -Message "Adding hyperlink [$Hyperlink] to the [$Range] cell on [$($Worksheet.Name)] worksheet"
            if ($Hyperlink -match 'https://') {
                $Worksheet.Cells[$CellId].Hyperlink = $hyperlink
            }
            else {
                $hyperlinkObj = New-Object -TypeName 'OfficeOpenXml.ExcelHyperLink' -ArgumentList @($Hyperlink, "$Content")
                $hyperlinkObj.ToolTip = "See more information about [$Content]"
                $Worksheet.Cells[$CellId].Hyperlink = $hyperlinkObj
            }
            #Changing cell style from Normal to Hyperlink
            $Worksheet.Cells[$CellId].Style.Font.Color.SetColor([System.Drawing.Color]0x467886)
            $Worksheet.Cells[$CellId].Style.Font.UnderLine = $true
            #$Worksheet.Cells[$CellId].StyleName = 'Hyperlink' # Does not seem to work
            #$Worksheet.Cells[$CellId].StyleID = 1
        }
    }


    #https://gist.github.com/marcgeld/bfacfd8d70b34fdf1db0022508b02aca
    function Compress-ByteArray {
        [CmdletBinding(DefaultParameterSetName = 'FromString')]
        [OutputType([byte[]])]
        param (
            [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'FromBytes')]
            [byte[]]$byteArray,

            [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'FromString')]
            [ValidateNotNullOrEmpty()]
            [String]$String,

            [Parameter(Position = 1, ParameterSetName = 'FromString')]
            [System.Text.Encoding]$Encoding = [System.Text.Encoding]::UTF8
        )
        process {
            if ($PSCmdlet.ParameterSetName -eq 'FromString') {
                [byte[]]$byteArray = $Encoding.GetBytes($String)
            }

            [System.IO.MemoryStream] $outputStream = New-Object System.IO.MemoryStream
            $gzipStream = New-Object -TypeName 'System.IO.Compression.GzipStream' -ArgumentList ($outputStream, ([IO.Compression.CompressionMode]::Compress))
            $gzipStream.Write( $byteArray, 0, $byteArray.Length )
            $gzipStream.Close()
            $outputStream.Close()
            [byte[]]($outputStream.ToArray()) # Return the byte array
            # Help memory cleanup
            $gzipStream.Dispose()
            $outputStream.Dispose()
        }
    }


    function Expand-ByteArray {
        [CmdletBinding()]
        [OutputType([String])]
        param (
            [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
            [byte[]]$byteArray,

            [Switch]$ToString,

            [System.Text.Encoding]$Encoding = [System.Text.Encoding]::UTF8
        )
        process {
            $inputStream = [System.IO.MemoryStream]::new(($byteArray))
            $outputStream = New-Object -TypeName 'System.IO.MemoryStream'
            $gzipStream = [System.IO.Compression.GzipStream]::new($inputStream, ([IO.Compression.CompressionMode]::Decompress))
            $gzipStream.CopyTo( $outputStream )
            $gzipStream.Close()
            $inputStream.Close()
            if ($ToString.IsPresent) {
                $Encoding.GetString(([byte[]]($outputStream.ToArray())))
            }
            else {
                [byte[]]($outputStream.ToArray()) # Return the byte array
            }
            # Help memory cleanup
            $gzipStream.Dispose()
            $outputStream.Dispose()
            $inputStream.Dispose()
        }
    }
    # Comment that will be used when the value size exceeds the Excel's cell limitation
    $CompressedStringValueComment = @"
#Extract the value by using the following function and command:

function Expand-ByteArray {${function:Expand-ByteArray}}

# Copy the cell value (CTRL+C) and type
Expand-ByteArray -ByteArray ([byte[]]((Get-Clipboard).Split('] ')[-1].Split(','))) -ToString
"@


    function Split-String {
        [CmdletBinding()]
        [OutputType('String')]
        param (
            [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
            [AllowEmptyString()]
            [String]$String,

            [Parameter(Mandatory = $true, Position = 1)]
            [uint16]$Width
        )

        process {
            $output = [Text.StringBuilder]::new()

            foreach ($Line in ($String.Split("`r`n").Split("`n"))) {
                $column = 0
                foreach ($word in ($Line -split '\s')) {
                    Write-Verbose "[$column + $($word.Length + 1)] {$word}"
                    $column += $word.Length + 1
                    if ($column -gt $Width) {
                        [void]$output.Append("`r`n$word ")
                        $column = $word.Length + 1
                    }
                    else {
                        [void]$output.Append("$word ")
                    }
                }
                [void]$output.Append("`r`n")
            }
            $output.ToString()
        }
    }


    <# function Add-ConditionalFormattingFormula {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [OfficeOpenXml.ExcelWorksheet]$Worksheet,

        [Parameter(Mandatory = $true, Position = 1)]
        [String]$Address,

        [Parameter(Mandatory = $true, Position = 2)]
        [System.Drawing.Color]$ForegroundColor,

        [Parameter(Mandatory = $true, Position = 3)]
        [System.Drawing.Color]$BackgroundColor,

        [Parameter(Mandatory = $true, Position = 4)]
        [Alias('ConditionValue')]
        [String]$Formula
    )

    [OfficeOpenXml.ConditionalFormatting.ExcelConditionalFormattingExpression]$cf = $Worksheet.ConditionalFormatting.AddExpression($Address)
    $cf.formula = $Formula
    $cf.Style.Fill.BackgroundColor = $BackgroundColor
    $cf.Style.Font.Color = $ForegroundColor
} #>
    #endregion functions


    #region main
    $ErrorActionPreference = 'Stop'

    if ($null -eq $PSBoundParameters['InputObject']) {
        # Query Intune's policies for the specified platform(s) only if list is not passed as a parameter
        $PolicyList = Get-IntunePolicy -Assignment -Platform $Platform | Sort-Object -Property Type,platform,Name
    }
    else {
        $PolicyList = $InputObject
    }

    if (Test-Path -LiteralPath $Path) {
        Write-Log -Message "[$InvocationName] Using the existing file [$Path]"
    }
    else {
        Write-Log -Message "[$InvocationName] Creating the file [$Path]"
    }
    $Excel = Open-ExcelPackage -Path $Path -Create -Verbose:$false

    $Worksheet = $Excel.Workbook.Worksheets | Where-Object -Property Name -EQ $SummaryWorksheetName
    [uint16]$WIndex = 1
    if ($null -ne $Worksheet) {
        [uint16]$WIndex = $Worksheet.Index
        Write-Log -Message "[$InvocationName] Removing existing worksheet named [$($Worksheet.Name)] at index $WIndex"
        $Excel.Workbook.Worksheets.Delete($Worksheet.Index)
    }
    $Worksheet = Add-Worksheet -ExcelPackage $Excel -WorksheetName $SummaryWorksheetName
    $Worksheet.TabColor = $SummaryColor
    if ($WIndex -gt 1) {
        $Excel.Workbook.Worksheets.MoveAfter($Worksheet.Index, ($WIndex - 1))
    }

    #region Summary
    # Holds the cell linked to every policy in the summary sheet so it can be used as a link in the other sheets
    $SummaryHash = @{}
    # Holds the cell linked to every policy in the detailed worksheets so it can be used as a link in the summary sheet (Handled at the end of the function)
    $DetailHash = @{}
    $SumRow = 1
    $SumColumn = 1
    #Define the columns
    $ColumnHeader = New-Object -TypeName System.Collections.Generic.List[Object] -ArgumentList (,@(
            @{Name = 'Policy id'; Width = 36 },
            @{Name = 'Policy name'; Width = 60 },
            @{Name = 'Policy type'; Width = 40 },
            @{Name = 'Platform'; Width = 13 },
            $(if ($DescriptionInfo -match 'Column') { @{Name = 'Description'; Width = 60 } } else { @{} }), # Add the column if needed
            @{Name = 'Status'; Width = 13 },
            @{Name = 'Policy scope'; Width = 10 },
            @{Name = 'Setting count'; Width = 17 },
            @{Name = 'Scope tags'; Width = 20 },
            @{Name = 'Created on'; Width = 17 },
            @{Name = 'Modified on'; Width = 17 },
            @{Name = 'Targeted'; Width = 13 },
            @{Name = 'Included members'; Width = 20 },
            @{Name = 'Include'; Width = 55 },
            @{Name = 'Excluded members'; Width = 20 },
            @{Name = 'Exclude'; Width = 55 },
            @{Name = 'Comment'; Width = 50 }
        ))

    foreach ($Header in $ColumnHeader) {
        if ($null -eq $Header.Name) { continue }
        New-RowItem -Worksheet $Worksheet -row $SumRow -Column $SumColumn -FontSize 14 -HorizontalAlignment 'Left' -Content $Header.Name
        $Worksheet.Column($SumColumn).width = $Header.Width
        $SumColumn++
    }
    #https://epplussoftware.com/docs/5.1/api/OfficeOpenXml.ExcelWorksheetView.html#OfficeOpenXml_ExcelWorksheetView_FreezePanes_System_Int32_System_Int32_
    $Worksheet.View.FreezePanes(2, 3)

    Write-Log -Message "[$InvocationName] Create the [$SummaryWorksheetName] worksheet with $(($PolicyList | Measure-Object).Count) policies"
    foreach ($Policy in $PolicyList) {
        $ASIncludedList = $Policy.assignments | Where-Object -Property Action -EQ 'Include'
        $ASExcludedList = $Policy.assignments | Where-Object -Property Action -EQ 'Exclude'
        [String[]]$AsInclude = $ASIncludedList | ForEach-Object { "$($_.Target) (Filter: [$($_.FilterType)] $($_.Filter))".Replace(' (Filter: [none] )','') }
        [uint32]$AsIncludedCount = $ASIncludedList | Where-Object -Property MemberCount -GE 0 | Measure-Object -Property MemberCount -Sum | Select-Object -ExpandProperty Sum
        [String[]]$AsExclude = $ASExcludedList | ForEach-Object { "$($_.Target) (Filter: [$($_.FilterType)] $($_.Filter))".Replace(' (Filter: [none] )','') }
        [uint32]$AsExcludedCount = $ASExcludedList | Where-Object -Property MemberCount -GE 0 | Measure-Object -Property MemberCount -Sum | Select-Object -ExpandProperty Sum
        $SumRow++
        $SumColumn = 1
        $SummaryHash["$($Policy.Name)"] = "'$SummaryWorksheetName'!B$SumRow" # Add the cell reference to be used as a link in the detail worksheets
        [String]$Status = $(
            if ((($Policy.Targeted -eq $false) -and ($AsInclude.Count -eq 0)) -or ($Policy.settingCount -eq 0)) {
                # Policy is not targeted or does not have any setting so it should be removed
                $ToBeRemovedCF.ConditionValue
            }
            elseif ($AsIncludedCount -eq 0) {
                # The target count is 0 so the policy should be reviewed
                $ToBeReviewedCF.ConditionValue
            }
            elseif ((($TestNamePattern.Count -gt 0) -and ("$($Policy.Name)".Replace('_',' ') | Select-String -Pattern $TestNamePattern -Quiet)) -or ($AsIncludedCount -lt $MinTargetThreshold)) {
                # The policy name matches one of the pattern defined in the parameters OR if the targeted count is lower than the threshold defined in the parameters
                $TestPolicyCF.ConditionValue
            }
            elseif (($ProductionPattern.Count -gt 0) -and ($Policy.Description | Select-String -Pattern $ProductionPattern -Quiet)) { $ProdPolicyCF.ConditionValue }
            else { '' }
        )

        # Retrieve the previous values for Status, Comment, and Policy scope
        [String]$PrevStatus = $PrevSummaryHash["$($Policy.Id)"].Status
        <#
        The previous status is used only if:
            The previous status is different from the current one and is not empty
            Current status = "To be reviewed" and previous status = "To be removed"
            Current status = "Test policy" and previous status = "Production"
    #>
        if (
            ("$PrevStatus" -ne '') `
                -and ($PrevStatus -ne $Status) `
                -and (($Status -eq '') `
                    -or (($Status -eq $ToBeReviewedCF.ConditionValue) -and ($PrevStatus -eq $ToBeRemovedCF.ConditionValue)) `
                    -or (($Status -eq $TestPolicyCF.ConditionValue) -and ($PrevStatus -eq $ProdPolicyCF.ConditionValue))
            )
        ) {
            $Status = "$PrevStatus"
        }
        [String]$PrevComment = $PrevSummaryHash["$($Policy.Id)"].Comment
        [String]$PrevScope = $PrevSummaryHash["$($Policy.Id)"].'Policy scope'

        # Define the columns
        $ColumnList = New-Object -TypeName System.Collections.Generic.List[Object] -ArgumentList @(,(
                @{Content = "$($Policy.id)"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                @{Content = "$($Policy.Name)"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false; Comment = "$(if ($DescriptionInfo -eq 'Comment') {$Policy.description})" }, # Add the description as a comment if needed
                @{Content = "$($Policy.Type)"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                @{Content = "$($Policy.Platforms)" -join ','; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                $(if ($DescriptionInfo -match 'Column') { @{Content = $Policy.description; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $true } } else { @{} }), # Add the column if needed
                @{Content = "$Status"; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $false },
                @{Content = "$PrevScope"; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $true },
                @{Content = [uint16]$Policy.settingCount; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $false },
                @{Content = $Policy.ScopeTags -join "`r`n"; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $true },
                @{Content = ([datetime]$Policy.createdDateTime); HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false; NumberFormat = 'yyyy-MM-dd HH:mm:ss' },
                @{Content = ([datetime]$Policy.lastModifiedDateTime); HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false; NumberFormat = 'yyyy-MM-dd HH:mm:ss' },
                @{Content = $Policy.Targeted; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $false },
                @{Content = $AsIncludedCount; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $false },
                @{Content = $AsInclude -join "`r`n"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $true },
                @{Content = $AsExcludedCount; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $false },
                @{Content = $AsExclude -join "`r`n"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $true },
                @{Content = "$PrevComment"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false }
            ))
        foreach ($ColumnItem in $ColumnList) {
            if ($null -eq $ColumnItem.HorizontalAlignment) { continue }
            New-RowItem -Worksheet $Worksheet -row $SumRow -Column $SumColumn @ColumnItem
            $SumColumn++
        }
    }
    $PrevSummaryHash.Clear()
    $ColumnList.Clear()
    $Range = $Worksheet.Cells["A1:$((Get-ExcelColumnName -ColumnNumber ($SumColumn - 1)).ColumnName)$SumRow"]
    Add-ExcelTable -Range $Range -TableName 'Summary' @ETParams
    # Auto fit the columns and correct the width of those that should be a fixed size
    $Index = 1
    foreach ($Column in $ColumnHeader) {
        if ($null -eq $Column.Name) { continue }
        $Worksheet.Column($Index).AutoFit($Column.Width)
        if (($Column.Name -eq 'Description') -and ($DescriptionInfo -eq 'SeparateColumnHidden')) {
            $Worksheet.Column($Index).Hidden = $true # Hide the "Description" column
        }
        $Index++
    }
    $ColumnHeader.Clear()
    if ($Platform.Count -eq 1) {
        # Hide the Platforms columns if a single platform is specfied in the parameter
        $Worksheet.Column(4).Hidden = $true
    }
    if ($DescriptionInfo -match 'Column') {
        # All columns after D (Description) are shifted to the right
        # Conditional formatting for column F (Status)
        Add-ConditionalFormatting -Address 'F:F' -Worksheet $Worksheet @ToBeReviewedCF
        Add-ConditionalFormatting -Address 'F:F' -Worksheet $Worksheet @ToBeRemovedCF
        Add-ConditionalFormatting -Address 'F:F' -Worksheet $Worksheet @TestPolicyCF
        Add-ConditionalFormatting -Address 'F:F' -Worksheet $Worksheet @ProdPolicyCF
        # Conditional formatting for column L (Targeted)
        Add-ConditionalFormatting -Address 'L:L' -Worksheet $Worksheet @NoTargetedCF
        # Conditional formatting for column N and P (Included/Excluded)
        Add-ConditionalFormatting -Address 'N:N' -Worksheet $Worksheet @DeletedGroupCF
        Add-ConditionalFormatting -Address 'N:N' -Worksheet $Worksheet @MissingGroupCF
        Add-ConditionalFormatting -Address 'P:P' -Worksheet $Worksheet @DeletedGroupCF
        Add-ConditionalFormatting -Address 'P:P' -Worksheet $Worksheet @MissingGroupCF
    }
    else {
        # Conditional formatting for column E (Status)
        Add-ConditionalFormatting -Address 'E:E' -Worksheet $Worksheet @ToBeReviewedCF
        Add-ConditionalFormatting -Address 'E:E' -Worksheet $Worksheet @ToBeRemovedCF
        Add-ConditionalFormatting -Address 'E:E' -Worksheet $Worksheet @TestPolicyCF
        Add-ConditionalFormatting -Address 'E:E' -Worksheet $Worksheet @ProdPolicyCF
        # Conditional formatting for column K (Targeted)
        Add-ConditionalFormatting -Address 'K:K' -Worksheet $Worksheet @NoTargetedCF
        # Conditional formatting for column M and O (Included/Excluded)
        Add-ConditionalFormatting -Address 'M:M' -Worksheet $Worksheet @DeletedGroupCF
        Add-ConditionalFormatting -Address 'M:M' -Worksheet $Worksheet @MissingGroupCF
        Add-ConditionalFormatting -Address 'O:O' -Worksheet $Worksheet @DeletedGroupCF
        Add-ConditionalFormatting -Address 'O:O' -Worksheet $Worksheet @MissingGroupCF
    }
    #endregion Summary

    #region Details
    # Group the policies by type, the group name is used as worksheet name
    Write-Log -Message "[$InvocationName] Grouping policies by type"
    $PolicyGroupList = $PolicyList | Group-Object -Property @{
        Expression = {
            switch -regex ($_.Type) {
                'Custom' { 'OMA-URI'; break }
                '^(Settings Catalog|Administrative template|Security Baseline)' { 'Configuration profiles'; break }
                'Windows Firewall Rules' { 'Firewall';break }
                #Default { 'Configuration profiles';break }
                Default { 'Templates';break }
            }
        }
    } |
        Sort-Object -Property { $_.Name.Length } -Descending
    $Worksheet = $PolicyList = $null
    $null = [System.GC]::GetTotalMemory($true)

    foreach ($PolicyGroup in $PolicyGroupList) {
        Write-Log -Message "[$InvocationName] ==========Processing $($PolicyGroup.Count) [$($PolicyGroup.Name)] policie(s)=========="
        $WorksheetName = $PolicyGroup.Name
        $Worksheet = $Excel.Workbook.Worksheets | Where-Object -Property Name -EQ $WorksheetName
        if ($null -ne $Worksheet) {
            $PrevCommentHash = Import-Excel -Path "$Path" -WorksheetName $WorksheetName -AsText '*' | Select-Object -Property 'Policy name', 'Comment' | Convert-PSObjectArrayToHashTable -idProperty 'Policy name' -Verbose:$false
            Write-Log -Message "[$InvocationName] Removing existing worksheet named [$($Worksheet.Name)]"
            $Excel.Workbook.Worksheets.Delete($Worksheet.Index)
        }
        else {
            $PrevCommentHash = @{}
        }
        $Worksheet = Add-Worksheet -ExcelPackage $Excel -WorksheetName $WorksheetName
        $Worksheet.TabColor = $DetailColor
        $Excel.Workbook.Worksheets.MoveAfter($Worksheet.Index, $WIndex)
        [uint16]$WIndex = $Worksheet.Index
        $DetailRow = 1
        $DetailColumn = 1

        $ETParams.TableName = ($WorksheetName -replace '\s+' -replace '\W+','_').Trim('_')

        switch ($WorksheetName) {
            #region Configuration profiles/Templates
            { $_ -in ('Configuration profiles', 'Templates') } {
                # Define the columns
                $ColumnHeader = New-Object -TypeName System.Collections.Generic.List[Object] -ArgumentList (,@(
                        @{Name = 'Policy name'; Width = 65 },
                        @{Name = 'Setting path'; Width = 65 },
                        @{Name = 'Setting name'; Width = 70 },
                        $(if ($DescriptionInfo -match 'Column') { @{Name = 'Description'; Width = 60 } } else { @{} }),
                        @{Name = 'Policy scope'; Width = 20 },
                        @{Name = 'Scope'; Width = 9 },
                        @{Name = 'Enabled'; Width = 9 },
                        @{Name = 'Value'; Width = if ($WorksheetName -eq 'Configuration profiles') { 15 } else { 50 } },
                        @{Name = 'Default'; Width = if ($WorksheetName -eq 'Configuration profiles') { 15 } else { 50 } },
                        @{Name = 'Registry key'; Width = 50 },
                        @{Name = 'Registry name'; Width = 50 },
                        @{Name = 'Uri'; Width = 70 },
                        @{Name = 'Comment'; Width = 50 },
                        @{Name = 'Policy status'; Width = 20 }
                    ))

                foreach ($Header in $ColumnHeader) {
                    if ($null -eq $Header.Name) { continue }
                    New-RowItem -Worksheet $Worksheet -row $DetailRow -Column $DetailColumn -FontSize 14 -HorizontalAlignment 'Left' -Content $Header.Name
                    $Worksheet.Column($DetailColumn).width = $Header.Width
                    $DetailColumn++
                }
                $Worksheet.View.FreezePanes(2, 3)

                $DetailColumn = 1
                foreach ($Policy in ($PolicyGroup.Group | Sort-Object -Property Name)) {
                    $DetailHash["$($Policy.id)"] = "'$WorksheetName'!A$($DetailRow + 1)"
                    Write-Log -Message "  [$($Policy.Name)]"
                    foreach ($Setting in $Policy.Settings) {
                        $DetailRow++
                        $DetailColumn = 1
                        [String]$SettingName = "$($Setting.Name)".Trim('\')
                        if ($WorksheetName -eq 'Configuration profiles') {
                            [String]$SettingName = "$($Setting.ParentSettingName)\$($Setting.Name)".Trim('\').Replace("$($Setting.Name)\",'')
                        }
                        if (("$($setting.value)".Trim() -eq '') -and ($Setting.value -isnot [string])) {
                            # The value is an object or is null if the setting state is just Enabled/Disabled
                            [String]$ValueStr = ($setting.value | ConvertTo-Json) -replace '^null$'
                        }
                        elseif ($setting.value -is [array]) {
                            [String]$ValueStr = $setting.value -join "`r`n"
                        }
                        else {
                            [String]$ValueStr = "$($Setting.ValueText) ($($Setting.Value))".Replace(' ()','') -replace '^\s+\(([^\(]+)\)$','$1'
                        }
                        # 32767 is the Excel cell size limit (https://support.microsoft.com/en-us/office/excel-specifications-and-limits-1672b34d-7043-467e-8e27-269d656771c3)
                        $ValueComment = ''
                        if ($ValueStr.Length -gt 32767) {
                            $ValueStr = "$ValueStr".TrimEnd(')') -replace '^\s\(' # Replace the empty "$Setting.valueText ("
                            [String]$ValueStr = "[LongStringCompressed] $((Compress-ByteArray -String $ValueStr)) -join ',')"
                            $ValueComment = $CompressedStringValueComment # Add instructions in the comment to extract the compressed string
                            if ($ValueStr.Length -gt 32767) {
                                [String]$ValueStr = '[Skipped long string to avoid Excel error]'
                            }
                        }
                        $DefaultValueStr = "$($Setting.defaultValueText) ($($Setting.defaultValue))".Replace(' ()','') -replace '^\s+\(([^\(]+)\)$','$1'
                        [String]$SettingPath = $Setting.SettingPath
                        if ("$SettingPath".Trim() -eq '') {
                            [String]$SettingPath = $Policy.Type
                        }
                        $ColumnList = New-Object -TypeName System.Collections.Generic.List[Object] -ArgumentList @(,(
                                @{Content = "$($Policy.Name)"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false; HyperLink = $SummaryHash["$($Policy.Name)"] },
                                @{Content = "$SettingPath"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                                @{Content = "$($Setting.ParentSettingName)\$($Setting.Name)".Trim('\').Replace("$($Setting.Name)\",''); HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false; Comment = "$(if ($DescriptionInfo -eq 'Comment') {$Setting.description})" },
                                $(if ($DescriptionInfo -match 'Column') { @{Content = $Setting.description; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $true } } else { @{} }), # Add the column if needed
                                @{Content = $ScopeFormula; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $true },
                                @{Content = "$($Setting.scope)"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                                @{Content = $Setting.Enabled; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                                @{Content = $ValueStr; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $true; Comment = "$ValueComment" },
                                @{Content = $DefaultValueStr; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $true },
                                @{Content = "$($Setting.RegistryKey)"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                                @{Content = "$($Setting.RegistryName)"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                                @{Content = "$($Setting.settingUri)"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false; Hyperlink = "$($Setting.infoUrl)" },
                                @{Content = "$($PrevCommentHash["$($Policy.Name)"])"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $true },
                                @{Content = $StatusFormula; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false }
                            ))
                        foreach ($ColumnItem in $ColumnList) {
                            if ($null -eq $ColumnItem.HorizontalAlignment) { continue }
                            New-RowItem -Worksheet $Worksheet -row $DetailRow -Column $DetailColumn @ColumnItem
                            $DetailColumn++
                        }
                    }
                }
                # Extra parameters for duplicated conditional formatting
                if ($WorksheetName -eq 'Configuration profiles') {
                    # Use the "Setting path" (B) and "Setting name" (C) columns to highlight the duplicates
                    $ExtraDupCF = @{
                        Address         = 'B:C'
                        RuleType        = 'Expression'
                        ForegroundColor = $DuplicatedCF.ForegroundColor
                        BackgroundColor = $DuplicatedCF.BackgroundColor
                        ConditionValue  = $DuplicatedConditionFormula -f 'B', $DetailRow, 'C'
                    }
                }
                else {
                    # Use the "Uri" column to highlight the duplicates
                    $ExtraDupCF = @{ Address = 'K:K' }
                    if ($DescriptionInfo -match 'Column') {
                        $ExtraDupCF = @{ Address = 'L:L' }
                    }
                }
                break
            }
            #endregion Configuration profiles/Templates
            #region OMA-URI
            'OMA-URI' {
                # Define the columns
                $ColumnHeader = New-Object -TypeName System.Collections.Generic.List[Object] -ArgumentList (,@(
                        @{Name = 'Policy name'; Width = 65 },
                        @{Name = 'Setting name'; Width = 60 },
                        $(if ($DescriptionInfo -match 'Column') { @{Name = 'Description'; Width = 60 } } else { @{} }),
                        @{Name = 'Policy scope'; Width = 20 },
                        @{Name = 'Scope'; Width = 10 },
                        @{Name = 'Type'; Width = 9 },
                        @{Name = 'Value'; Width = 70 },
                        @{Name = 'Uri'; Width = 100 },
                        @{Name = 'Comment'; Width = 70 },
                        @{Name = 'Policy status'; Width = 20 }
                    ))

                foreach ($Header in $ColumnHeader) {
                    if ($null -eq $Header.Name) { continue }
                    New-RowItem -Worksheet $Worksheet -row $DetailRow -Column $DetailColumn -FontSize 14 -HorizontalAlignment 'Left' -Content $Header.Name
                    $Worksheet.Column($DetailColumn).width = $Header.Width
                    $DetailColumn++
                }
                $Worksheet.View.FreezePanes(2, 3)

                $DetailColumn = 1
                foreach ($Policy in ($PolicyGroup.Group | Sort-Object -Property Name)) {
                    Write-Log -Message "  [$($Policy.Name)]"
                    $DetailHash["$($Policy.id)"] = "'$WorksheetName'!A$($DetailRow + 1)"
                    foreach ($Setting in $Policy.Settings) {
                        $DetailRow++
                        $DetailColumn = 1
                        [String]$ValueStr = $Setting.Value
                        # 32767 is the Excel cell size limit (https://support.microsoft.com/en-us/office/excel-specifications-and-limits-1672b34d-7043-467e-8e27-269d656771c3)
                        $ValueComment = ''
                        if ($ValueStr.Length -gt 32767) {
                            [String]$ValueStr = "[LongStringCompressed] $((Compress-ByteArray -String $ValueStr) -join ',')"
                            $ValueComment = $CompressedStringValueComment # Add instructions in the comment to extract the compressed string
                            if ($ValueStr.Length -gt 32767) {
                                [String]$ValueStr = '[Skipped long string to avoid Excel error]'
                            }
                        }
                        $ColumnList = New-Object -TypeName System.Collections.Generic.List[Object] -ArgumentList @(,(
                                @{Content = "$($Policy.Name)"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false; HyperLink = $SummaryHash["$($Policy.Name)"] },
                                @{Content = "$($Setting.Name)"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                                $(if ($DescriptionInfo -match 'Column') { @{Content = $Setting.description; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $true } } else { @{} }), # Add the column if needed
                                @{Content = $ScopeFormula; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $true },
                                @{Content = "$($Setting.scope)"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                                @{Content = "$($Setting.Type)" -replace 'omaSetting'; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                                @{Content = $ValueStr; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $true; Comment = "$ValueComment" },
                                @{Content = "$($Setting.settingUri)"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false; HyperLink = "$($Setting.infoUrl)" },
                                @{Content = "$($PrevCommentHash["$($Policy.Name)"])"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $true },
                                @{Content = $StatusFormula; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false }
                            ))
                        foreach ($ColumnItem in $ColumnList) {
                            if ($null -eq $ColumnItem.HorizontalAlignment) { continue }
                            New-RowItem -Worksheet $Worksheet -row $DetailRow -Column $DetailColumn @ColumnItem
                            $DetailColumn++
                        }
                    }
                }

                # Extra parameters for duplicated conditional formatting
                $CIndex = 'G'
                if ($DescriptionInfo -match 'Column') {
                    $CIndex = 'H'
                }
                $ExtraDupCF = @{
                    Address         = '{0}:{0}' -f $CIndex
                    RuleType        = 'Expression'
                    ForegroundColor = $DuplicatedCF.ForegroundColor
                    BackgroundColor = $DuplicatedCF.BackgroundColor
                    ConditionValue  = $DuplicatedConditionFormula -f 'B', $DetailRow, $CIndex
                }
                break
            }
            #endregion OMA-URI
            #region Firewall rules
            'Firewall' {
                # Define the columns
                $ColumnHeader = New-Object -TypeName System.Collections.ArrayList -ArgumentList (,@(
                        @{Name = 'Policy name'; Width = 65 },
                        @{Name = 'Policy scope'; Width = 20 },
                        @{Name = 'Rule name'; Width = 40 },
                        @{Name = 'Action'; Width = 10 },
                        @{Name = 'Direction'; Width = 13 },
                        @{Name = 'Interfaces'; Width = 15 },
                        @{Name = 'Local Address'; Width = 25 },
                        @{Name = 'Local Port'; Width = 18 },
                        @{Name = 'Remote Address'; Width = 25 },
                        @{Name = 'Remote Port'; Width = 18 },
                        @{Name = 'Network Types'; Width = 20 },
                        @{Name = 'Protocol'; Width = 12 },
                        @{Name = 'File Path'; Width = 50 },
                        @{Name = 'Description'; Width = 50 },
                        @{Name = 'Policy status'; Width = 20 }
                    ))

                foreach ($Header in $ColumnHeader) {
                    New-RowItem -Worksheet $Worksheet -row $DetailRow -Column $DetailColumn -FontSize 14 -HorizontalAlignment 'Left' -Content $Header.Name
                    $Worksheet.Column($DetailColumn).width = $Header.Width
                    $DetailColumn++
                }
                $Worksheet.View.FreezePanes(2, 3)

                $DetailColumn = 1
                foreach ($Policy in ($PolicyGroup.Group | Sort-Object -Property Name)) {
                    Write-Log -Message "  [$($Policy.Name)]"
                    $DetailHash["$($Policy.id)"] = "'$WorksheetName'!A$($DetailRow + 1)"
                    foreach ($SettingGroup in ($Policy.Settings | Group-Object -Property ParentSettingName | Sort-Object -Property Name)) {
                        $DetailRow++
                        $DetailColumn = 1
                        $SettingHash = $SettingGroup.Group | Convert-PSObjectArrayToHashTable -idProperty Name -Property Value, ValueText -Verbose:$false
                        $NetworkTypes = ($SettingHash.'Network Types'.ValueText -split ':' | Where-Object { $_ -match 'FW_?PROFILE_?TYPE' }) -replace '.*FW_?PROFILE_?TYPE_?([^:]+).*','$1'
                        $ColumnList = New-Object -TypeName System.Collections.ArrayList -ArgumentList @(,(
                                @{Content = $Policy.Name; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false; HyperLink = $SummaryHash["$($Policy.Name)"] },
                                @{Content = $ScopeFormula; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $true },
                                @{Content = $SettingGroup.Name; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                                @{Content = $SettingHash.Action.ValueText; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $false },
                                @{Content = $SettingHash.Direction.Value; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $false },
                                @{Content = $SettingHash.'Interface Types'.Value; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                                @{Content = $SettingHash.'Local Address Ranges'.Value -join "`r`n"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $true },
                                @{Content = $SettingHash.'Local Port Ranges'.Value -join "`r`n"; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $true },
                                @{Content = $SettingHash.'Remote Address Ranges'.Value -join "`r`n"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $true },
                                @{Content = $SettingHash.'Remote Port Ranges'.Value -join "`r`n"; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $true },
                                @{Content = $NetworkTypes -join "`r`n"; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $true },
                                @{Content = $SettingHash.Protocol.Value; HorizontalAlignment = 'Center'; FontSize = 10; WrapText = $false },
                                @{Content = $SettingHash.'File Path'.Value; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                                @{Content = $SettingHash.Description.Value; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false },
                                @{Content = $StatusFormula; HorizontalAlignment = 'Left'; FontSize = 10; WrapText = $false }
                            ))
                        foreach ($ColumnItem in $ColumnList) {
                            New-RowItem -Worksheet $Worksheet -row $DetailRow -Column $DetailColumn @ColumnItem
                            $DetailColumn++
                        }
                        $SettingHash = $null
                    }
                }
                $ExtraDupCF = @{ Address = 'C:C' } # Extra parameters for duplicated conditional formatting
                break
            }
            #endregion Firewall rules
        }
        Remove-Variable -Name 'DefaultValueStr','ValueStr','ValueComment' -Force -EA Ignore

        $ColumnList.Clear()
        $ColumnList = $null
        $ColumnName = (Get-ExcelColumnName -ColumnNumber ($DetailColumn - 1)).ColumnName
        $Range = $Worksheet.Cells["A1:$($ColumnName)$DetailRow"]
        Add-ExcelTable -Range $Range @ETParams
        # Conditional formatting for duplicated settings
        if ("$($ExtraDupCF.Keys)" -eq 'Address') {
            Add-ConditionalFormatting -Worksheet $Worksheet @DuplicatedCF @ExtraDupCF
        }
        else {
            Add-ConditionalFormatting -Worksheet $Worksheet @ExtraDupCF # Custom duplicated formula
        }
        # Conditional formatting to reflect the policies' status on the settings rows
        Add-ConditionalFormatting -Address ('A:{0}' -f $ColumnName) -Worksheet $Worksheet @DetailToBeRemovedCF -ConditionValue ('${0}1 = "{1}"' -f $ColumnName, $ToBeRemovedCF.ConditionValue)
        Add-ConditionalFormatting -Address ('A:{0}' -f $ColumnName) -Worksheet $Worksheet @DetailToBeReviewedCF -ConditionValue ('${0}1 = "{1}"' -f $ColumnName, $ToBeReviewedCF.ConditionValue)
        Add-ConditionalFormatting -Address ('A:{0}' -f $ColumnName) -Worksheet $Worksheet @DetailTestCF -ConditionValue ('${0}1 = "{1}"' -f $ColumnName, $TestPolicyCF.ConditionValue)
        Add-ConditionalFormatting -Address ('A:{0}' -f $ColumnName) -Worksheet $Worksheet @DetailProdCF -ConditionValue ('${0}1 = "{1}"' -f $ColumnName, $ProdPolicyCF.ConditionValue)
        # Auto fit the columns with a minimum size
        $Index = 1
        foreach ($Column in $ColumnHeader) {
            if ($null -eq $Column.Name) { continue }
            $Worksheet.Column($Index).AutoFit($Column.Width)
            if ((($Column.Name -eq 'Description') -and ($DescriptionInfo -eq 'SeparateColumnHidden')) -or (($Column.Name -match 'registry') -and ($WorksheetName -eq 'Templates'))) {
                $Worksheet.Column($Index).Hidden = $true # Hide the "Description" column or the "Registry key" and "Registry name" for templates
            }
            $Index++
        }
        #$Worksheet.Column(($DetailColumn - 1)).Hidden = $true # Hide the last "Policy status" column (used for conditional formatting only)
        $Worksheet.Column(($ColumnHeader.Name.IndexOf('Policy status') + 1)).Hidden = $true # Hide the "Policy status" column (used for conditional formatting only)
        $ColumnHeader.Clear()
        Remove-Variable -Name 'ColumnHeader','Worksheet','Range' -Force -EA Ignore
        $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
        $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
        Write-Verbose -Message "[$InvocationName] Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)"
    }

    # Link the "Policy id" (Summary worksheet) to the corresponding policy's settings
    $Worksheet = $Excel.Workbook.Worksheets["$SummaryWorksheetName"]
    for ($Row = 2; $Row -le ($Worksheet.Dimension.Rows); $Row++) {
        [String]$Id = $Worksheet.Cells["A$Row"].Text
        $hyperlinkObj = New-Object -TypeName 'OfficeOpenXml.ExcelHyperLink' -ArgumentList @($DetailHash["$Id"], "$Id")
        $hyperlinkObj.ToolTip = "See the detailed settings for [$($Worksheet.Cells["B$Row"].Text)]"
        $Worksheet.Cells["A$Row"].Hyperlink = $hyperlinkObj
        #Changing cell style from Normal to Hyperlink
        $Worksheet.Cells["A$Row"].Style.Font.Color.SetColor([System.Drawing.Color]0x467886)
        $Worksheet.Cells["A$Row"].Style.Font.UnderLine = $true
    }
    $DetailHash.Clear()
    $SummaryHash.Clear()
    #endregion Details

    Select-Worksheet -ExcelPackage $Excel -WorksheetName $SummaryWorksheetName -Verbose:$false
    Close-ExcelPackage -ExcelPackage $Excel -Show:$Show -Verbose:$false

    Remove-Variable -Name 'DetailHash','Worksheet','PolicyGroup','PolicyGroupList','PolicyList','Excel' -Force -EA Ignore
    # End function and report memory usage, before and after cleaning it up
    $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
    $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
    Write-Log -Message "[$InvocationName] Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)"

    #endregion main
    $ErrorActionPreference = 'Continue'
}


function Get-IntunePolicySummaryReport {
    [CmdletBinding()]
    param ()

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
    }
    process {
        # POST https://graph.microsoft.com/beta/deviceManagement/reports/cachedReportConfigurations
        $Body = @{
            id      = 'ConfigurationPolicyAggregate_00000000-0000-0000-0000-000000000001'
            filter  = "((UnifiedPolicyPlatformType eq 'Windows10x') or (UnifiedPolicyPlatformType eq 'Windows10') or (UnifiedPolicyPlatformType eq 'Windows81AndLater') or (UnifiedPolicyPlatformType eq 'Unknown'))"
            orderBy = @(
                'NumberOfConflictDevices desc'
            )
            select  = @(
                'PolicyName'
                'UnifiedPolicyType'
                'UnifiedPolicyPlatformType'
                'NumberOfCompliantDevices'
                'NumberOfNonCompliantOrErrorDevices'
                'NumberOfConflictDevices'
                'NumberOfNotApplicableDevices'
            )
        }
        $Result = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/reports/cachedReportConfigurations' -Method POST -APIVersion beta -Body $body

        if ($Result.status -ne 'InProgress') {
            throw "[$InvocationName] could not refresh the report: $($Result.status)"
        }
        do {
            Start-Sleep -Seconds 10
            $Result = Invoke-MgGraphRequestSingle -Resource "deviceManagement/reports/cachedReportConfigurations('ConfigurationPolicyAggregate_00000000-0000-0000-0000-000000000001')" -APIVersion beta
            <#
@odata.context      : https://graph.microsoft.com/beta/$metadata#deviceManagement/reports/cachedReportConfigurations/$entity
id                  : ConfigurationPolicyAggregate_00000000-0000-0000-0000-000000000001
reportName          : ConfigurationPolicyAggregate
filter              : (UnifiedPolicyPlatformType eq 'Windows10x' or UnifiedPolicyPlatformType eq 'Windows10' or UnifiedPolicyPlatformType eq 'Windows81AndLater' or UnifiedPolicyPlatformType eq 'Unknown')
select              : {PolicyName, UnifiedPolicyType, UnifiedPolicyPlatformType, NumberOfCompliantDevices…}
orderBy             : {NumberOfConflictDevices asc}
metadata            :
status              : completed
lastRefreshDateTime : 11/18/2025 2:19:22 PM
expirationDateTime  : 11/25/2025 2:19:22 PM
#>
        } while (($null -ne $Result) -and ($Result.status -ne 'Completed'))

        #POST https://graph.microsoft.com/beta/deviceManagement/reports/getCachedReport
        $Body = @{
            id      = 'ConfigurationPolicyAggregate_00000000-0000-0000-0000-000000000001'
            select  = @(
                'PolicyName'
                'UnifiedPolicyType'
                'UnifiedPolicyPlatformType'
                'NumberOfCompliantDevices'
                'NumberOfNonCompliantOrErrorDevices'
                'NumberOfConflictDevices'
                'NumberOfNotApplicableDevices'
            )
            orderBy = @(
                'NumberOfConflictDevices desc'
            )
            filter  = "((UnifiedPolicyPlatformType eq 'Windows10x') or (UnifiedPolicyPlatformType eq 'Windows10') or (UnifiedPolicyPlatformType eq 'Windows81AndLater') or (UnifiedPolicyPlatformType eq 'Unknown'))"
        }

        $Result = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/reports/getCachedReport' -Method POST -APIVersion beta -Body $body
        $Schema = $Result.Schema | Select-Object -Property @{Label = 'Index'; Expression = { $Result.Schema.IndexOf($_) } }, *
        for ($iv = 0; $iv -lt ($Result.Values | Measure-Object).Count; $iv++) {
            [PSCustomObject]@{
                Platform                   = $Result.Values[$iv][(($Schema | Where-Object -Property Column -EQ 'UnifiedPolicyPlatformType_loc').Index)]
                PolicyType                 = $Result.Values[$iv][(($Schema | Where-Object -Property Column -EQ 'UnifiedPolicyType_loc').Index)]
                PolicyName                 = $Result.Values[$iv][(($Schema | Where-Object -Property Column -EQ 'PolicyName').Index)]
                CompliantDevices           = $Result.Values[$iv][(($Schema | Where-Object -Property Column -EQ 'NumberOfCompliantDevices').Index)]
                ConflictDevices            = $Result.Values[$iv][(($Schema | Where-Object -Property Column -EQ 'NumberOfConflictDevices').Index)]
                NonCompliantOrErrorDevices = $Result.Values[$iv][(($Schema | Where-Object -Property Column -EQ 'NumberOfNonCompliantOrErrorDevices').Index)]
                NotApplicableDevices       = $Result.Values[$iv][(($Schema | Where-Object -Property Column -EQ 'NumberOfNotApplicableDevices').Index)]
            }
        }
    }
}


function Get-IntunePolicyReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [String]$PolicyId
    )

    begin {
        #$InvocationName = $MyInvocation.MyCommand.Name
        # POST https://graph.microsoft.com/beta/deviceManagement/reports/getConfigurationSettingNoncomplianceReport
        <#
@{
    select    = @(
        'SettingName'
        'SettingStatus'
        'ErrorCode'
        'SettingInstanceId'
        'SettingInstancePath'
    )
    skip      = 0
    top       = 50
    filter    = "(PolicyId eq '6ebc8eba-96a0-4ebf-b934-e69ed44068d0') and (DeviceId eq '9e601241-4b2f-4040-80a5-9872178488eb') and (UserId eq '94f9d961-e4c2-47f3-93a7-2e7a734293bb') and (SettingStatus eq '6')"
    orderBy   = @()
    sessionId = 'fe413599-7d33-4a48-9fa1-ce6f0e255e67'
}
  #GET https://graph.microsoft.com/beta/deviceManagement/managedDevices/9e601241-4b2f-4040-80a5-9872178488eb/deviceConfigurationStates/6ebc8eba-96a0-4ebf-b934-e69ed44068d0/settingStates?$filter=(userId%20eq%20%2794f9d961-e4c2-47f3-93a7-2e7a734293bb%27)%20and%20(settingInstanceId%20eq%20%27b283aa15-7d10-0201-b9dc-20dd67856366%27)
        #>
    }
    process {
        $Body = @{
            select = @('NumberOfCompliantDevices', 'NumberOfConflictDevices', 'NumberOfNotApplicableDevices', 'NumberOfNonCompliantOrErrorDevices', 'NumberOfInProgressDevices', 'UnifiedPolicyType')
            filter = "((PolicyBaseTypeName eq 'DeviceManagementConfigurationPolicy')) and (PolicyId eq '$PolicyId')"
        }
        $json = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/reports/getConfigurationPolicyDeviceSummaryReport' -Method POST -APIVersion beta -Body $body | ConvertFrom-Json
        $Object = [PSCustomObject]@{}
        for ($i = 0; $i -lt ($json.Schema | Measure-Object).Count; $i++) {
            if ( $json.Schema[$i].PropertyType -match 'string') { continue }
            $Name = $json.Schema[$i].Column -replace 'NumberOf'
            $Value = $json.Values[0][$i]
            Add-Member -InputObject $Object -MemberType NoteProperty -Name $Name -Value $value -Force
        }
        $Object
    }
}


function Get-IntunePolicyTemplate {
    <#
.SYNOPSIS
    Get a list of the Intune policy templates.

.DESCRIPTION
    Get a list of the Intune policy templates.

.PARAMETER displayName
    id of the template.

.PARAMETER displayName
    Name of the template.

.PARAMETER lifecycleState
    State of the template (draft,superseded,active).

.PARAMETER templateFamily
    Type of template.
        appQuietTime
        baseline
        deviceConfigurationPolicies
        deviceConfigurationScripts
        endpointSecurityAccountProtection
        endpointSecurityAntivirus
        endpointSecurityApplicationControl
        endpointSecurityAttackSurfaceReduction
        endpointSecurityDiskEncryption
        endpointSecurityEndpointDetectionAndResponse
        endpointSecurityEndpointPrivilegeManagement
        endpointSecurityFirewall
        enrollmentConfiguration
        windowsOsRecoveryPolicies


.EXAMPLE
    PS C:\> Get-IntunePolicyTemplate

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-10-01
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [String[]]$id,

        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [ValidateSet(
            'Advanced Security Baseline for HoloLens 2',
            'Microsoft 365 Apps for Enterprise Security Baseline',
            'Microsoft Defender for Endpoint Security Baseline',
            'Security Baseline for Microsoft Edge',
            'Security Baseline for Windows 10 and later',
            'Standard Security Baseline for HoloLens 2',
            'Windows 365 Security Baseline'
        )]
        [String[]]$displayName,

        [Parameter(Position = 1, ParameterSetName = 'ById')]
        [Parameter(Position = 1, ParameterSetName = 'ByName')]
        [ValidateSet('draft', 'superseded', 'active')]
        [String]$lifecycleState,

        [Parameter(Position = 2, ParameterSetName = 'ById')]
        [Parameter(Position = 2, ParameterSetName = 'ByName')]
        [ValidateSet(
            'appQuietTime',
            'baseline',
            'deviceConfigurationPolicies',
            'deviceConfigurationScripts',
            'endpointSecurityAccountProtection',
            'endpointSecurityAntivirus',
            'endpointSecurityApplicationControl',
            'endpointSecurityAttackSurfaceReduction',
            'endpointSecurityDiskEncryption',
            'endpointSecurityEndpointDetectionAndResponse',
            'endpointSecurityEndpointPrivilegeManagement',
            'endpointSecurityFirewall',
            'enrollmentConfiguration',
            'windowsOsRecoveryPolicies'
        )]
        [String]$templateFamily
    )

    begin {
        #$InvocationName = $MyInvocation.InvocationName
    }
    process {
        $GRParams = @{
            APIVersion = 'beta'
            Resource   = 'deviceManagement/configurationPolicyTemplates'
            Select     = 'displayName', 'displayversion', 'lifecyclestate', 'settingtemplatecount', 'version', 'id', 'baseid', 'templateFamily'
        }
        $GRParams.Filter = $(
            if ("$templateFamily".Trim() -ne '') {
                "templateFamily eq '$templateFamily'"
            }
            if ("$lifecyclestate" -ne '') {
                "lifecyclestate eq '$lifecyclestate'"
            }
        ) -join ' and '

        if ("$($GRParams.Filter)".Trim() -eq '') { $GRParams.Remove('Filter') }
        $TemplateList = Invoke-MgGraphRequestSingle @GRParams |
            Select-Object -Property templateFamily,
            @{Label = 'TemplateName'; Expression = { $_.displayname } },
            displayversion,
            version,
            lifecyclestate,
            settingtemplatecount,
            @{Label = 'TemplateId'; Expression = { $_.id } },
            @{Label = 'TemplateBaseId'; Expression = { $_.baseid } }

        if ($displayName.Count -gt 0) {
            $TemplateList | Where-Object -Property TemplateName -Match (($DisplayName | ForEach-Object { [regex]::Escape($_) }) -join '|')
        }
        elseif ($id.Count -gt 0) {
            $TemplateList | Where-Object -Property TemplateId -In $id
        }
        else {
            $TemplateList
        }
    }
    end {}
}


function Get-IntuneTemplate {
    <#
.SYNOPSIS
    Get a list of the Intune templates.

.DESCRIPTION
    Get a list of the Intune templates.

.PARAMETER displayName
    id of the template.

.PARAMETER displayName
    Name of the template.

.PARAMETER type
    Type of the template.

.PARAMETER plaftform
    Target platform.

.EXAMPLE
    PS C:\> Get-IntuneTemplate

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-01-15
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK

#>


    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [Alias('TemplateId')]
        [String[]]$id,

        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [String[]]$displayName,

        [Parameter(Position = 1, ParameterSetName = 'ById')]
        [Parameter(Position = 1, ParameterSetName = 'ByName')]
        [ValidateSet('advancedThreatProtectionSecurityBaseline', 'cloudPC', 'deviceConfigurationForOffice365', 'microsoftEdgeSecurityBaseline', 'securityBaseline', 'securityTemplate')]
        [String]$type,

        [Parameter(Position = 2, ParameterSetName = 'ById')]
        [Parameter(Position = 2, ParameterSetName = 'ByName')]
        [ValidateSet('windows10AndLater', 'android', 'iOS')]
        [String]$platform,

        [Parameter(ParameterSetName = 'ById')]
        [Switch]$NameOnly
    )

    begin {
        #$InvocationName = $MyInvocation.InvocationName
    }
    process {
        $GRParams = @{
            APIVersion = 'beta'
            Resource   = 'deviceManagement/templates'
        }
        $GRParams.Filter = $(
            if ("$type".Trim() -ne '') {
                "templateType eq '$type'"
            }
            if ("$platform" -ne '') {
                "platformType eq '$platform'"
            }
        ) -join ' and '

        if ($NameOnly.IsPresent -eq $true) {
            $GRParams.Select = 'id','displayName'
        }

        if ("$($GRParams.Filter)".Trim() -eq '') { $GRParams.Remove('Filter') }

        $TemplateList = Invoke-MgGraphRequestSingle @GRParams |
            Select-Object -Property id,
            templateSubtype,
            templateType,
            platformType,
            isDeprecated,
            publishedDateTime,
            @{Label = 'TemplateName'; Expression = { $_.displayname } },
            description,
            versionInfo,
            intentCount
        if ($displayName.Count -gt 0) {
            $TemplateList | Where-Object -Property TemplateName -Match (($DisplayName | ForEach-Object { [regex]::Escape($_) }) -join '|')
        }
        elseif ($id.Count -gt 0) {
            $TemplateList | Where-Object -Property id -In $id
        }
        else {
            $TemplateList
        }
    }
    end {}
}


function Get-IntuneSettingCategory {
    <#
.SYNOPSIS
    Get a list of all the Intune setting categories.

.DESCRIPTION
    Get a list of all the Intune setting categories, as shown in the portal.

.PARAMETER id
    id of the category.

.PARAMETER AsHashtable
    Return the category as an hashtable.

.PARAMETER NameOnly
    Only return the full displayName of the category.

.EXAMPLE
    PS C:\> Get-IntuneSettingCategory

.EXAMPLE
    PS C:\> Get-IntuneSettingCategory -AsHashtable

.EXAMPLE
    PS C:\> Get-IntuneSettingCategory -AsHashtable -NameOnly

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-06-03
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [String[]]$id,

        [Switch]$AsHashtable,

        [Switch]$NameOnly
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        $CategoryList = @{}
        $FullPath = New-Object -TypeName 'System.Collections.Generic.List[String]'
        if ($NameOnly.IsPresent) {
            $Select = @('id','displayName','parentCategoryId')
        }
        else {
            $Select = @('id','displayName','platforms','categoryDescription','parentCategoryId')
        }
        $Params = @{
            Resource    = 'deviceManagement/configurationCategories'
            APIVersion  = 'beta'
            Select      = $Select
            ErrorAction = 'Stop'
        }
        $ConfigCategoryList = Invoke-MgGraphRequestSingle @Params | Convert-PSObjectArrayToHashTable -idProperty id
    }
    process {
        <# [String[]]$PlatformList = $ConfigCategoryList.values.platforms -split ',' | Sort-Object -Unique
        foreach ($PlatformItem in $PlatformList) {
            New-Variable -Name $PlatformItem -Value @{} -Force
        } #>
        $IdList = $ConfigCategoryList.Keys
        if ($Id.Count -gt 0) { $IdList = $id | Select-Object -Unique }
        foreach ($CategoryId in $IdList) {
            $TempCat = $Category = $ConfigCategoryList["$CategoryId"]
            if ($null -eq $Category) {
                Write-Warning -Message "[$InvocationName] Failed to get information about [$CategoryId]"
                continue
            }
            $FullPath.Add($Category.displayName)
            while ($TempCat.parentCategoryId -ne '00000000-0000-0000-0000-000000000000') {
                $TempCat = $ConfigCategoryList["$($TempCat.parentCategoryId)"]
                $FullPath.Add($TempCat.displayName)
            }
            $FullPath.Reverse()
            if ($NameOnly.IsPresent) {
                $CategoryList["$CategoryId"] = $FullPath -join '\'
            }
            else {
                $CategoryList["$CategoryId"] = [PSCustomObject]@{
                    id          = $CategoryId
                    displayName = $Category.displayName
                    platforms   = $Category.platforms -split ','
                    FullPath    = $FullPath -join '\'
                    description = $Category.categoryDescription
                }
            }
            $FullPath.Clear()
        }
    }
    end {
        $ConfigCategoryList.Clear()
        $FullPath = $null
        Write-Verbose -Message "[$InvocationName] Found $($CategoryList.Count) categorie(s)"
        if ($AsHashtable.IsPresent -eq $true) {
            $CategoryList.Clone()
        }
        else {
            $CategoryList.Clone().Values
        }
        $CategoryList.Clear()
        $ConfigCategoryList = $null
        $null = [System.GC]::GetTotalMemory($true)
    }
}
#endregion Intune policies


#region Intune RBAC
function Get-IntuneScopeTag {
    <#
.SYNOPSIS
    Get the Intune scope tags.

.DESCRIPTION
    Get the Intune scope tags.

    The results contain the following properties:
        id
        displayName
        description
        isBuiltin
        assignments (id and display name of the assigned groups)

.PARAMETER displayName
    Name of the scope tag.

.PARAMETER id
    id of the scope tag.

.EXAMPLE
Return every scope tag.

    PS C:\> Get-IntuneScopeTag

.EXAMPLE
Return scope tags that have the ids 0 or 13.

    PS C:\> Get-IntuneScopeTag -id 0,13

.EXAMPLE
Return scope tags that are named either ScopeTag1 or ScopeTag2.

    PS C:\> Get-IntuneScopeTag -Name 'ScopeTag1','ScopeTag2'

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-01-14
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [Alias('Name')]
        [String[]]$DisplayName,

        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [String[]]$id
    )

    begin {
        #$InvocationName = $MyInvocation.MyCommand.Name
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            [String[]]$id = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/roleScopeTags' -APIVersion beta -Select displayName,id | Where-Object -Property DisplayName -In $DisplayName | Select-Object -ExpandProperty id
        }
        if ($id.Count -eq 0) {
            [String[]]$id = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/roleScopeTags' -APIVersion beta -Select id | Select-Object -ExpandProperty id
        }
        $HashTable = $(
            foreach ($ScopeId in $id) {
                @{
                    id     = "ScopeTag_$ScopeId"
                    method = 'GET'
                    url    = 'deviceManagement/roleScopeTags/{0}' -f $ScopeId
                }
                @{
                    id     = "Assignment_$ScopeId"
                    method = 'GET'
                    url    = 'deviceManagement/roleScopeTags/{0}/assignments' -f $ScopeId
                }
            }
        )

        $BatchResults = Invoke-MgGraphRequestBatch -Hashtable $HashTable -APIVersion beta -DoNotLogErrors

        [String[]]$GroupidList = ($BatchResults | Where-Object -Property id -Like 'assignment*').body.value.Target.groupid | Select-Object -Unique
        if ($GroupidList.Count -gt 0) {
            $GroupList = Invoke-MgGraphRequestBatch -Resource 'groups' -ObjectList $GroupidList -Select 'displayName' -DoNotLogErrors | Select-Object -Property id, @{Label = 'displayName'; Expression = { $_.Body.displayName } }
        }

        ($BatchResults | Where-Object -Property id -Like 'ScopeTag*') |
            Select-Object -Property @{Label = 'id'; Expression = { $_.body.id } },
            @{Label = 'displayName'; Expression = { $_.body.displayName } },
            @{Label = 'description'; Expression = { $_.body.description } },
            @{Label = 'isBuiltIn'; Expression = { $_.body.isBuiltIn } },
            @{Label = 'assignments'; Expression = { $GroupList | Where-Object -Property id -In ($BatchResults | Where-Object -Property id -EQ "assignment_$($_.body.id)").body.value.Target.groupid } }
    }
}


function Get-IntuneRBACRole {
    <#
.SYNOPSIS
    Get the Intune RBAC roles.

.DESCRIPTION
    Get the Intune RBAC roles.

    The results contain the following properties depending on the parameters used:

.PARAMETER displayName
    Name of the role.

.PARAMETER id
    id of the role.

.PARAMETER type
    Type of the role (Intune, W365, Autopatch).

.EXAMPLE
Return every role.

    PS C:\> Get-IntuneRBACRole

.EXAMPLE
Return the role with the id 49402c68-7a81-43b6-bda9-98a964fae76d.

    PS C:\> Get-IntuneRBACRole -id '49402c68-7a81-43b6-bda9-98a964fae76d'

.EXAMPLE
Return the roles named either "Policy and Profile manager" or "Custom role 1".

    PS C:\> Get-IntuneRBACRole -DisplayName "Policy and Profile manager","Custom role 1"

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-01-14
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [Alias('Name')]
        [String[]]$DisplayName,

        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [String[]]$id,

        [Parameter(Position = 1, ParameterSetName = 'ById')]
        [Parameter(Position = 1, ParameterSetName = 'ByName')]
        [String]$Type
    )

    begin {
        #$InvocationName = $MyInvocation.MyCommand.Name
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            [String[]]$id = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/roleDefinitions' -APIVersion beta -Select displayName,id | Where-Object -Property DisplayName -In $DisplayName | Select-Object -ExpandProperty id
        }
        if ($id.Count -eq 0) {
            [String[]]$id = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/roleDefinitions' -APIVersion beta -Select id | Select-Object -ExpandProperty id
        }
        $HashTable = $(
            foreach ($RoleId in $id) {
                @{
                    id     = "Role_$RoleId"
                    method = 'GET'
                    url    = 'deviceManagement/roleDefinitions/{0}' -f $RoleId
                }
                @{
                    id     = "Assignment_$RoleId"
                    method = 'GET'
                    url    = 'deviceManagement/roleDefinitions/{0}/roleAssignments?$select=id' -f $RoleId #&$expand=microsoft.graph.deviceAndAppManagementRoleAssignment/roleScopeTags
                }
            }
            @{
                id     = 'Assignments'
                method = 'GET'
                url    = 'deviceManagement/roleassignments'
            }
        )

        $BatchResults = Invoke-MgGraphRequestBatch -Hashtable $HashTable -APIVersion beta -DoNotLogErrors

        $Assignments = ($BatchResults | Where-Object -Property id -EQ 'assignments').Body.value
        [String[]]$GroupidList = @($Assignments.members) + @($Assignments.resourceScopes) + @($Assignments.scopeMembers) | Select-Object -Unique
        if ($GroupidList.Count -gt 0) {
            $GroupList = Invoke-MgGraphRequestBatch -Resource 'groups' -ObjectList $GroupidList -Select 'displayName' -DoNotLogErrors | Select-Object -Property id, @{Label = 'displayName'; Expression = { $_.Body.displayName } }
        }

        $ScopeTagList = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/roleScopeTags' -APIVersion beta -Select id, displayName

        foreach ($Role in ($BatchResults | Where-Object -Property id -Like 'Role_*').body) {
            $RoleAssignments = $Assignments | Where-Object -Property id -In (($BatchResults | Where-Object -Property id -Like ('Assignment_{0}' -f $Role.id))).body.value.id
            [String]$RoleType = $(
                switch ("$(($Role.'@odata.type' -split '\.')[-1])") {
                    'deviceAndAppManagementRoleDefinition' { 'Intune' }
                    'Windows365RoleDefinition' { 'Windows 365' } # TODO
                    'AutopatchRoleDefinition' { 'Autopatch' } # TODO
                    default { $_ }
                }
            )
            if (($RoleAssignments | Measure-Object).Count -eq 0) {
                [PSCustomObject]@{
                    Roleid                  = $Role.id
                    RoleName                = $Role.displayName
                    Roletype                = $RoleType
                    description             = $Role.description
                    isBuiltIn               = $Role.isBuiltIn
                    isBuiltInRoleDefinition = $Role.isBuiltInRoleDefinition
                    RoleScopeTags           = ($ScopeTagList | Where-Object -Property id -In $Role.roleScopeTagIds).displayName
                    AssignmentId            = ''
                    AssignmentName          = ''
                    AssignmentDescription   = ''
                    AssignmentScopeGroup    = ''
                    AssignmentScopeType     = ''
                    AssignmentMembers       = ''
                    AssignmentScopeTags     = ''
                }
            }
            else {
                foreach ($RA in $RoleAssignments) {
                    [Object[]]$ScopeGroup = $(
                        switch ($RA.ScopeType) {
                            'allDevicesAndLicensedUsers' { ('All devices', 'All users'); break }
                            'AllDevices' { 'All devices' }
                            'resourceScope' { ($GroupList | Where-Object -Property id -In $RA.resourceScopes).displayName; break }
                            default { '' }
                        }
                    )
                    [PSCustomObject]@{
                        Roleid                  = $Role.id
                        RoleName                = $Role.displayName
                        Roletype                = $RoleType
                        description             = $Role.description
                        isBuiltIn               = $Role.isBuiltIn
                        isBuiltInRoleDefinition = $Role.isBuiltInRoleDefinition
                        RoleScopeTags           = ($ScopeTagList | Where-Object -Property id -In $Role.roleScopeTagIds).displayName
                        AssignmentId            = $RA.id
                        AssignmentName          = $RA.displayName
                        AssignmentDescription   = $RA.description
                        AssignmentScopeGroup    = $ScopeGroup
                        AssignmentScopeType     = $RA.scopeType
                        AssignmentMembers       = ($GroupList | Where-Object -Property id -In $RA.members).displayName
                        AssignmentScopeTags     = ($ScopeTagList | Where-Object -Property id -In $RA.roleScopeTagIds).displayName
                    }
                }
            }
        }
    }
}


function Get-IntuneAssignmentFilter {
    <#
.SYNOPSIS
    List Intune assignment filters.

.DESCRIPTION
    List Intune assignment filters.

.PARAMETER id
    id of the assignment filter

.PARAMETER displayName
    Display name of the assignment filter.

.PARAMETER assignment
    Add the filter assignments to the results.

.EXAMPLE
    PS C:\> Get-IntuneAssignmentFilter -Assignment

.EXAMPLE
    PS C:\> Get-IntuneAssignmentFilter -displayName 'Filter1','Filter2'

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-03-11
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [String[]]$id,

        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [String[]]$displayName,

        [Parameter(ParameterSetName = 'ById')]
        [Parameter(ParameterSetName = 'ByName')]
        [Switch]$assignment
    )

    begin {
        $InvocationName = $MyInvocation.InvocationName
        $APIResource = 'deviceManagement/assignmentFilters'
        $APIVersion = 'beta'
        $GRParams = @{
            APIVersion     = $APIVersion
            Resource       = ''
            Select         = 'displayName'
            DoNotLogErrors = $true
        }
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            Write-Verbose -Message "[$InvocationName] Querying assignment filters with name [$($displayName -join ', ')]"
            [String[]]$id = Invoke-MgGraphRequestSingle -APIVersion $APIVersion -Resource $APIResource -Filter "displayName in ('$($displayName -join "','")')" -Select id | Select-Object -ExpandProperty id
        }

        if ($id.Count -eq 0) {
            Write-Verbose -Message "[$InvocationName] Querying all assignment filters"
            [String[]]$id = Invoke-MgGraphRequestSingle -APIVersion $APIVersion -Resource $APIResource -Select id | Select-Object -ExpandProperty id
        }

        if ($id.Count -eq 0) {
            Write-Warning -Message "[$InvocationName] Could not find any assignment filter"
            return
        }
        Write-Verbose -Message "[$InvocationName] Found $($id.Count) assignment filters"

        $HashTable = $(
            foreach ($Filterid in $id) {
                @{
                    id     = "$Filterid"
                    method = 'GET'
                    url    = '{0}/{1}' -f $APIResource, $Filterid
                }
                if ($Assignment.IsPresent) {
                    @{
                        id     = '{0}_Payloads' -f $Filterid
                        method = 'GET'
                        url    = '{0}/{1}/payloads' -f $APIResource, $Filterid
                    }
                }
            }
            @{
                id     = 'ScopeTags'
                method = 'GET'
                url    = 'deviceManagement/roleScopeTags?$select=id,displayName'
            }
        )

        $BatchResults = Invoke-MgGraphRequestBatch -APIVersion $APIVersion -Hashtable $HashTable | Convert-PSObjectArrayToHashTable -idProperty id -Verbose:$false
        $ScopeTagList = ($BatchResults['ScopeTags']).body.value

        if ($assignment.IsPresent) {
            $PayloadList = $(
                foreach ($PayloadId in ($BatchResults.keys | Where-Object { $_ -like '*_Payloads' })) {
                    $BatchResults["$PayloadId"].body.value
                }
            )
            Write-Verbose -Message "[$InvocationName] Querying assignments for $(($PayloadList | Measure-Object).Count) payload(s)"
            [String[]]$GroupIdList = $PayloadList.groupId | Select-Object -Unique
            if ($GroupIdList.Count -gt 0) {
                Write-Verbose -Message "[$InvocationName] Querying $($GroupIdList.Count) group name(s)"
                $GroupList = Get-EntraIdGroupInfo -id $GroupIdList | Convert-PSObjectArrayToHashTable -idProperty id -Verbose:$false
            }
            else {
                Write-Verbose -Message "[$InvocationName] No group id in the payloads"
                $GroupList = @{}
            }

            $PayloadNames = @{}
            foreach ($Type in ($PayloadList | Group-Object -Property payloadType)) {
                [String[]]$payloadIdList = $Type.Group | Select-Object -ExpandProperty payloadId -Unique
                [String[]]$Resource = $(
                    switch -Regex ($Type.Name) {
                        'enrollment' {
                            'deviceManagement/deviceEnrollmentConfigurations'
                            'deviceManagement/windowsAutopilotDeploymentProfiles'
                            'deviceManagement/appleUserInitiatedEnrollmentProfiles'
                            break
                        }
                        'Configuration|compliance' {
                            'deviceManagement/configurationPolicies'
                            'deviceManagement/deviceConfigurations'
                            'deviceManagement/groupPolicyConfigurations'
                            'deviceManagement/deviceCompliancePolicies'
                            'deviceAppManagement/mobileAppConfigurations'
                            break
                        }
                        '(application|App\b)' {
                            'deviceAppManagement/mobileApps'
                            break
                        }
                        default {
                            Write-Warning -Message "[$InvocationName] Unmanaged payload type: $_"
                            $Script:AssignableIntuneResourceMap.Resource | Select-Object -Unique
                        }
                    }
                )
                $Found = 0
                Write-Verbose -Message "[$InvocationName] Trying to retrieve the name for $($payloadIdList.Count) payloads of type [$($Type.Name)] using the following resources: $($Resource -join ',')"

                foreach ($ResourceItem in $Resource) {
                    $GRParams.Select = 'displayName'
                    if ($ResourceItem -in ('deviceManagement/configurationPolicies')) {
                        $GRParams.Select = 'name'
                    }
                    $GRParams.Resource = $ResourceItem
                    $GRParams.ObjectList = $payloadIdList
                    if ($ResourceItem -eq 'deviceManagement/deviceEnrollmentConfigurations') {
                        $GRParams.ObjectList = $(foreach ($Suffix in $EnrollementIdSuffix) { $payloadIdList | ForEach-Object { '{0}{1}' -f $_, $Suffix } })
                    }
                    $Result = Invoke-MgGraphRequestBatch @GRParams | Where-Object -Property Status -EQ 200
                    if ($null -ne $Result) {
                        $Found += ($Result | Measure-Object).Count
                        Write-Verbose -Message "[$InvocationName] Found [$Found] object out of $($payloadIdList.count) using [$ResourceItem]"
                        $Result | ForEach-Object { $PayloadNames["$($_.id)"] = $_.body."$($GRParams.Select)" }
                    }
                    if ($Found -eq $payloadIdList.Count) {
                        Write-Verbose -Message "[$InvocationName] Found all of the [$($Type.Name)] objects"
                        break
                    }
                }
                if ($Found -lt $payloadIdList.Count) {
                    $Found = 0
                    $GRParams.ObjectList = $payloadIdList = $payloadIdList | Where-Object { $_ -notin $PayloadNames.Keys }
                    $GRParams.Select = 'displayName'
                    [String[]]$Resource = $Script:AssignableIntuneResourceMap.Resource | Select-Object -Unique | Where-Object { $_ -notin $Resource }
                    Write-Warning -Message "[$InvocationName] Not all of the [$($Type.Name)] objects could be found ($($payloadIdList.Count) remaining). Trying again using these resources: $($Resource -join ', ')"
                    foreach ($ResourceItem in $Resource) {
                        $GRParams.Resource = $ResourceItem
                        $Result = Invoke-MgGraphRequestBatch @GRParams | Where-Object -Property Status -EQ 200
                        if ($null -ne $Result) {
                            $Found += ($Result | Measure-Object).Count
                            Write-Verbose -Message "[$InvocationName] Found [$Found] object out of $($payloadIdList.count) using [$ResourceItem]"
                            $Result | ForEach-Object { $PayloadNames["$($_.id)"] = $_.body.$PropertyName }
                        }
                        if ($Found -eq $payloadIdList.Count) {
                            Write-Verbose -Message "[$InvocationName] Found all of the [$($Type.Name)] objects"
                            break
                        }
                    }
                }
            }
            Write-Verbose -Message "[$InvocationName] Found $($PayloadNames.Keys.Count) names"
            $payloadIdList = $PayloadList = $null
        }


        foreach ($Filterid in $id) {
            $Filter = $BatchResults["$FilterId"]
            if ($null -eq $Filter.body.id) {
                Write-Warning -Message "[$InvocationName] Could not find an assignment filter with the id [$Filterid]"
            }
            else {
                Write-Verbose -Message "[$InvocationName] Processing [$($Filter.body.displayName)] with id {$($Filterid)}"
                $Object = [PSCUstomObject]@{
                    id                             = $Filter.body.id
                    displayName                    = $Filter.body.displayName
                    platform                       = $Filter.body.platform
                    assignmentFilterManagementType = $Filter.body.assignmentFilterManagementType
                    rule                           = $Filter.body.rule
                    createdDateTime                = $Filter.body.createdDateTime
                    lastModifiedDateTime           = $Filter.body.lastModifiedDateTime
                    roleScopeTags                  = $ScopeTagList | Where-Object -Property id -In $Filter.body.roleScopeTags | Select-Object -ExpandProperty displayName
                    description                    = $Filter.body.description
                }
                if ($Assignment.IsPresent) {
                    $Payload = $BatchResults["${FilterId}_Payloads"].body.value |
                        Select-Object -Property payloadId,
                        @{Label = 'payloadName'; Expression = { [string]($PayloadNames["$($_.payloadId)"]) } },
                        payloadType,
                        assignmentFilterType,
                        groupId,
                        @{Label = 'groupName'; Expression = { [string]($GroupList["$($_.groupId)"].displayName) } }
                    $Object | Add-Member -Name 'assignments' -MemberType NoteProperty -Value $Payload -Force -EA Ignore
                }
                $Object
            }
        }
        $ScopeTagList = $BatchResults = $Payload = $GroupList = $GroupIdList = $null
    }
    end {
        # End function/script and report memory usage, before and after cleaning it up
        $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
        $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
        Write-Verbose -Message "[$InvocationName] Function finished. Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)"
    }
}
#endregion Intune RBAC


#region Intune scripts
function Get-IntuneHealthScript {
    <#
.SYNOPSIS
    Get the Intune health (remediation) scripts.

.DESCRIPTION
    Get the Intune health (remediation) scripts.

    The results contain the following properties depending on the parameters used:
        displayName            = Name of the script
        status                 = Status of the script (Active or Not deployed)
        version                = Version of the script
        author                 = Author of the script
        description            = Description of the script
        runSchedule            = Execution schedule of the script
        lastRun                = When the script was last run on any device
        runRemediation         = Is the remediation script enabled?
        runAsAccount           = Is the script configured to run in the user context?
        enforceSignatureCheck  = Must the script be signed?
        runAs32Bit             = Must the script be launched in a 32bit PowerShell session or a 64bit one?
        AssignmentType         = Type of assignment (Include, Exclude)
        Target                 = Name of the target (All devices, All users, group name)
        FilterType             = Type of filter (Include, Exclude)
        Filter                 = Name of the filter
        withoutIssue           = Number of detection that returned an exit code value of 0
        withIssue              = Number of detection that returned an exit code value of anything but 0
        detectionFailed        = Number of detection that failed (PowerShell Exception)
        detectionPending       = Number of detection that are pending execution
        detectionNotApplicable = Number of detection that are not applicable (filtered)
        remediated             = Number of remediation that were run succefully
        remediationSkipped     = Number of remediation that were skipped (Detection without issue)
        reccured               = Number of remediation that did not remediate
        remediationFailed      = Number of remediation that failed
        totalRemediated        = Number of total remediations
        createdDateTime        = Script creation date
        lastModifiedDateTime   = Script modification date
        roleScopeTagIds        = Scope tags linked to the script
        id                     = Id of the script

.PARAMETER displayName
    Name of the script.

.PARAMETER id
    id of the script.

.PARAMETER Assignment
    Add the assignments to the results.
    Multiple results can be returned for a single script if the number of included or excluded targets are assigned.

.PARAMETER RunSummary
    Add the execution statistics to the results.

.EXAMPLE
    PS C:\> Get-IntuneHealthScript

.EXAMPLE
    PS C:\>

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION:
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param (
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [String]$displayName,

        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Byid')]
        [String]$id,

        [Parameter(ParameterSetName = 'ByName')]
        [Parameter(ParameterSetName = 'Byid')]
        [switch]$Assignment,

        [Parameter(ParameterSetName = 'ByName')]
        [Parameter(ParameterSetName = 'Byid')]
        [switch]$RunSummary
    )

    begin {
        $InvocationName = $MyInvocation.InvocationName
        $RunSummaryPropertyList = @(
            @{Name = 'noIssueDetectedDeviceCount'; Target = 'WithoutIssue' },
            @{Name = 'issueDetectedDeviceCount'; Target = 'WithIssue' },
            @{Name = 'detectionScriptErrorDeviceCount'; Target = 'DetectionFailed' },
            @{Name = 'detectionScriptPendingDeviceCount'; Target = 'DetectionPending' },
            @{Name = 'detectionScriptNotApplicableDeviceCount'; Target = 'DetectionNotApplicable' },
            @{Name = 'issueRemediatedDeviceCount'; Target = 'Remediated' },
            @{Name = 'remediationSkippedDeviceCount'; Target = 'RemediationSkipped' },
            @{Name = 'issueReoccurredDeviceCount'; Target = 'Reccured' },
            @{Name = 'remediationScriptErrorDeviceCount'; Target = 'RemediationFailed' },
            @{Name = 'lastScriptRunDateTime'; Target = 'LastRun' },
            @{Name = 'issueRemediatedCumulativeDeviceCount'; Target = 'TotalRemediated' }
        )
        $ExcludePropertyList = New-Object -TypeName system.collections.ArrayList
        $SelectParams = @{} # Parameters used by Select-Object in order to exclude some properties depending on the Assignment and RunSummary parameters

        # Parameters used by Invoke-MgGraphRequestSingle to query the scripts
        $GRParams = @{
            APIVersion = 'beta'
            Resource   = 'deviceManagement/deviceHealthScripts'
            OrderBy    = 'displayName'
            Expand     = @()
        }

        #
        if ($Assignment.isPresent -eq $true) {
            $GRParams.Expand += 'assignments'
        }
        else {
            $ExcludePropertyList.AddRange(@('status', 'Target', 'FilterType', 'Filter', 'runSchedule', 'runRemediation', 'AssignmentType'))
        }
        if ($RunSummary.isPresent -eq $true) {
            $GRParams.Expand += 'runSummary'
        }
        else {
            $ExcludePropertyList.AddRange(@($RunSummaryPropertyList.Target))
        }
        if ($GRParams.Expand.Count -eq 0) { $GRParams.Remove('Expand') }
        if ($ExcludePropertyList.Count -gt 0) {
            $SelectParams.Property = '*'
            $SelectParams.ExcludeProperty = $ExcludePropertyList
        }
        $RBACAuthorized = (Get-MgContext).Scopes -match 'DeviceManagementRBAC'
    }
    process {
        $ItemRunSummary = $null
        if ("$DisplayName".Trim() -ne '') {
            $GRParams.Filter = "startswith(displayName, '$displayname')"
        }
        elseif ("$id".Trim() -ne '') {
            $GRParams.Resource = 'deviceManagement/deviceHealthScripts/{0}' -f $id
            # runSummary property is empty when using the id
            $ItemRunSummary = Invoke-MgGraphRequestSingle -APIVersion 'beta' -Resource ('deviceManagement/deviceHealthScripts/{0}/runsummary' -f $id)
        }
        $scriptList = Invoke-MgGraphRequestSingle @GRParams
        [String[]]$GroupIdList = $scriptList.assignments.target.groupid | Select-Object -Unique
        if ($GroupIdList.Count -gt 0) {
            $grouplist = Invoke-MgGraphRequestBatch -Resource 'groups' -Select 'displayname' -ObjectList $GroupIdList -DoNotLogErrors | Select-Object id, @{label = 'DisplayName'; Expression = { $_.body.displayName } }
        }
        if ($RBACAuthorized) {
            $ScopeTagList = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/roleScopeTags' -APIVersion 'beta' -EA Stop
        }
        else {
            Write-Warning -Message "[$InvocationName] Failed to get the scope tags due to missing permissions"
        }
        $FilterList = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/assignmentFilters' -Select 'id', 'displayname' -APIVersion 'beta' -ErrorAction Continue
        foreach ($script in $scriptList) {
            if ($RBACAuthorized) {
                [String[]]$ScopeTags = $ScopeTagList | Where-Object -Property id -In $Script.roleScopeTagIds | Select-Object -ExpandProperty displayName
            }
            else {
                [String[]]$ScopeTags = $Script.roleScopeTagIds
            }
            $Object = [PSCustomObject]@{
                displayName            = $Script.displayName
                status                 = 'Active'
                version                = $Script.version
                author                 = $Script.publisher
                description            = $Script.description
                runSchedule            = ''
                lastRun                = [datetime]::MinValue
                runRemediation         = $null
                runAsAccount           = $Script.runAsAccount
                enforceSignatureCheck  = $Script.enforceSignatureCheck
                runAs32Bit             = $Script.runAs32Bit
                AssignmentType         = ''
                Target                 = ''
                FilterType             = ''
                Filter                 = ''
                withoutIssue           = 0
                withIssue              = 0
                detectionFailed        = 0
                detectionPending       = 0
                detectionNotApplicable = 0
                remediated             = 0
                remediationSkipped     = 0
                reccured               = 0
                remediationFailed      = 0
                totalRemediated        = 0
                #deviceHealthScriptType  = $Script.deviceHealthScriptType
                createdDateTime        = $Script.createdDateTime
                lastModifiedDateTime   = $Script.lastModifiedDateTime
                #isGlobalScript          = $Script.isGlobalScript
                #highestAvailableVersion = $Script.highestAvailableVersion
                roleScopeTagIds        = $ScopeTags
                id                     = $Script.id
            } | Select-Object @SelectParams

            if ($RunSummary.IsPresent -eq $true) {
                $Item = $Script.runSummary
                if (($null -eq $Item) -and ($null -ne $ItemRunSummary)) {
                    $Item = $ItemRunSummary
                }
                foreach ($Property in $RunSummaryPropertyList) {
                    $Object."$($Property.Target)" = $Item."$($Property.Name)"
                }
            }
            if ($Assignment.IsPresent -eq $true) {
                if (($script.assignments | Measure-Object).Count -gt 0) {
                    $ConvertedTargetList = $script.assignments | ConvertFrom-IntuneAssignmentTarget -Groups $grouplist -Filters $FilterList
                    foreach ($as in $ConvertedTargetList) {
                        $Object.runRemediation = $as.AdditionalProperties.runRemediationScript
                        $Object.RunSchedule = $(
                            switch -Regex ("$($as.AdditionalProperties.runSchedule.'@odata.type')") {
                                'RunOnce' {
                                    [datetime]$DateTime = "$($as.AdditionalProperties.runSchedule.date)T$($as.AdditionalProperties.runSchedule.time)"
                                    if ($as.AdditionalProperties.runSchedule.useUtc -eq $true) {
                                        $DateTime = $DateTime.ToUniversalTime()
                                    }
                                    'Once on {0} at {1}' -f ($DateTime.ToString('yyyy-MM-dd')), ($DateTime.ToString('HH:mm:ss'))
                                    break
                                }
                                'Daily' {
                                    'Every {0} day at {1}' -f $as.AdditionalProperties.runSchedule.interval, ("$($as.AdditionalProperties.runSchedule.time)".Split('.')[0])
                                    break
                                }
                                'Hourly' {
                                    'Every {0} hour(s)' -f $as.AdditionalProperties.runSchedule.interval
                                    break
                                }
                                '' {
                                    'N/A'
                                }
                                Default {
                                    'Unknown [{0}]' -f $_
                                }
                            }
                        )

                        $Object.AssignmentType = $as.Action
                        [String]$Object.Target = $as.Target
                        $Object.FilterType = $as.FilterType
                        $Object.Filter = $as.Filter
                        $Object
                    }
                }
                else {
                    $Object.Status = 'Not deployed'
                    $Object
                }
            }
            else {
                $Object
            }
        }
    }
    end {}
}


function Invoke-IntuneHealthScriptDownload {
    <#
.SYNOPSIS
    Download Intune Health (remediation) scripts.

.DESCRIPTION
    Download Intune Health (remediation) scripts.

.PARAMETER displayName
    Name of the scripts.

.PARAMETER id
    Id of the scripts.

.PARAMETER Destination
    Download folder.

.EXAMPLE
Download every script in the IntuneScripts located in the current user's profile.

    PS C:\> Get-IntuneHealthScript | Invoke-IntuneHealthScriptDownload -Destination "$Env:userprofile\IntuneScripts"

.EXAMPLE
    PS C:\> Invoke-IntuneHealthScriptDownload -displayName 'WKS WIN Remediate WindowsUpdate', '' -Destination "$Env:userprofile\IntuneScripts"

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-10-06
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [Alias('Name')]
        [String[]]$displayName,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [String[]]$id,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ById')]
        [String]$Destination
    )

    begin {
        $InvocationName = $MyInvocation.InvocationName

        if (! (Test-Path -Path $Destination)) {
            $null = New-Item -Path $Destination -ItemType Directory -Force
        }
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            [String[]]$Id = Invoke-MgGraphRequestSingle -APIVersion 'beta' -Resource 'deviceManagement/deviceHealthScripts' -Filter ("displayName in ('{0}')" -f ($displayName -join "','")) -Select Id | Select-Object -ExpandProperty Id
        }

        $BatchResults = Invoke-MgGraphRequestBatch -APIVersion beta -Resource 'deviceManagement/deviceHealthScripts' -ObjectList $Id -Select 'id', 'displayName', 'detectionScriptContent', 'remediationScriptContent' -DoNotLogErrors
        foreach ($Result in $BatchResults) {
            if ($Result.Status -eq 200) {
                $Script = $Result.Body
                [String]$ScriptName = $Script.displayName
                [String]$ScriptFileName = $ScriptName.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                if (($script.detectionScriptContent).Length -ne 0) {
                    Write-Verbose -Message "[$InvocationName] Exporting [$ScriptName]'s detection script to [$Destination\${ScriptFileName}_Detect.ps1]"
                    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("$($script.detectionScriptContent)")).TrimStart('?') | Out-File -Encoding UTF8 -FilePath "$Destination\${ScriptFileName}_Detect.ps1" -Force
                }
                if (($script.remediationScriptContent).Length -ne 0) {
                    Write-Verbose -Message "[$InvocationName] Exporting [$ScriptName]'s remediation script to [$Destination\${ScriptFileName}_Remediate.ps1]"
                    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("$($script.remediationScriptContent)")).TrimStart('?') | Out-File -Encoding UTF8 -FilePath "$Destination\${ScriptFileName}_Remediate.ps1" -Force
                }
            }
            else {
                Write-Warning -Message "[$InvocationName] Failed to get script details for [$($Result.id)]"
            }
        }
    }
    end {}
}


function Get-IntunePlatformScript {
    <#
.SYNOPSIS
    Get the Intune platform scripts.

.DESCRIPTION
    Get the Intune platform scripts.

    The results contain the following properties depending on the parameters used:
        displayName            = Name of the script
        description            = Description of the script
        runAsAccount           = Is the script configured to run in the user context?
        enforceSignatureCheck  = Must the script be signed?
        runAs32Bit             = Must the script be launched in a 32bit PowerShell session or a 64bit one?
        AssignmentType         = Type of assignment (Include, Exclude)
        Target                 = Name of the target (All devices, All users, group name)
        FilterType             = Type of filter (Include, Exclude)
        Filter                 = Name of the filter
        deviceSuccess          = Number of devices that returned an exit code value of 0
        deviceError            = Number of devices that returned an exit code value of anything but 0
        userSuccess            = Number of users that returned an exit code value of 0
        userError              = Number of users that returned an exit code value of anything but 0
        createdDateTime        = Script creation date
        lastModifiedDateTime   = Script modification date
        roleScopeTagIds        = Scope tags linked to the script
        id                     = Id of the script

.PARAMETER displayName
    Name of the script.

.PARAMETER id
    id of the script.

.PARAMETER Assignment
    Add the assignments to the results.
    Multiple results can be returned for a single script if the number of included or excluded targets are assigned.

.PARAMETER RunSummary
    Add the execution statistics to the results.

.EXAMPLE
    PS C:\> Get-IntunePlatformScript

.EXAMPLE
    PS C:\>

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-03-09
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param (
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [String]$displayName,

        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Byid')]
        [String]$id,

        [Parameter(ParameterSetName = 'ByName')]
        [Parameter(ParameterSetName = 'Byid')]
        [switch]$Assignment,

        [Parameter(ParameterSetName = 'ByName')]
        [Parameter(ParameterSetName = 'Byid')]
        [switch]$RunSummary
    )

    begin {
        $InvocationName = $MyInvocation.InvocationName
        $RunSummaryPropertyList = @(
            @{Name = 'successDeviceCount'; Target = 'DeviceSuccess' },
            @{Name = 'errorDeviceCount'; Target = 'DeviceError' },
            @{Name = 'successUserCount'; Target = 'UserSuccess' },
            @{Name = 'errorUserCount'; Target = 'UserError' }
        )
        $ExcludePropertyList = New-Object -TypeName system.collections.ArrayList
        $SelectParams = @{} # Parameters used by Select-Object in order to exclude some properties depending on the Assignment and RunSummary parameters

        # Parameters used by Invoke-MgGraphRequestSingle to query the scripts
        $GRParams = @{
            APIVersion = 'beta'
            Resource   = 'deviceManagement/deviceManagementScripts'
            OrderBy    = 'displayName'
            Expand     = @()
        }

        if ($Assignment.isPresent -eq $true) {
            $GRParams.Expand += 'assignments'
        }
        else {
            $ExcludePropertyList.AddRange(@('status', 'Target', 'FilterType', 'Filter', 'AssignmentType'))
        }
        if ($RunSummary.isPresent -eq $true) {
            $GRParams.Expand += 'runSummary'
        }
        else {
            $ExcludePropertyList.AddRange(@($RunSummaryPropertyList.Target))
        }
        if ($GRParams.Expand.Count -eq 0) { $GRParams.Remove('Expand') }
        if ($ExcludePropertyList.Count -gt 0) {
            $SelectParams.Property = '*'
            $SelectParams.ExcludeProperty = $ExcludePropertyList
        }
        $RBACAuthorized = (Get-MgContext).Scopes -match 'DeviceManagementRBAC'
    }
    process {
        if ("$DisplayName".Trim() -ne '') {
            $GRParams.Filter = "startswith(displayName, '$displayname')"
        }
        elseif ("$id".Trim() -ne '') {
            $GRParams.Resource = 'deviceManagement/deviceManagementScripts/{0}' -f $id
        }
        $scriptList = Invoke-MgGraphRequestSingle @GRParams
        [String[]]$GroupIdList = $scriptList.assignments.target.groupid | Select-Object -Unique
        if ($GroupIdList.Count -gt 0) {
            $grouplist = Invoke-MgGraphRequestBatch -Resource 'groups' -Select 'displayname' -ObjectList $GroupIdList -DoNotLogErrors | Select-Object id, @{label = 'DisplayName'; Expression = { $_.body.displayName } }
        }
        if ($RBACAuthorized) {
            $ScopeTagList = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/roleScopeTags' -APIVersion 'beta' -EA Stop
        }
        else {
            Write-Warning -Message "[$InvocationName] Failed to get the scope tags due to missing permissions"
        }
        $FilterList = Invoke-MgGraphRequestSingle -Resource 'deviceManagement/assignmentFilters' -Select 'id', 'displayname' -APIVersion 'beta' -ErrorAction Continue
        <#
        #Too many throttled queries
        if ($RunSummary.IsPresent) {
            $BatchRunSummary = Invoke-MgGraphRequestBatch -APIVersion 'beta' -Resource 'deviceManagement/deviceManagementScripts' -ObjectList $ScriptList -Query 'runsummary' -WaitTime 3000 -MaxRetry 4 | Convert-PSObjectArrayToHashTable -idProperty id
        }
        #>
        foreach ($script in $scriptList) {
            if ($RBACAuthorized) {
                [String[]]$ScopeTags = $ScopeTagList | Where-Object -Property id -In $Script.roleScopeTagIds | Select-Object -ExpandProperty displayName
            }
            else {
                [String[]]$ScopeTags = $Script.roleScopeTagIds
            }
            $Object = [PSCustomObject]@{
                displayName           = $Script.displayName
                status                = 'Active'
                fileName              = $Script.fileName
                description           = $Script.description
                runAsAccount          = $Script.runAsAccount
                enforceSignatureCheck = $Script.enforceSignatureCheck
                runAs32Bit            = $Script.runAs32Bit
                AssignmentType        = ''
                Target                = ''
                FilterType            = ''
                Filter                = ''
                deviceSuccess         = 0
                deviceError           = 0
                userSuccess           = 0
                userError             = 0
                createdDateTime       = $Script.createdDateTime
                lastModifiedDateTime  = $Script.lastModifiedDateTime
                roleScopeTagIds       = $ScopeTags
                id                    = $Script.id
            } | Select-Object @SelectParams

            if ($RunSummary.IsPresent -eq $true) {
                $Item = $Script.runSummary
                if ($null -eq $Item) {
                    $Item = Invoke-MgGraphRequestSingle -APIVersion 'beta' -Resource ('deviceManagement/deviceManagementScripts/{0}/runsummary' -f $script.id)
                }
                foreach ($Property in $RunSummaryPropertyList) {
                    $Object."$($Property.Target)" = $Item."$($Property.Name)"
                }
            }
            if ($Assignment.IsPresent -eq $true) {
                if (($script.assignments | Measure-Object).Count -gt 0) {
                    $ConvertedTargetList = $script.assignments | ConvertFrom-IntuneAssignmentTarget -Groups $grouplist -Filters $FilterList
                    foreach ($as in $ConvertedTargetList) {
                        $Object.AssignmentType = $as.Action
                        [String]$Object.Target = $as.Target
                        $Object.FilterType = $as.FilterType
                        $Object.Filter = $as.Filter
                        $Object
                    }
                }
                else {
                    $Object.Status = 'Not deployed'
                    $Object
                }
            }
            else {
                $Object
            }
        }
    }
    end {}
}


function Invoke-IntunePlatformScriptDownload {
    <#
.SYNOPSIS
    Download Intune platform scripts.

.DESCRIPTION
    Download Intune platform scripts.

.PARAMETER displayName
    Name of the scripts.

.PARAMETER id
    Id of the scripts.

.PARAMETER Destination
    Download folder.

.EXAMPLE
Download every script in the IntuneScripts located in the current user's profile.

    PS C:\> Get-IntunePlatformScript | Invoke-IntunePlatformScriptDownload -Destination "$Env:userprofile\IntuneScripts"

.EXAMPLE
    PS C:\> Invoke-IntunePlatformScriptDownload -displayName 'WKS WIN WindowsUpdate', '' -Destination "$Env:userprofile\IntuneScripts"

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-03-09
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [Alias('Name')]
        [String[]]$displayName,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [String[]]$id,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ById')]
        [String]$Destination
    )

    begin {
        $InvocationName = $MyInvocation.InvocationName

        if (! (Test-Path -Path $Destination)) {
            $null = New-Item -Path $Destination -ItemType Directory -Force
        }
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            [String[]]$Id = Invoke-MgGraphRequestSingle -APIVersion 'beta' -Resource 'deviceManagement/deviceManagementScripts' -Filter ("displayName in ('{0}')" -f ($displayName -join "','")) -Select Id | Select-Object -ExpandProperty Id
        }

        $BatchResults = Invoke-MgGraphRequestBatch -APIVersion beta -Resource 'deviceManagement/deviceManagementScripts' -ObjectList $Id -Select 'id', 'fileName', 'displayName', 'scriptContent' -DoNotLogErrors
        foreach ($Result in $BatchResults) {
            if ($Result.Status -eq 200) {
                $Script = $Result.Body
                [String]$ScriptName = $Script.displayName
                [String]$ScriptFileName = $Script.fileName
                if (($script.scriptContent).Length -ne 0) {
                    $ScriptDestination = "$Destination\$ScriptFileName"
                    if (Test-Path -Path $ScriptDestination) {
                        [String]$ScriptFileName = "$($ScriptFileName.Replace('.ps1',''))_$($ScriptName.Split([IO.Path]::GetInvalidFileNameChars()) -join '_').ps1"
                        Write-Warning -Message "[$InvocationName] [$ScriptName] The script's destination already exists [$ScriptDestination] using the script's full name: [$ScriptFileName]"
                        $ScriptDestination = "$Destination\$ScriptFileName"
                    }
                    else {
                        Write-Verbose -Message "[$InvocationName] Exporting [$ScriptName]'s script to [$ScriptDestination]"
                    }
                    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("$($script.scriptContent)")).TrimStart([char]65279) | Out-File -Encoding UTF8 -FilePath $ScriptDestination -Force
                }
            }
            else {
                Write-Warning -Message "[$InvocationName] Failed to get script details for [$($Result.id)]"
            }
        }
    }
    end {}
}
#endregion Intune scripts


#region applications
function Invoke-IntuneWin32AppDownload {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [String]$id,

        [Parameter(Mandatory = $true, Position = 1)]
        [String]$Destination
    )

    begin {
        #$InvocationName = $MyInvocation.MyCommand.Name
    }
    process {
        $Resource = 'deviceAppManagement/mobileApps/{0}/microsoft.graph.mobileLobApp/contentVersions' -f $id
        $LatestContentVersion = Invoke-MgGraphRequestSingle -APIVersion beta -Resource $Resource -OrderBy 'id desc' | Select-Object -ExpandProperty id -First 1
        $FileList = Invoke-MgGraphRequestSingle -APIVersion beta -Resource ("$Resource/{0}/files" -f "$LatestContentVersion")
        $App = Invoke-MgGraphRequestSingle -APIVersion beta -Resource ('deviceAppManagement/mobileApps/{0}' -f $id)

        $AppFolder = "$Destination\$($App.displayName)"
        if (! (Test-Path -Path $AppFolder)) {
            $null = New-Item -Path $AppFolder -ItemType Directory -Force
        }
        foreach ($File in $FileList) {
            $azureStorageUri = Invoke-MgGraphRequestSingle -APIVersion beta -Resource ('$Resource/{0}/files/{1}?$select=azureStorageUri' -f "$LatestContentVersion",$File.id) | Select-Object -ExpandProperty azureStorageUri
            Invoke-RestMethod -Uri $azureStorageUri -Method 'GET' -OutFile "$AppFolder\$($File.name)"
        }
    }
}
#endregion applications
#endregion Intune


#region miscellaneous
function Convert-GraphErrorMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowNull()]
        [Object]$InputObject
    )

    process {
        if ($InputObject.body.error) {
            if ("$($InputObject.body.error.message)".IndexOf('{') -ge 0) {
                $JSONMessage = $InputObject.body.error.message | ConvertFrom-Json -EA Ignore
                [String]$ErrorCode = $JSONMessage.ErrorCode
                if ($ErrorCode -eq '') { $ErrorCode = $InputObject.body.error.code }
                [String]$Message = $JSONMessage.Message
                if ("$($JSONMessage.Message)".IndexOf('{') -ge 0) {
                    $Message = ($JSONMessage.Message | ConvertFrom-Json -EA Ignore).Message
                }
                [String]$Target = $JSONMessage.Target
                [String]$Details = $JSONMessage.Details
            }
            else {
                $Message = $InputObject.body.error.message
                $ErrorCode = $InputObject.body.error.code
            }

            [PSCustomObject]@{
                statusCode = [String]$InputObject.status
                codeName   = [String]$InputObject.body.error.code
                message    = [String]$Message
                ErrorCode  = [String]$ErrorCode
                Target     = [String]$Target
                Details    = [String]$Details
            }
        }
    }
}


function Convert-PSObjectArrayToHashTable {
    <#
.SYNOPSIS
    Convert a PSObject array to an hashtable.

.DESCRIPTION
    Convert a PSObject array to an hashtable.

    Uses an id property to define the key in the hashtable and adds the other properties as the value.
    If the id property is not unique in the array of objects, use the -AllowClobber to set an array of values for the specific key.
    Otherwise only the last item will be set as the value.

.PARAMETER InputObject
    PSObject array to be converted to hashtable.

.PARAMETER idProperty
    Name of the property to be used as the hashtable key.

.PARAMETER Property
    Properties to be kept in the value.

.PARAMETER AllowClobber
    Allow for multiple values to be added for a single key.

.EXAMPLE
    PS C:\> Invoke-MgGraphRequestSingle -Resource 'devices' -Select id,displayName,OperatingSystem,deviceid | Convert-PSObjectArrayToHashTable -idProperty id -Property displayName,operatingsystem

.EXAMPLE
    PS C:\> Get-Service | Convert-PSObjectArrayToHashTable -idProperty status -AllowClobber

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-01-21
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK

#>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('PSObjectArray')]
        [PSObject[]]$InputObject,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$idProperty,

        [Parameter(Mandatory = $false, Position = 2)]
        [String[]]$Property,

        [Switch]$AllowClobber
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        # Initialize the hashtable
        $HashTable = @{}
        $SOParams = @{
            Property = $Property
        }
        if ($Property -notcontains $idProperty) {
            $SOParams.ExcludeProperty = $idProperty
        }
    }
    process {
        foreach ($PSObject in $InputObject) {
            Remove-Variable -Name 'CurrentValue', 'Object', 'CurrentProperties' -Force -ErrorAction Ignore
            try {
                # Retrieve the value of the specified property
                $IdValue = $PSObject.$idProperty
                if ($null -ne $IdValue) {
                    $CurrentValue = $HashTable["$IdValue"]
                    $Object = $PSObject
                    [String[]]$CurrentProperties = $Object.psobject.members |
                        Where-Object -Property MemberType -In ('Property', 'NoteProperty') |
                        Select-Object -ExpandProperty Name |
                        Where-Object { $_ -notin ('PSProvider', 'PSDrive', 'PSChildName', 'PSParentPath', 'PSPath') }

                    if (($Property.Count -eq 1) -and ($Property -ne '*')) {
                        $Object = $PSObject.$Property
                    }
                    elseif ($CurrentProperties.Count -eq 2) {
                        # Only 2 properties, including the id one, so we only keep the remaining one
                        $Property = $CurrentProperties | Where-Object { $_ -ne "$IdProperty" } | Select-Object -First 1
                        $Object = $PSObject.$Property
                    }
                    elseif ($Property.Count -gt 1) {
                        $Object = $PSObject | Select-Object @SOParams
                    }

                    if (($null -eq $CurrentValue) -and ($AllowClobber.IsPresent)) {
                        $HashTable["$IdValue"] = New-Object -TypeName System.Collections.ArrayList
                    }
                    elseif (($null -ne $CurrentValue) -and ($AllowClobber.IsPresent -eq $false) -and ($Object -ne $CurrentValue)) {
                        Write-Warning -Message "[$InvocationName] The key [$IdValue] already exists with value [$($CurrentValue | Out-String)]. Use the AllowClobber parameter to add another value to the key."
                        continue
                    }

                    # Add the object to the hashtable
                    if ($AllowClobber.IsPresent) {
                        $null = $HashTable["$IdValue"].Add($Object)
                    }
                    else {
                        $HashTable["$IdValue"] = $Object
                    }
                }
                else {
                    Write-Warning "[$InvocationName] Object does not have a valid '$idProperty' property. Skipping: $($PSObject | ConvertTo-Json -Compress -Depth 15)"
                }
            }
            catch {
                Write-Warning "[$InvocationName] Failed to process object: $($PSObject | ConvertTo-Json -Compress -Depth 15). Error: $($_.Exception.Message)"
            }
        }
    }
    end {
        # End function and report memory usage
        $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($true) / 1MB), 2)
        Write-Verbose "[$InvocationName] Function finished. Memory usage: $MemoryUsage MB"
        # Return the constructed hashtable
        return $HashTable
    }
}


function Send-GraphMail {
    <#
.SYNOPSIS
    Send an email using Microsoft Graph.

.DESCRIPTION
    Send an email using Microsoft Graph.

.PARAMETER Subject
    Subject of the email.

.PARAMETER Message
    Body of the message.
    Can be plain text or html (use -AsHtml in that case).

.PARAMETER from
    Sender of the email.
    By default, the authenticated user/app is used.

.PARAMETER To
    List of recipients (email address).

.PARAMETER Cc
    List of the cc recipients (email address).

.PARAMETER Bcc
    List of the bcc recipients (email address).

.PARAMETER Attachment
    List of files to be attached to the email.

.PARAMETER Importance
    Priority flag.

.PARAMETER AsHtml
    Tells the function that the Message parameter is an html formated text.

.PARAMETER SaveToSentItems
    Saves the email to the sent items in the sender's mailbox.

.EXAMPLE
    PS C:\>

.EXAMPLE
    PS C:\>

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2025-10-27
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK
    https://learn.microsoft.com/en-us/graph/api/user-sendmail?view=graph-rest-1.0&tabs=http
    https://learn.microsoft.com/en-us/graph/outlook-things-to-know-about-send-mail

#>



    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$Subject,

        [Parameter(Mandatory = $true, Position = 1)]
        [String]$Message,

        [Parameter(Position = 2)]
        [String]$from = 'me',

        [Parameter(Mandatory = $true, Position = 3, ValueFromPipelineByPropertyName = $true)]
        [Alias('mail')]
        [String[]]$To,

        [Parameter(Position = 4)]
        [String[]]$Cc,

        [Parameter(Position = 5)]
        [String[]]$Bcc,

        [Parameter(Position = 6)]
        [ValidateScript({
                if ($Missing = $_ | Where-Object { ! (Test-Path -Path $_) }) {
                    throw "The following attachement does not exist: $($Missing -join ', ')"
                }
                else { $true }
            })]
        [String[]]$Attachment,

        [Parameter(Position = 7)]
        [ValidateSet('low', 'normal', 'high')]
        [String]$Importance = 'normal',

        [switch]$AsHtml,

        [switch]$SaveToSentItems
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name

        $ContentType = 'text'
        if ($AsHtml.IsPresent) {
            $ContentType = 'HTML'
        }

        $MailSender = 'me'
        if ($from -ne 'me') {
            [String]$senderid = Invoke-MgGraphRequestSingle -Resource 'users' -Filter "mail eq '$from'" -Select id | Select-Object -ExpandProperty id
            if ("$senderId" -eq '') {
                throw "[$InvocationName] Could not find user using mail [$from]"
            }
            $MailSender = 'users/{0}' -f $senderid
        }
    }
    process {
        $ToRecipients = $(
            foreach ($Address in $To) {
                @{EmailAddress = @{Address = $Address } }
            }
        )
        $params = @{
            Message         = @{
                Subject      = $Subject
                Body         = @{
                    ContentType = $ContentType
                    Content     = $Message
                }
                ToRecipients = @($ToRecipients)
                Importance   = $Importance
            }
            SaveToSentItems = $SaveToSentItems.IsPresent
        }

        if ($Attachment.Count -gt 0) {
            # Convert the attachements to base64 and add them to the parameters
            $params.Message.Attachments = @(
                $(
                    foreach ($a in $Attachment) {
                        try {
                            $File = Get-Item -Path $a -EA Stop
                            @{
                                '@odata.type' = '#microsoft.graph.fileAttachment'
                                Name          = $File.Name
                                ContentType   = 'text/plain'
                                ContentBytes  = [Convert]::ToBase64String([IO.File]::ReadAllBytes($a))
                            }
                        }
                        catch {
                            throw "[$InvocationName] Could not fetch the attachement [$a]"
                        }
                    }
                )
            )
        }
        # Add cc and bcc recipients
        if ($Cc.Count -gt 0) {
            $params.Message.ccRecipients = @(
                $(
                    foreach ($Address in $Cc) {
                        @{EmailAddress = @{Address = $Address } }
                    }
                )
            )
        }
        if ($Bcc.Count -gt 0) {
            $params.Message.BccRecipients = @(
                $(
                    foreach ($Address in $Bcc) {
                        @{EmailAddress = @{Address = $Address } }
                    }
                )
            )
        }

        Invoke-MgGraphRequestSingle -Resource "$MailSender/sendMail" -Method 'POST' -Body $Params
    }
    end {

    }
}
#endregion miscellaneous


#region LogAnalytics
function Invoke-LogAnalyticsQuery {
    <#
.SYNOPSIS
    Run a Log Analytics Query and retrieve the output.

.DESCRIPTION
    Run a Log Analytics Query (Kusto) and retrieve the output.

.PARAMETER tenantID
    ID of the tenant.

.PARAMETER subscriptionID
    ID of the subscription where the Log Analytics workspace is located.

.PARAMETER ResourceGroupName
    Name of the resource group hosting the Log Analytics workspace.

.PARAMETER workspaceName
    Name of the Log Analytics workspace.

.PARAMETER query
    Kusto query

.EXAMPLE
    PS C:\> $kqlQuery = "
set notruncation; // Do not trunc the results
workspace('/subscriptions/$subscriptionIDEntraId/resourcegroups/$ResourceGroupNameEntraId/providers/microsoft.operationalinsights/workspaces/$workspaceNameEntraId').SigninLogs
| where TimeGenerated >= ago($($SignInsTimeSpan)d)
| extend DeviceName = tostring(DeviceDetail.displayName),AzureADDeviceID = tostring(DeviceDetail.deviceId)
| summarize LastSeen = max(TimeGenerated) by DeviceName,AzureADDeviceID
" -creplace '(?m)^\s*\r?\n' # Trim any blank lines where the exclusion variables are empty

    PS C:\> Invoke-LogAnalyticsQuery tenantID $TenantId -subscriptionID $subscriptionIDEntraId -ResourceGroupName $ResourceGroupNameEntraId -workspaceName $workspaceNameEntraId -query $kqlQuery

.NOTES

#>


    [cmdletbinding()]
    [Alias('laq')]
    param (
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$tenantID,

        [parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$subscriptionID,

        [parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [parameter(Mandatory = $true, Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string]$workspaceName,

        [parameter(Mandatory = $true, Position = 4)]
        [ValidateNotNullOrEmpty()]
        [Alias('KQLQuery')]
        [string]$query
    )

    if ($Global:PSDefaultParameterValues.Keys.Count -gt 0) {
        $PSDefaultParameterValues = $Global:PSDefaultParameterValues.Clone()
    }
    else {
        $PSDefaultParameterValues.Clear()
    }

    $InvocationName = $MyInvocation.MyCommand.Name

    try {
        $RestoreAzContext = $false
        $AzContext = Get-AzContext
        if (($AzContext.Tenant.id -ne $TenantId) -or ($AzContext.Subscription.id -ne $subscriptionID)) {
            $RestoreAzContext = $true
            $null = Set-AzContext -Tenant $tenantID -Subscription $subscriptionID
            Write-Log -Message ('[{0}] Set the context to TenantId [{1}], subscriptionID [{2}]' -f $InvocationName, $TenantId, $SubscriptionId)
        }
        $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $workspaceName
        Write-Log -Message ('[{0}] Workspace used: {1}' -f $InvocationName, ($Workspace | ConvertTo-Json))
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Log -Message ('[{0}] failed to get the workspace [{1}] in [{2}]' -f $InvocationName, $workspaceName, $ResourceGroupName)
        throw "$ErrorMessage"
    }
    try {
        Write-Log -Message "[$InvocationName] Executing the following query: `r`n$Query"
        $QueryResult = Invoke-AzOperationalInsightsQuery -Workspace $workspace -Query $query -ErrorAction Stop
        if ($null -ne $QueryResult.Error) {
            Write-Log -Message "[$InvocationName] The query resulted in an error: $($QueryResult.Error | ConvertTo-Json -Compress)" -Type Warning
        }
        Write-Log -Message "[$InvocationName] The query returned $(($QueryResult.Results | Measure-Object).Count) results"
        $QueryResult.Results
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Log -Message ('[{0}] Invoke-AzOperationalInsightsQuery failed' -f $InvocationName)
        throw "$ErrorMessage"
    }
    if ($RestoreAzContext -eq $true) {
        try {
            $null = Set-AzContext -Tenant $AzContext.Tenant -Subscription $AzContext.Subscription -EA Stop
            Write-Log -Message ('[{0}] Restored the context to TenantId [{1}], subscriptionID [{2}]' -f $InvocationName, $AzContext.Tenant, $AzContext.Subscription)
        }
        catch {
            Write-Log -Message ('[{0}] Failed to restore the context to TenantId [{1}], subscriptionID [{2}]' -f $InvocationName, $AzContext.Tenant, $AzContext.Subscription)
        }
    }
}


# Function to send data to log analytics
function Send-LogAnalyticsData {
    <#
.SYNOPSIS
    Send log data to Azure Monitor by using the HTTP Data Collector API

.DESCRIPTION
    Send log data to Azure Monitor by using the HTTP Data Collector API

.PARAMETER sharedKey
    Shared key used for authentication.

.PARAMETER body
    Payload to send to Log Analytics formated as a json.

.PARAMETER logType
    Name of the subimitted message.

    Can only contains alpha characters (no numerical or special characters)

.PARAMETER WorkspaceId
    Log Analytics workspace ID.

.NOTES
    Author:      Jan Ketil Skanke
    Contact:     @JankeSkanke
    Created:     2022-01-14
    Updated:     2022-01-14

    Version history:
    1.0.0 - (2022-01-14) Function created

.EXAMPLE
Send-LogAnalyticsData -WorkspaceId $WorkspaceId -sharedKey $sharedKey -body $jsonPayload -logType $logAnalyticsLogName

.LINK
    https://learn.microsoft.com/en-us/rest/api/loganalytics/create-request
   #>


    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$sharedKey,

        [Parameter(Mandatory = $true, Position = 2)]
        [array]$body,

        [Parameter(Mandatory = $true, Position = 3)]
        [ValidateScript({
                if ("$_" -match '^[A-Za-z]+$') {
                    $true
                }
                else { throw 'Log-Type only supports alpha characters (no numeric or special characters)' }
            })]
        [string]$logType,

        [Parameter(Mandatory = $true, Position = 4)]
        [Alias('customerId')]
        [string]$WorkspaceId
    )

    if ($Global:PSDefaultParameterValues.Keys.Count -gt 0) {
        $PSDefaultParameterValues = $Global:PSDefaultParameterValues.Clone()
    }
    else {
        $PSDefaultParameterValues.Clear()
    }

    $InvocationName = $MyInvocation.MyCommand.Name

    #Defining method and datatypes
    [String]$APIVersion = '2016-04-01'
    $method = 'POST'
    $contentType = 'application/json'
    $resource = '/api/logs'
    $UTCNow = [DateTime]::UtcNow
    $TimeStampField = "$($UTCNow.ToString('s'))Z"
    $xmsdate = $UTCNow.ToString('r')
    $BytesArray = ([System.Text.Encoding]::UTF8.GetBytes($Body))
    $contentLength = $BytesArray.Length

    #Construct authorization signature
    $xHeaders = 'x-ms-date:' + $xmsdate
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)
    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $signature = 'SharedKey {0}:{1}' -f $WorkspaceId, $encodedHash

    #Construct uri
    $uri = 'https://{0}.ods.opinsights.azure.com/{1}?api-version={2}' -f $WorkspaceId, "$resource".TrimStart('/'), $APIVersion

    #validate that payload data does not exceed limits
    if ($contentLength -gt 31.9MB) {
        throw ('Upload payload is too big and exceed the 32Mb limit for a single upload. Please reduce the payload size. Current payload size is: ' + ($contentLength / 1MB).ToString('#.#') + 'Mb')
    }
    $payloadsize = ('Upload payload size is ' + ($contentLength / 1KB).ToString('#.#') + 'Kb ')

    #Create authorization Header
    $headers = @{
        'Authorization'        = $signature
        'Log-Type'             = $logType
        'x-ms-date'            = $xmsdate
        'time-generated-field' = $TimeStampField
    }
    #Sending data to log analytics
    Write-Log -Message ('[{0}] Sending data to log analytics.' -f $InvocationName)
    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $BytesArray -UseBasicParsing
    $statusmessage = "$($response.StatusCode) : $($payloadsize)"

    #Report back status
    $Result = [PSCustomObject]@{
        Date        = $UTCNow
        StatusCode  = $response.StatusCode
        PayloadSize = $contentLength
        LogType     = $logType
        Status      = 'Success'
    }

    $OutputMessage = "[$InvocationName] Date: $(Get-Date -Format 'dd-MM HH:mm') $logType"

    if ($statusmessage -match '200 :') {
        $OutputMessage = "$OutPutMessage => Success, $statusmessage"
    }
    else {
        $Result.Status = 'Failure'
        $OutputMessage = "$OutPutMessage => Failure, $statusmessage"
    }

    Write-Log -Message $OutputMessage
    return $Result
}
#endregion LogAnalytics


#region SharePoint
function Invoke-SPFileDownload {
    <#
.SYNOPSIS
    Download files from a SharePoint site.

.DESCRIPTION
    Download files from a SharePoint site.

.PARAMETER SiteName
    Name of the SharePoint site.

.PARAMETER SiteId
    Id of the SharePoint site.

.PARAMETER DriveName
    Name of the SharePoint drive.

.PARAMETER DriveId
    Id of the SharePoint drive.

.PARAMETER Directory
    SharePoint directory path.

.PARAMETER parentItemId
    SharePoint directory id.

.PARAMETER Name
    SharePoint file name.

.PARAMETER Search
    Search pattern used to find a file in the drive.

.PARAMETER ExactMatch
    The search method matches all files which name contains the specified pattern by default.
    Use this switch to tell the function to look for the file matching the exact pattern.

.PARAMETER Destination
    Folder where the file(s) will be downloaded.

.EXAMPLE
Download a single file named test.txt from the Documents drive of the MySPSite site in the folder "SharePoint\Folder with spaces" to C:\Temp
    PS C:\> Invoke-SPFileDownload -SiteName 'MySPSite' -DriveName 'Documents' -Directory 'SharePoint\Folder with spaces' -Name 'test.txt' -Destination 'C:\temp'

.EXAMPLE
Download multiple files from the Documents drive of the MySPSite site in the folder "SharePoint\Folder with spaces" to C:\Temp
    PS C:\> Invoke-SPFileDownload -SiteName 'MySPSite' -DriveName 'Documents' -Directory 'SharePoint\Folder with spaces' -Name 'test.txt','services.csv' -Destination 'C:\temp'

.EXAMPLE
Search and download a file from a SharePoint drive.

Download all the files matching "test.txt" (Ex: "File test.txt","test.txt")
    PS C:\> Invoke-SPFileDownload -SiteName 'MySPSite' -DriveName 'Documents' -Search 'test.txt' -Destination 'C:\temp'

Download only the file which name equals "test.txt"
    PS C:\> Invoke-SPFileDownload -SiteName 'MySPSite' -DriveName 'Documents' -Search 'test.txt' -ExactMatch -Destination 'C:\temp'

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-05-13
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'SiteName-FileName-DriveName-Directory')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-FileName-DriveName-Directory')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-FileName-DriveName-FolderId')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-FileName-DriveId-Directory')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-FileName-DriveId-FolderId')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-Pattern-DriveName')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-Pattern-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$SiteName,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-FileName-DriveName-Directory')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-FileName-DriveName-FolderId')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-FileName-DriveId-Directory')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-FileName-DriveId-FolderId')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-Pattern-DriveName')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-Pattern-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$SiteId,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-FileName-DriveName-Directory')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-FileName-DriveName-FolderId')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-Pattern-DriveName')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-FileName-DriveName-Directory')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-FileName-DriveName-FolderId')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-Pattern-DriveName')]
        [ValidateNotNullOrEmpty()]
        [String]$DriveName,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-FileName-DriveId-Directory')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-FileName-DriveId-FolderId')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-Pattern-DriveId')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-FileName-DriveId-Directory')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-FileName-DriveId-FolderId')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-Pattern-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$DriveId,

        [Parameter(Position = 2, ParameterSetName = 'SiteName-FileName-DriveName-Directory')]
        [Parameter(Position = 2, ParameterSetName = 'SiteName-FileName-DriveId-Directory')]
        [Parameter(Position = 2, ParameterSetName = 'SiteId-FileName-DriveName-Directory')]
        [Parameter(Position = 2, ParameterSetName = 'SiteId-FileName-DriveId-Directory')]
        [AllowEmptyString()]
        [String]$Directory,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-FileName-DriveName-FolderId')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-FileName-DriveId-FolderId')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-FileName-DriveName-FolderId')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-FileName-DriveId-FolderId')]
        [ValidateNotNullOrEmpty()]
        [String]$parentItemId,

        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'SiteName-FileName-DriveName-Directory', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'SiteName-FileName-DriveName-FolderId', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'SiteName-FileName-DriveId-Directory', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'SiteName-FileName-DriveId-FolderId', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'SiteId-FileName-DriveName-Directory', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'SiteId-FileName-DriveName-FolderId', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'SiteId-FileName-DriveId-Directory', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'SiteId-FileName-DriveId-FolderId', ValueFromPipelineByPropertyName = $true)]
        [String[]]$Name,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-Pattern-DriveName', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-Pattern-DriveId', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-Pattern-DriveName', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-Pattern-DriveId', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Search,

        [Parameter(ParameterSetName = 'SiteName-Pattern-DriveName')]
        [Parameter(ParameterSetName = 'SiteName-Pattern-DriveId')]
        [Parameter(ParameterSetName = 'SiteId-Pattern-DriveName')]
        [Parameter(ParameterSetName = 'SiteId-Pattern-DriveId')]
        [Switch]$ExactMatch,

        [Parameter(Mandatory = $true, Position = 4, ParameterSetName = 'SiteName-FileName-DriveName-Directory')]
        [Parameter(Mandatory = $true, Position = 4, ParameterSetName = 'SiteName-FileName-DriveName-FolderId')]
        [Parameter(Mandatory = $true, Position = 4, ParameterSetName = 'SiteName-FileName-DriveId-Directory')]
        [Parameter(Mandatory = $true, Position = 4, ParameterSetName = 'SiteName-FileName-DriveId-FolderId')]
        [Parameter(Mandatory = $true, Position = 4, ParameterSetName = 'SiteName-Pattern-DriveName')]
        [Parameter(Mandatory = $true, Position = 4, ParameterSetName = 'SiteName-Pattern-DriveId')]
        [Parameter(Mandatory = $true, Position = 4, ParameterSetName = 'SiteId-FileName-DriveName-Directory')]
        [Parameter(Mandatory = $true, Position = 4, ParameterSetName = 'SiteId-FileName-DriveName-FolderId')]
        [Parameter(Mandatory = $true, Position = 4, ParameterSetName = 'SiteId-FileName-DriveId-Directory')]
        [Parameter(Mandatory = $true, Position = 4, ParameterSetName = 'SiteId-FileName-DriveId-FolderId')]
        [Parameter(Mandatory = $true, Position = 4, ParameterSetName = 'SiteId-Pattern-DriveName')]
        [Parameter(Mandatory = $true, Position = 4, ParameterSetName = 'SiteId-Pattern-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$Destination
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        if ("$SiteId".Trim() -eq '') {
            Write-Verbose -Message "[$InvocationName] Looking for a site named [$SiteName]"
            [String]$SiteId = Invoke-MgGraphRequestSingle -Resource 'sites' -Search $SiteName -Select Name,id | Where-Object -Property Name -EQ $SiteName | Select-Object -ExpandProperty Id
        }
        Write-Verbose -Message "[$InvocationName] SiteId: $SiteId"
        if ("$DriveId".Trim() -eq '') {
            Write-Verbose -Message "[$InvocationName] Looking for a drive named [$DriveName]"
            [String]$DriveId = Invoke-MgGraphRequestSingle -Resource ('sites/{0}/drives' -f $SiteId) -Select Name,id | Where-Object -Property Name -EQ $DriveName | Select-Object -ExpandProperty id
        }
        Write-Verbose -Message "[$InvocationName] DriveId: $DriveId"
    }
    process {
        if ("$Search".Trim() -ne '') {
            Write-Verbose -Message "[$InvocationName] Searching for [$Search] in the drive"
            $Resource = 'sites/{0}/drives/{1}/root/search(q=''{2}'')' -f $SiteId, $DriveId, $Search
            $FileInfo = Invoke-MgGraphRequestSingle -Resource $Resource
            if ($ExactMatch.IsPresent) {
                $FileInfo = $FileInfo | Where-Object -Property Name -EQ $Search
            }
        }
        else {
            if ($PSCmdlet.ParameterSetName -like '*-Directory') {
                [String]$Directory = "$Directory".Replace('\','/')
                $FolderInfoDL = Test-SPFolder -Directory $Directory -SiteId $SiteId -DriveId $DriveId -PassThru -ChildProperty ('id','name') -Property ('id','name')
                $parentItemId = $FolderInfoDL.id
            }
            else {
                $FolderInfoDL = Test-SPFolder -Id $parentItemId -SiteId $SiteId -DriveId $DriveId -PassThru -ChildProperty ('id','name') -Property ('id','name')
            }
            if ($null -eq $FolderInfoDL) {
                throw "Failed to find [$parentItemId]"
            }

            $FileInfo = $(
                foreach ($Item in $Name) {
                    [String]$ItemId = $FolderInfoDL.children | Where-Object -Property Name -EQ $Item | Select-Object -ExpandProperty id
                    if ("$ItemId" -ne '') {
                        $Resource = 'sites/{0}/drives/{1}/items/{2}' -f $SiteId, $DriveId, $ItemId
                        Invoke-MgGraphRequestSingle -Resource $Resource -EA Stop
                    }
                    else {
                        Write-Warning -Message "[$InvocationName] Failed to find the file [$FullFilePath]: $($_.Exception.Message)"
                        $Error.Clear()
                    }
                }
            )
        }
        Write-Verbose -Message "[$InvocationName] Found $(($FileInfo | Measure-Object).Count) file(s)"

        $FileInfo # Output the files' information

        foreach ($File in $FileInfo) {
            [String]$Name = $File.Name
            #https://learn.microsoft.com/en-us/graph/api/driveitem-get-contentstream?view=graph-rest-beta&tabs=http
            Write-Verbose -Message "[$InvocationName] Downloading [$Name] ($($File.Id)) to [$Destination]"
            $Resource = 'sites/{0}/drives/{1}/items/{2}/contentStream' -f $SiteId, $DriveId, $File.id
            #$Resource = 'sites/{0}/drives/{1}/root:/{2}:/content' -f $SiteId, $DriveId, $FullFilePath # Deprecated
            Invoke-MgGraphRequestSingle -Resource $Resource -OutputFilePath "$Destination\$Name"
            if (! (Test-Path -LiteralPath "$Destination\$Name")) {
                Write-Warning -Message "[$InvocationName] Could not find the downloaded file [$Destination\$Name]"
            }
        }

        $FileInfo = $null
        $FolderInfoDL = $null
        # End function/script and report memory usage, before and after cleaning it up
        $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
        $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
        Write-Verbose -Message "[$InvocationName] Function finished. Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)"
    }
    end {}
}


function Invoke-SPFileUpload {
    <#
.SYNOPSIS
    Upload files to a SharePoint site.

.DESCRIPTION
    Upload files to a SharePoint site.

.PARAMETER SiteName
    Name of the SharePoint site.

.PARAMETER SiteId
    Id of the SharePoint site.

.PARAMETER DriveName
    Name of the SharePoint drive.

.PARAMETER DriveId
    Id of the SharePoint drive.

.PARAMETER Directory
    SharePoint directory path.

.PARAMETER parentItemId
    SharePoint directory id.

.PARAMETER Path
    Path of the file to be uploaded.

.PARAMETER ContentType
    Type of content to be uploaded.

.PARAMETER UploadSession
    Use an upload session for stability and performance.
    An upload session allows the app to upload ranges of the file in sequential API requests.
    It also enables the transfer to resume if the connection is dropped during the upload.

.EXAMPLE
Upload a single file to the Documents drive of the MySPSite site in the folder "Path\Of destination"
    PS C:\> Invoke-SPFileUpload -Path 'C:\temp\test.txt' -SiteName 'MySPSite' -DriveName 'Documents' -Directory 'Path\Of destination'

.EXAMPLE
Upload all the Excel files in C:\temp to the Documents drive of the MySPSite site in the folder "Path\Of destination" using an upload session
    PS C:\> Get-ChildItem -Path 'C:\temp' -Filter '*.xlsx' | Invoke-SPFileUpload -SiteName 'MySPSite' -DriveName 'Documents' -Directory 'Path\Of destination' -UploadSession

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-05-13
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'SiteName-Directory-DriveName')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-Directory-DriveName', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-Directory-DriveId', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-ParentId-DriveName', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-ParentId-DriveId', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-Directory-DriveName', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-Directory-DriveId', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-ParentId-DriveName', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-ParentId-DriveId', ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [ValidateScript({
                if ($Missing = $_ | Where-Object { ! (Test-Path -LiteralPath "$_") -or ((Get-Item -LiteralPath "$_").Length -le 0) }) {
                    throw "The following file does not exist: $($Missing -join ', ')"
                }
                else { $true }
            })]
        [Alias('FullName')]
        [String[]]$Path,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-Directory-DriveName')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-Directory-DriveId')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-ParentId-DriveName')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-ParentId-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$SiteName,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-Directory-DriveName')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-Directory-DriveId')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-ParentId-DriveName')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-ParentId-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$SiteId,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-Directory-DriveName')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-ParentId-DriveName')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-Directory-DriveName')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-ParentId-DriveName')]
        [ValidateNotNullOrEmpty()]
        [String]$DriveName,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-Directory-DriveId')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-ParentId-DriveId')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-Directory-DriveId')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-ParentId-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$DriveId,

        [Parameter(Position = 3, ParameterSetName = 'SiteName-Directory-DriveName')]
        [Parameter(Position = 3, ParameterSetName = 'SiteName-Directory-DriveId')]
        [Parameter(Position = 3, ParameterSetName = 'SiteId-Directory-DriveName')]
        [Parameter(Position = 3, ParameterSetName = 'SiteId-Directory-DriveId')]
        [AllowEmptyString()]
        [String]$Directory,

        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'SiteName-ParentId-DriveName')]
        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'SiteName-ParentId-DriveId')]
        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'SiteId-ParentId-DriveName')]
        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'SiteId-ParentId-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$parentItemId,

        [Parameter(Position = 4, ParameterSetName = 'SiteName-Directory-DriveName')]
        [Parameter(Position = 4, ParameterSetName = 'SiteName-Directory-DriveId')]
        [Parameter(Position = 4, ParameterSetName = 'SiteName-ParentId-DriveName')]
        [Parameter(Position = 4, ParameterSetName = 'SiteName-ParentId-DriveId')]
        [Parameter(Position = 4, ParameterSetName = 'SiteId-Directory-DriveName')]
        [Parameter(Position = 4, ParameterSetName = 'SiteId-Directory-DriveId')]
        [Parameter(Position = 4, ParameterSetName = 'SiteId-ParentId-DriveName')]
        [Parameter(Position = 4, ParameterSetName = 'SiteId-ParentId-DriveId')]
        [Switch]$UploadSession,

        [Parameter(ParameterSetName = 'SiteName-Directory-DriveName')]
        [Parameter(ParameterSetName = 'SiteName-Directory-DriveId')]
        [Parameter(ParameterSetName = 'SiteName-ParentId-DriveName')]
        [Parameter(ParameterSetName = 'SiteName-ParentId-DriveId')]
        [Parameter(ParameterSetName = 'SiteId-Directory-DriveName')]
        [Parameter(ParameterSetName = 'SiteId-Directory-DriveId')]
        [Parameter(ParameterSetName = 'SiteId-ParentId-DriveName')]
        [Parameter(ParameterSetName = 'SiteId-ParentId-DriveId')]
        [Switch]$Force
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        if ("$SiteId".Trim() -eq '') {
            Write-Verbose -Message "[$InvocationName] Looking for a site named [$SiteName]"
            [String]$SiteId = Invoke-MgGraphRequestSingle -Resource 'sites' -Search $SiteName -Select Name,id | Where-Object -Property Name -EQ $SiteName | Select-Object -ExpandProperty Id
        }
        Write-Verbose -Message "[$InvocationName] SiteId: $SiteId"
        if ("$DriveId".Trim() -eq '') {
            Write-Verbose -Message "[$InvocationName] Looking for a drive named [$DriveName]"
            [String]$DriveId = Invoke-MgGraphRequestSingle -Resource ('sites/{0}/drives' -f $SiteId) -Select Name,id | Where-Object -Property Name -EQ $DriveName | Select-Object -ExpandProperty id
        }
        Write-Verbose -Message "[$InvocationName] DriveId: $DriveId"

        if ($PSCmdlet.ParameterSetName -like '*-Directory-*') {
            [String]$Directory = "$Directory".Replace('\','/')
            if ($Force.IsPresent) {
                $FolderInfoUP = New-SPFolder -Directory $Directory -SiteId $SiteId -DriveId $DriveId
            }
            else {
                $FolderInfoUP = Test-SPFolder -Directory $Directory -SiteId $SiteId -DriveId $DriveId -PassThru -ChildProperty ('id','name')
            }
            if ($null -eq $FolderInfoUP) {
                throw "Failed to find [$Directory]"
            }
        }
        else {
            $FolderInfoUP = Test-SPFolder -Id $parentItemId -SiteId $SiteId -DriveId $DriveId -PassThru -ChildProperty ('id','name')
            if ($null -eq $FolderInfoUP) {
                throw "Failed to find [$parentItemId]"
            }
        }
    }
    process {
        foreach ($PathItem in $Path) {
            [byte[]]$fileBytes = [System.IO.File]::ReadAllBytes($PathItem)
            [int]$FileSize = $fileBytes.Length

            [String]$Name = Split-Path -Path $PathItem -Leaf
            [String]$FullFilePath = "${Directory}:/$Name" -replace '\s','%20'
            Write-Verbose -Message "[$InvocationName] Uploading [$PathItem] to [$FullFilePath] (FolderId [$($FolderInfoUP.id)], Size [$FileSize], SiteId [$SiteId], DriveId [$SPDriveId])"

            $FileInfo = $FolderInfoUP.children | Where-Object -Property Name -EQ $Name
            #https://learn.microsoft.com/en-us/graph/api/driveitem-put-content?view=graph-rest-beta&tabs=http
            if ($null -eq $FileInfo) {
                Write-Verbose -Message "[$InvocationName] Creating the missing file"
                $Resource = '/drives/{0}/items/{1}:/{2}:' -f $DriveId, $FolderInfoUP.id, $Name # Upload new
            }
            else {
                Write-Verbose -Message "[$InvocationName] Replacing an existing file"
                $Resource = '/drives/{0}/items/{1}' -f $DriveId, $FileInfo.id # Replace existing
            }
            $FileInfo = $null

            if (($FileSize -lt 250MB) -and ($UploadSession.IsPresent -eq $false)) {
                # The "content" method only supports files up to 250MB
                Write-Verbose -Message "[$InvocationName] Uploading the file using the 'content' method"
                $Params = @{
                    Method      = 'PUT'
                    Resource    = "$Resource/content"
                    Body        = $fileBytes
                    EA          = 'Stop'
                    ContentType = 'application/octet-stream'
                }
                Invoke-MgGraphRequestSingle @Params
            }
            else {
                #https://learn.microsoft.com/en-us/graph/api/driveitem-createuploadsession?view=graph-rest-beta
                Write-Verbose -Message "[$InvocationName] Creating an upload session"
                $uploadSessionObj = Invoke-MgGraphRequestSingle -Method 'POST' -Resource "$Resource/createUploadSession" -EA Stop
                #[Datetime]$expirationDateTime = $uploadSessionObj.expirationDateTime
                Write-Verbose -Message "[$InvocationName] Upload url [$($uploadSessionObj.uploadUrl)] is valid until $($uploadSessionObj.expirationDateTime)"

                if (($FileSize / 60MB) -ge 1) {
                    $ChunkMultiple = 1
                    if ($FileSize -gt 320KB) {
                        $ChunkMultiple = [Math]::Min((($FileSize / 320KB) - 1), 191) # 60MB is the max chunk size (60MB/320KB - 1)
                    }
                    $ChunkSize = 320KB * $ChunkMultiple # the size of each byte range MUST be a multiple of 320 KB
                    [UInt16]$ChunkNumber = $FileSize / $ChunkSize
                    Write-Verbose -Message "[$InvocationName] Splitting the file since it's larger than 60MB (Chunk size [$ChunkSize], chunks number [$ChunkNumber])"
                    $Index = 1
                    $RangeMin = 0
                    while ($RangeMin -lt $FileSize) {
                        $RangeMax = [math]::Min($RangeMin + $ChunkSize - 1, ($FileSize - 1))
                        $FileChunk = [byte[]]$FileBytes[$RangeMin..$RangeMax]
                        $Headers = @{
                            [string]'Content-Type'   = 'application/octet-stream'
                            [string]'Content-Length' = $FileChunk.length
                            [string]'Content-Range'  = "bytes $RangeMin-$RangeMax/$FileSize"
                        }
                        Write-Verbose -Message "[$InvocationName] {$Index/$ChunkNumber} Header: $($Headers | ConvertTo-Json)"
                        Write-Verbose -Message "[$InvocationName] {$Index/$ChunkNumber} Chunk length: $($FileChunk.Length)"
                        Invoke-MgGraphRequest -Uri $uploadSessionObj.uploadUrl -Method 'PUT' -Headers $Headers -Body $FileChunk -SkipHeaderValidation
                        $RangeMin += $ChunkSize
                    }
                }
                else {
                    $headers = @{
                        'Content-Range' = "bytes 0-$($fileSize - 1)/$fileSize"
                    }
                    Write-Verbose -Message "[$InvocationName] The file size is less than 60MB"
                    Write-Verbose -Message "[$InvocationName] Header: $($Headers | ConvertTo-Json)"
                    Invoke-MgGraphRequest -Uri $uploadSessionObj.uploadUrl -Method 'PUT' -Headers $Headers -Body $fileBytes -SkipHeaderValidation
                }
            }
            $FileBytes = $null
            $FileChunk = $null
            # report memory usage, before and after cleaning it up
            $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
            $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
            Write-Verbose -Message "[$InvocationName] Function finished. Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)"
        }
    }
    end {
        $FolderInfoUP = $null
        # report memory usage, before and after cleaning it up
        $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
        $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
        Write-Verbose -Message "[$InvocationName] Function finished. Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)"
    }
}


function Test-SPFolder {
    <#
.SYNOPSIS
    Test whether a SharePoint folder exists.

.DESCRIPTION
    Test whether a SharePoint folder exists.

.PARAMETER Directory
    SharePoint folder path.

.PARAMETER Id
    SharePoint folder id.

.PARAMETER SiteName
    Name of the SharePoint site.

.PARAMETER SiteId
    Id of the SharePoint site.

.PARAMETER DriveName
    Name of the SharePoint drive.

.PARAMETER DriveId
    Id of the SharePoint drive.

.PARAMETER PassThru
    Return the folder object instead of just $true/$false.

.PARAMETER Property
    Define which folder property are to be returned when using -PassThru.
    By default, only the id and name are returned.
    See the following link for a complete list of available properties:
        https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-beta

.PARAMETER ChildProperty
    Add the children to the folder object and define which child property are to be returned when using -PassThru.
    See the following link for a complete list of available properties:
        https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-beta

.EXAMPLE
    PS C:\> Test-SPFolder -Directory 'Path\Of destination' -SiteId $SiteId -DriveName 'Documents'

.EXAMPLE
    PS C:\> Test-SPFolder -Directory 'Path\Of destination' -SiteName 'MySPSite' -DriveName 'Documents'

.EXAMPLE
    PS C:\> Test-SPFolder -Directory 'Path\Of destination' -SiteName 'MySPSite' -DriveName 'Documents' -PassThru -ChildProperty ('id', 'name')

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-05-13
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'SiteName-Directory-DriveName', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-Directory-DriveName', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-Directory-DriveId', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-Directory-DriveName', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-Directory-DriveId', ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [String]$Directory,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-Id-DriveName', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-Id-DriveId', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-Id-DriveName', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-Id-DriveId', ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Id,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-Directory-DriveName')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-Directory-DriveId')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-Id-DriveName')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-Id-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$SiteName,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-Directory-DriveName')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-Directory-DriveId')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-Id-DriveName')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-Id-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$SiteId,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-Directory-DriveName')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-Id-DriveName')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-Directory-DriveName')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-Id-DriveName')]
        [ValidateNotNullOrEmpty()]
        [String]$DriveName,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-Directory-DriveId')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-Id-DriveId')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-Directory-DriveId')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-Id-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$DriveId,

        [Parameter(ParameterSetName = 'SiteName-Directory-DriveName')]
        [Parameter(ParameterSetName = 'SiteName-Directory-DriveId')]
        [Parameter(ParameterSetName = 'SiteName-Id-DriveName')]
        [Parameter(ParameterSetName = 'SiteName-Id-DriveId')]
        [Parameter(ParameterSetName = 'SiteId-Directory-DriveName')]
        [Parameter(ParameterSetName = 'SiteId-Directory-DriveId')]
        [Parameter(ParameterSetName = 'SiteId-Id-DriveName')]
        [Parameter(ParameterSetName = 'SiteId-Id-DriveId')]
        [switch]$PassThru,

        [Parameter(Position = 3, ParameterSetName = 'SiteName-Directory-DriveName')]
        [Parameter(Position = 3, ParameterSetName = 'SiteName-Directory-DriveId')]
        [Parameter(Position = 3, ParameterSetName = 'SiteName-Id-DriveName')]
        [Parameter(Position = 3, ParameterSetName = 'SiteName-Id-DriveId')]
        [Parameter(Position = 3, ParameterSetName = 'SiteId-Directory-DriveName')]
        [Parameter(Position = 3, ParameterSetName = 'SiteId-Directory-DriveId')]
        [Parameter(Position = 3, ParameterSetName = 'SiteId-Id-DriveName')]
        [Parameter(Position = 3, ParameterSetName = 'SiteId-Id-DriveId')]
        [AllowEmptyCollection()]
        [String[]]$Property = @('id', 'name'),

        [Parameter(Position = 4, ParameterSetName = 'SiteName-Directory-DriveName')]
        [Parameter(Position = 4, ParameterSetName = 'SiteName-Directory-DriveId')]
        [Parameter(Position = 4, ParameterSetName = 'SiteName-Id-DriveName')]
        [Parameter(Position = 4, ParameterSetName = 'SiteName-Id-DriveId')]
        [Parameter(Position = 4, ParameterSetName = 'SiteId-Directory-DriveName')]
        [Parameter(Position = 4, ParameterSetName = 'SiteId-Directory-DriveId')]
        [Parameter(Position = 4, ParameterSetName = 'SiteId-Id-DriveName')]
        [Parameter(Position = 4, ParameterSetName = 'SiteId-Id-DriveId')]
        [AllowEmptyCollection()]
        [String[]]$ChildProperty
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        if ("$SiteId".Trim() -eq '') {
            Write-Verbose -Message "[$InvocationName] Looking for a site named [$SiteName]"
            [String]$SiteId = Invoke-MgGraphRequestSingle -Resource 'sites' -Search $SiteName -Select Name,id | Where-Object -Property Name -EQ $SiteName | Select-Object -ExpandProperty Id
        }
        Write-Verbose -Message "[$InvocationName] SiteId: $SiteId"
        if ("$DriveId".Trim() -eq '') {
            Write-Verbose -Message "[$InvocationName] Looking for a drive named [$DriveName]"
            [String]$DriveId = Invoke-MgGraphRequestSingle -Resource ('sites/{0}/drives' -f $SiteId) -Select Name,id | Where-Object -Property Name -EQ $DriveName | Select-Object -ExpandProperty id
        }
        Write-Verbose -Message "[$InvocationName] DriveId: $DriveId"

        if ($PassThru.IsPresent) {
            if ($ChildProperty.Count -gt 0) {
                $Expand = '$expand=children'
                if ($ChildProperty -notcontains '*') {
                    $Expand = '{0}($select={1})' -f $Expand,($ChildProperty -join ',')
                }
            }
            if (($Property.Count -gt 0) -and ($Property -notcontains '*')) { $Select = "`$Select=$($Property -join ',')" }
        }
        else {
            $Expand = ''
            $Select = '$Select=id' # Select only the id for performance purposes
        }
    }
    process {
        if ($PSCmdlet.ParameterSetName -like '*-Directory-*') {
            [String]$Directory = "$Directory".Replace('\','/')
            $Message = "Folder [$Directory]"
            $Uri = ('v1.0/sites/{0}/drives/{1}/root:/{2}' -f $SiteId, $DriveId, "$Directory".Replace(' ','%20').TrimEnd()).TrimEnd(':/')
        }
        else {
            $Message = "Folder with id [$id]"
            $Uri = 'v1.0/sites/{0}/drives/{1}/items/{2}' -f $SiteId, $DriveId, $Id
        }
        $Uri = ('{0}?{1}&{2}' -f "$uri", "$Select", "$Expand").TrimEnd('&').Replace('?&','?')
        $Result = $false
        try {
            $FolderObject = Invoke-MgGraphRequest -Uri $Uri -ErrorAction 'Stop' -OutputType PSObject
            if ($null -eq $FolderObject) {
                throw 'null object'
            }
            Write-Verbose -Message "[$InvocationName] $Message exists ($($FolderObject.id))"
            $Result = $true
        }
        catch {
            $FolderObject = $null
            $ErrMsg = "[$($_.categoryinfo.Reason)] $($_.Exception.Message)"
            if ($Global:Error.Count -gt 0) { $Global:Error.RemoveAt(0) }
            Write-Verbose -Message "[$InvocationName] $Message is missing: $ErrMsg"
        }
        finally {
            if ($PassThru.IsPresent) {
                $FolderObject
                $FolderObject = $null
                # report memory usage, before and after cleaning it up
                $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
                $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
                Write-Verbose -Message "[$InvocationName] Function finished. Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)"
            }
            else {
                $Result
            }
        }
    }
    end {}
}


function New-SPFolder {
    <#
.SYNOPSIS
    Create a new folder in SharePoint.

.DESCRIPTION
    Create a new folder in SharePoint.

.PARAMETER Directory
    SharePoint folder path.

.PARAMETER SiteName
    Name of the SharePoint site.

.PARAMETER SiteId
    Id of the SharePoint site.

.PARAMETER DriveName
    Name of the SharePoint drive.

.PARAMETER DriveId
    Id of the SharePoint drive.

.EXAMPLE
    PS C:\> New-SPFolder -Directory 'Path\Of destination' -SiteId $SiteId -DriveName 'Documents'

.EXAMPLE
    PS C:\> New-SPFolder -Directory 'Path\Of destination' -SiteName 'MySPSite' -DriveName 'Documents'

.NOTES
    AUTHOR: Marc-Antoine ROBIN
    CREATION: 2026-05-13
    VERSION: 1.0.0
    MODIFICATIONS:

.LINK


#>


    [CmdletBinding(DefaultParameterSetName = 'SiteName-DriveName', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-DriveName', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteName-DriveId', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-DriveName', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SiteId-DriveId', ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Directory,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-DriveName')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteName-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$SiteName,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-DriveName')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SiteId-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$SiteId,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-DriveName')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-DriveName')]
        [ValidateNotNullOrEmpty()]
        [String]$DriveName,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteName-DriveId')]
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SiteId-DriveId')]
        [ValidateNotNullOrEmpty()]
        [String]$DriveId
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        if ("$SiteId".Trim() -eq '') {
            Write-Verbose -Message "[$InvocationName] Looking for a site named [$SiteName]"
            [String]$SiteId = Invoke-MgGraphRequestSingle -Resource 'sites' -Search $SiteName -Select Name,id | Where-Object -Property Name -EQ $SiteName | Select-Object -ExpandProperty Id
        }
        Write-Verbose -Message "[$InvocationName] SiteId: $SiteId"
        if ("$DriveId".Trim() -eq '') {
            Write-Verbose -Message "[$InvocationName] Looking for a drive named [$DriveName]"
            [String]$DriveId = Invoke-MgGraphRequestSingle -Resource ('sites/{0}/drives' -f $SiteId) -Select Name,id | Where-Object -Property Name -EQ $DriveName | Select-Object -ExpandProperty id
        }
        Write-Verbose -Message "[$InvocationName] DriveId: $DriveId"
    }
    process {
        $Directory = "$Directory".Replace('\','/')
        $NewFolder = Test-SPFolder -Directory $Directory -SiteId $SiteId -DriveId $DriveId -PassThru -ChildProperty ('id','name')
        if ($null -eq $NewFolder) {
            Write-Verbose -Message "[$InvocationName] Folder [$Directory] is missing"
            [String[]]$FolderParts = "$Directory".Split('/')
            [String]$ParentId = ''
            Write-Verbose -Message "[$InvocationName] Creating the folder"
            foreach ($Part in $FolderParts) {
                [String]$FolderPath = "$FolderPath/$Part".Trim('/')
                Write-Verbose -Message "[$InvocationName] Looking for [$FolderPath]"
                $Resource = 'sites/{0}/drives/{1}/root:/{2}' -f $SiteId, $DriveId, "$FolderPath".Replace(' ','%20')
                $NewFolder = Test-SPFolder -Directory "$FolderPath".Replace(' ','%20') -SiteId $SiteId -DriveId $DriveId -PassThru -Property '*' -ChildProperty '*'
                if ($null -eq $NewFolder) {
                    Write-Verbose -Message "[$InvocationName] Could not find folder [$FolderPath]"
                    if ("$ParentId" -eq '') {
                        $Resource = 'sites/{0}/drives/{1}/root/children' -f $SiteId, $DriveId
                    }
                    else {
                        $Resource = 'sites/{0}/drives/{1}/items/{2}/children' -f $SiteId, $DriveId, $ParentId
                    }
                    Write-Verbose -Message "[$InvocationName] Creating [$FolderPath]"
                    $Body = @{name = "$Part";folder = @{} }
                    try {
                        if ($PSCmdlet.ShouldProcess($ParentId, "Create a new folder [$FolderPath]")) {
                            <#
                                    POST /drives/{drive-id}/items/{parent-item-id}/children
                                    POST /groups/{group-id}/drive/items/{parent-item-id}/children
                                    POST /me/drive/items/{parent-item-id}/children
                                    POST /sites/{site-id}/drive/items/{parent-item-id}/children
                                    POST /users/{user-id}/drive/items/{parent-item-id}/children
                            #>
                            # https://learn.microsoft.com/en-us/graph/api/driveitem-post-children?view=graph-rest-beta&tabs=http
                            $NewFolder = Invoke-MgGraphRequestSingle -Resource $Resource -Method POST -Body $Body -EA Stop
                            [String]$ParentId = $NewFolder.Id
                        }
                    }
                    catch {
                        $NewFolder = $null
                        $null = [System.GC]::GetTotalMemory($true)
                        throw "[$InvocationName] Failed to create [$FolderPath]: $($_.Exception.Message)"
                    }
                }
                else {
                    [String]$ParentId = $NewFolder.Id
                }
            }
        }
        else {
            Write-Verbose -Message "[$InvocationName] Folder [$Directory] already exists ($($NewFolder.id))"
        }
        $NewFolder
        $NewFolder = $null
        # report memory usage, before and after cleaning it up
        $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
        $NewMemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
        Write-Verbose -Message "[$InvocationName] Function finished. Memory usage: $MemoryUsage MB (After collection: $NewMemoryUsage MB)"
    }
    end {}
}
#endregion SharePoint