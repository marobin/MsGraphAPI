# MSGraphAPI Module

This module contains Microsoft Graph API, Azure REST API, Log Analytics, and SharePoint helper functions.

Most of the functions below use a comment-based help.
Once the module is imported, **Get-Help -Name `<FunctionName>` -ShowWindow** can be used against these functions.

## Authentication
| Name                          | Description                                                            |
| ----------------------------- | ---------------------------------------------------------------------- |
| ConvertFrom-JWTToken          | Convert a JWT token to an object.                                      |
| Test-GraphRequiredScope       | Test if the required permissions are available in the current context. |
| Connect-MgGraphApplication    | Connect to Microsoft Graph and Azure.                                  |
| Add-MsGraphOAuthAppPermission | Add delegated Graph permissions to an App Registration.                |
| Invoke-Pim                    | Activation of Priviledge Identity Management eligible Entra Id roles.  |
| Get-PimHistory                | Get the history of Priviledge Identity Management actions.             |

## Invoke Graph and Azure API requests
| Name                        | Description                                  |
| --------------------------- | -------------------------------------------- |
| Invoke-MgGraphRequestBatch  | Invoke a Microsoft Graph request as a batch. |
| Invoke-MgGraphRequestSingle | Invoke a Microsoft Graph request.            |
| Invoke-AzureRequestBatch    | Invoke a Azure REST API request as a batch.  |
| Invoke-AzureRequestSingle   | Invoke an Azure REST API request.            |

## Entra ID
| Name                       | Description                                                             |
| -------------------------- | ----------------------------------------------------------------------- |
| Get-EntraIdSignInLog       | Get the sign in logs for a user, a device, or by using a correlationid. |
| Get-EntraIdGroupInfo       | Get information about a group.                                          |
| Get-EntraIdGroupMembership | Get the members of the groups specified in the parameters.              |
| New-EntraIdGroup           | Create an Entra Id security group.                                      |
| Add-EntraIdGroupMember     | Add members to an existing Entra Id security group.                     |
| Remove-EntraIdGroupMember  | Remove members from an existing Entra Id security group.                |
| Add-EntraIdGroupOwner      | Add owners to an existing Entra Id security group.                      |
| Remove-EntraIdGroupOwner   | Remove owners from an existing Entra Id security group.                 |

## Intune
| Name                                | Description                                                                          |
| ----------------------------------- | ------------------------------------------------------------------------------------ |
| Get-IntuneAuditLog                  | Query the Intune Audit logs                                                          |
| Resolve-CloudResourceId             | Return the type, resource associated with and id                                     |
| ConvertFrom-IntuneAssignmentTarget  | Convert the target object of Intune assignments to PSCustomObject.                   |
| Get-IntuneAssignment                | Get a list of assignments for every assignable object in Intune.                     |
| Get-IntunePolicyChangeLog           | List the history of action made on a policy                                          |
| Resolve-IntuneConfigurationPolicy   | Parse an Intune setting object and return the relevant information                   |
| Resolve-SettingUriToUrl             | Parse a CSP setting uri (OmaUri) to retrieve the link to its documentation.          |
| Get-IntunePolicy                    | Get information about Intune policies.                                               |
| Export-IntunePolicy                 | Export an Intune policy as a json file.                                              |
| Export-IntunePolicyToExcel          | Export Intune policies and their respective settings into an Excel file.             |
| Import-IntunePolicy                 | Import an Intune policy in a json file.                                              |
| Get-IntuneReport                    | Use the reports/exportJobs endpoint to generate Intune reports.                      |
| Get-IntunePolicySummaryReport       | Generate and display the Policy configuration status report                          |
| Get-IntunePolicyReport              | Generate and display the Policy configuration status report for the specified policy |
| Get-IntunePolicyTemplate            | Get a list of the Intune policy templates.                                           |
| Get-IntuneTemplate                  | Get a list of the Intune templates.                                                  |
| Get-IntuneSettingCategory           | Get a list of all the Intune setting categories.                                     |
| Get-IntuneScopeTag                  | Get the Intune scope tags.                                                           |
| Get-IntuneRBACRole                  | Get the Intune RBAC roles.                                                           |
| Get-IntuneAssignmentFilter          | List Intune assignment filters.                                                      |
| Get-IntuneHealthScript              | Get the Intune health (remediation) scripts.                                         |
| Invoke-IntuneHealthScriptDownload   | Download Intune Health (remediation) scripts.                                        |
| Get-IntunePlatformScript            | Get the Intune platform scripts.                                                     |
| Invoke-IntunePlatformScriptDownload | Download Intune platform scripts.                                                    |

## Miscellaneous

| Name                             | Description                                                        |
| -------------------------------- | ------------------------------------------------------------------ |
| Convert-GraphErrorMessage        | Return the error returned by the graph request as a PSCustomObject |
| Convert-PSObjectArrayToHashTable | Convert a PSObject array to an hashtable.                          |
| Send-GraphMail                   | Send an email using Microsoft Graph.                               |

## Log Analytics
| Name                     | Description                                                         |
| ------------------------ | ------------------------------------------------------------------- |
| Invoke-LogAnalyticsQuery | Run a Log Analytics Query and retrieve the output.                  |
| Send-LogAnalyticsData    | Send log data to Azure Monitor by using the HTTP Data Collector API |

## SharePoint
| Name                  | Description                              |
| --------------------- | ---------------------------------------- |
| Invoke-SPFileDownload | Download files from a SharePoint site.   |
| Invoke-SPFileUpload   | Upload files to a SharePoint site.       |
| New-SPFolder          | Create a new folder in SharePoint.       |
| Test-SPFolder         | Test whether a SharePoint folder exists. |


# Scripts

## CreateIntuneDriverGroupAndPolicy
  
Create the Entra Id group along with the Intune driver policies based on the make and models of the devices present in Entra Id.


## SetIntunePrimaryUser
  
Change the primary user for Intune devices to the user who signs in to them most often.

## SyncUserAndDeviceGroups
  



## EntraIdGroupAnalysis
  
Export detailed information about Entra Id groups.
This report can take a very long time to update depending on the number of groups present in Entra Id.
  
  
* `All groups` worksheet

List of all the Entra Id groups.

| Property                      | Description                                                                                                              |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| id                            | Id of the group                                                                                                          |
| Name                          | Name of the group                                                                                                        |
| Description                   | Description of the group                                                                                                 |
| Type                          | Type of group (`Microsoft 365`,`Mail enabled security`,`Security`,`Distribution`)                                        |
| Membership                    | Type of membership (`Assigned`,`Dynamic`)                                                                                |
| Source                        | Source of authority (`Windows Server AD`,`Cloud`)                                                                        |
| Test group                    | Indicate whether the group name contains specific test keywords                                                          |
| Members                       | Number of members                                                                                                        |
| Devices                       | Number of device members                                                                                                 |
| Users                         | Number of user members                                                                                                   |
| Groups                        | Number of group members                                                                                                  |
| Others                        | Number of other members                                                                                                  |
| To be reviewed                | Indicate whether the group should be reviewed (test group, empty group, both devices and users are members of the group) |
| Created on                    | Date of creation                                                                                                         |
| Security enabled              | Is security enabled for the group?                                                                                       |
| Role assignable               | Is the group assignable to a role                                                                                        |
| On-prem sync enabled          | Is group synched from Active Directory?                                                                                  |
| On-prem domain                | Active Directory domain                                                                                                  |
| Writeback enabled             | Is writeback enabled?                                                                                                    |
| Nested in                     | List of group where the group is nested in                                                                               |
| Nested groups                 | List of groups nested in the group                                                                                       |
| OnPremisesGroupType           | Type of Active Directory group                                                                                           |
| Mail enabled                  | Is email enabled for the group?                                                                                          |
| Mail                          | group email                                                                                                              |
| In use                        | Is the group in use?                                                                                                     |
| Used for Intune Policy        | Intune policies where the group is assigned to                                                                           |
| Used for Intune Roles         | Intune RBAC roles where the group is assigned to                                                                         |
| Used for Intune ScopeTag      | Intune scope tags where the group is assigned to                                                                         |
| Used for Administrative units | Administrative units where the group is assigned to                                                                      |


* `Dynamic groups` worksheet

Detail of all the Entra Id dynamic groups along with their rules.  

| Property            | Description                                                                               |
| ------------------- | ----------------------------------------------------------------------------------------- |
| id                  | Id of the group                                                                           |
| Name                | Name of the group                                                                         |
| Membership rule     | Rule used as membership                                                                   |
| Processing state    | Indicates whether the dynamic membership state is `On` or `Off`                           |
| Uses group.objectid | Indicates whether the rule uses the memberOf rule                                         |
| Nested group        |                                                                                           |
| ext1                | Indicate whether the rule uses the extensionAttribute1 linked to device or user members.  |
| ext2                | Indicate whether the rule uses the extensionAttribute2 linked to device or user members.  |
| ext3                | Indicate whether the rule uses the extensionAttribute3 linked to device or user members.  |
| ext4                | Indicate whether the rule uses the extensionAttribute4 linked to device or user members.  |
| ext5                | Indicate whether the rule uses the extensionAttribute5 linked to device or user members.  |
| ext6                | Indicate whether the rule uses the extensionAttribute6 linked to device or user members.  |
| ext7                | Indicate whether the rule uses the extensionAttribute7 linked to device or user members.  |
| ext8                | Indicate whether the rule uses the extensionAttribute8 linked to device or user members.  |
| ext9                | Indicate whether the rule uses the extensionAttribute9 linked to device or user members.  |
| ext10               | Indicate whether the rule uses the extensionAttribute10 linked to device or user members. |
| ext11               | Indicate whether the rule uses the extensionAttribute11 linked to device or user members. |
| ext12               | Indicate whether the rule uses the extensionAttribute12 linked to device or user members. |
| ext13               | Indicate whether the rule uses the extensionAttribute13 linked to device or user members. |
| ext14               | Indicate whether the rule uses the extensionAttribute14 linked to device or user members. |
| ext15               | Indicate whether the rule uses the extensionAttribute15 linked to device or user members. |
| Autopilot           | Indicates whether the rule uses the groupTag (OrderId) of the Autopilot device.           |
| GroupTag            | groupTag filter as specified in the rule                                                  |
| UserProperties      | List of user properties used to define the rule                                           |
| DeviceProperties    | List of user properties device to define the rule                                         |

* `Intune assignments`
List of all the existing Intune assignments.

* `Intune RBAC`
List of all the existing Intune RBAC assignments.

* `Intune Scope Tags`
List of all the existing Intune scope tags assignments.


* `Administrative Units` (Work in progress...)
List of all the existing Administrative Units assignments.


## Export-GraphPermissions

