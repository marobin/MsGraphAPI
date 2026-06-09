function Invoke-ScriptReport {
    <#
.SYNOPSIS
    Generate a report for the current script's execution.

.DESCRIPTION
    Generate a report for the current script's execution.


$reportData = [PSCustomObject]@{
                Summary      = [PSCustomObject]@{
                    StartTime      = $ScriptStartTime
                    Duration       = '{0:hh\:mm\:ss}' -f ($ScriptEndTime - $ScriptStartTime)
                    TotalObjects   = ($InputObject | Measure-Object).Count
                    ObjectsChanged = ($InputObject | Where-Object -Property Status -Like 'Success*' | Measure-Object).Count
                    WouldChange    = ($InputObject | Where-Object -Property Status -Like 'Audit*' | Measure-Object).Count
                    ObjectsSkipped = ($InputObject | Where-Object -Property Status -Like 'Skipped*' | Measure-Object).Count
                    ObjectsFailed  = ($InputObject | Where-Object -Property Status -match 'Error|Fail' | Measure-Object).Count
                    GlobalError    = $GlobalError
                }
                ScriptParams = New-Object -TypeName System.Collections.ArrayList
                Details      = New-Object -TypeName System.Collections.ArrayList
            }

.PARAMETER DebugMode
    Indicates whether the debug mode was enabled for the script.

.PARAMETER InputObject
    List of the script actions.

    Each item must have a "Status" property with its value matching one of the following:
        Success = Indicates success
        Audit = The script was run using the debug mode
        Skipped = The item was not changed accordingly to the script's conditions
        Error or Fail = The script failed to process the item

.PARAMETER ConfigName
    Which configuration was used in the ScriptParameters.xml file.

.PARAMETER ScriptParams
    List of the script parameters parsed from the ScriptParameters.xml file.

.PARAMETER ScriptAction
    Description of the script's pupose.
    Will be used has the email's subject.

.PARAMETER ReportToDisk
    Save the report to the disk at the ReportPath location.

.PARAMETER ReportPath
    Location of the report on the disk.

.PARAMETER DetailedReport
    Output the details of each processed item.

.PARAMETER ScriptStartTime
    Date and time when the script was started.

.PARAMETER ScriptEndTime
    Date and time when the script was stopped.

.PARAMETER GlobalError
    Indicates if the script failed to run. (Exception catched by the main try/catch block)

.PARAMETER SendMail
    Indicates whether an email should be sent.

.PARAMETER MailSender
    Email address of the sender.

.PARAMETER MailRecipient
    Email addresses of the recipients.

.PARAMETER MailCc
    Email addresses of the cc recipients.

.PARAMETER MailAttachment
    List of files to be attached to the email.

.PARAMETER SmtpServer
    FQDN of the SMTP server used to send the email.

.PARAMETER SmtpPort
    Port of the SMTP server used to send the email.

.PARAMETER MailIdentityFile
    File holding the sender's credentials.

    That file should be exported using the following command:
        Get-Credential | Export-CliXml -Path $MailIdentityFile -Force

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
    param(
        [switch]$DebugMode,

        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [Object[]]$InputObject,

        [Parameter(Position = 1)]
        [String]$ConfigName,

        [Parameter(Position = 2)]
        [System.Xml.XmlElement[]]$ScriptParams,

        [Parameter(Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptAction = 'Generic Report',

        [Switch]$DetailedReport,

        [Switch]$ReportToDisk,

        [Parameter(Position = 4)]
        [String]$ReportPath,

        [Parameter(Position = 6)]
        [ValidateNotNullOrEmpty()]
        [datetime]$ScriptStartTime = [DateTime]::Now,

        [Parameter(Position = 7)]
        [ValidateNotNullOrEmpty()]
        [datetime]$ScriptEndTime = [DateTime]::Now,

        [Parameter(Position = 8)]
        [String]$GlobalError,

        [Switch]$SendMail,

        [Parameter(Position = 9)]
        [String]$MailSender,

        [Parameter(Position = 10)]
        [String[]]$MailRecipient,

        [Parameter(Position = 11)]
        [String[]]$MailCc,

        [Parameter(Position = 12)]
        [String[]]$MailAttachment,

        [Parameter(Position = 13)]
        [String]$SmtpServer,

        [Parameter(Position = 14)]
        [String]$SmtpPort,

        [Parameter(Position = 15)]
        [String]$MailIdentityFile
    )

    begin {
        $InvocationName = $MyInvocation.MyCommand.Name
        Write-Log -Message ('[{0}] Starting report generation' -f $InvocationName)
    }

    process {
        try {
            #region report variables
            # Validate $StartTime
            if (($null -eq $ScriptStartTime) -or (-not ($ScriptStartTime -is [datetime]))) {
                $ScriptStartTime = [DateTime]::Now
                Write-Log -Message "[$InvocationName] Start time not provided, using current time: $ScriptStartTime"
            }
            if (($null -ne $ScriptEndTime) -and (-not ($ScriptEndTime -is [datetime]))) {
                $ScriptEndTime = [DateTime]::Now
                Write-Log -Message "[$InvocationName] End time not provided, using current time: $ScriptEndTime"
            }

            $ScriptContext = "$Env:USERDOMAIN\$env:USERNAME"

            # Create report data structure using Progress values
            $reportData = [PSCustomObject]@{
                Summary      = [PSCustomObject]@{
                    ScriptContext  = $ScriptContext
                    StartTime      = $ScriptStartTime
                    Duration       = '{0:hh\:mm\:ss}' -f ($ScriptEndTime - $ScriptStartTime)
                    TotalObjects   = ($InputObject | Measure-Object).Count
                    ObjectsChanged = ($InputObject | Where-Object -Property Status -Match 'Success' | Measure-Object).Count
                    WouldChange    = ($InputObject | Where-Object -Property Status -Match 'Audit' | Measure-Object).Count
                    ObjectsSkipped = ($InputObject | Where-Object -Property Status -Match 'Skipped' | Measure-Object).Count
                    ObjectsFailed  = ($InputObject | Where-Object -Property Status -Match 'Error|Fail' | Measure-Object).Count
                    GlobalError    = $GlobalError
                }
                ScriptParams = $null
                Details      = New-Object -TypeName System.Collections.ArrayList
            }

            if (($ScriptParams | Measure-Object).Count -gt 0) {
                $ParamsObject = [PSCustomObject]@{}
                foreach ($Param in $ScriptParams) {
                    if ($Param.Name -match 'Certificate') { continue }
                    $ParamsObject | Add-Member -MemberType NoteProperty -Name "$("$($Param.Name)".Trim())" -Value "$($Param.InnerText)".Trim() -Force
                }
                $reportData.ScriptParams = $ParamsObject
            }

            # Generate detailed report if requested (Used by Azure Automation)
            if (($DetailedReport.IsPresent -eq $true) -and ($reportData.Summary.TotalObjects -gt 0)) {
                $reportData.Details.AddRange($InputObject)
                Write-Output "`nScript Report - $ScriptAction - Details"
                Write-Output '================================================================================================================================='
                # Use deviceResults queue for detailed status
                $ErrorActionPreference = 'Silentlycontinue'
                $InputObject | Select-Object -Property * -ExcludeProperty '*id' | Sort-Object -Property Status | Format-Table -AutoSize -Force
                Write-Output ''
                $ErrorActionPreference = 'Stop'
            }

            # Display simple report (Used by Azure Automation)
            Write-Output "`nScript Report - $ScriptAction"
            Write-Output '====================='
            Write-Output "Start Time: $($reportData.Summary.StartTime)"
            Write-Output "Duration: $($reportData.Summary.Duration)"
            Write-Output "`nSummary Statistics:"
            Write-Output '-----------------'
            Write-Output "Total Objects Found:`t`t$($reportData.Summary.TotalObjects)"
            Write-Output "Would Change:`t`t`t$($reportData.Summary.WouldChange)"
            Write-Output "Changed:`t`t`t$($reportData.Summary.ObjectsChanged)"
            Write-Output "Skipped Total:`t`t`t$($reportData.Summary.ObjectsSkipped)"
            Write-Output "Failed:`t`t`t`t$($reportData.Summary.ObjectsFailed)"
            #endregion report variables

            #region export report
            # Save report to disk if requested
            if ($ReportToDisk) {
                $ReportPath = $ExecutionContext.InvokeCommand.ExpandString("$ReportPath")
                $reportFullPath = Join-Path -Path $ReportPath -ChildPath ("Report_$($ConfigName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').json" -replace '_+','_')
                if (-not (Test-Path -Path $reportPath)) {
                    $null = New-Item -ItemType Directory -Path $reportPath -Force -WhatIf:$false
                }
                $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFullPath -Force -WhatIf:$false
                Write-Log -Message "[$InvocationName] Saved report to: $reportFullPath"
            }
            #endregion export report

            Write-Log -Message ('[{0}] Report generation completed successfully' -f $InvocationName)
        }
        catch {
            Write-Log -Message ('[{0}] Failed to generate report' -f $InvocationName) -Type Error
        }

        #region email
        if ($SendMail.IsPresent) {
            Write-Log -Message ("[{0}] Preparing the email's content" -f $InvocationName)
            $BodyAsHtml = $false
            $FirstLine = ''
            $Priority = 'Normal'
            $MailSubject = "$ScriptAction [$ConfigName]"

            if ("$GlobalError" -ne '') {
                $MailSubject = "$MailSubject - ERROR"
                $Priority = 'High'
                $FirstLine = @"
Error while executing the script: $GlobalError

"@
            }
            elseif ($reportData.Summary.ObjectsFailed -gt 0) {
                $FirstLine = @'
The script has failed to process ({0}) elements.

'@ -f $reportData.Summary.ObjectsFailed
            }
            elseif ($DebugMode.IsPresent -eq $true) {
                $MailSubject = "$MailSubject - DEBUG"
            }

            $Body = @'
$FirstLine
Script execution summary:
- Context   : $ScriptContext
- Start Time: $($reportData.Summary.StartTime)
- Duration:   $($reportData.Summary.Duration)
- Total:      $($reportData.Summary.TotalObjects)
- WhatIf:     $($reportData.Summary.WouldChange)
- Changed:    $($reportData.Summary.ObjectsChanged)
- Skipped:    $($reportData.Summary.ObjectsSkipped)
- Failed:     $($reportData.Summary.ObjectsFailed)
'@
            if ("$Mailtemplate" -ne '') {
                # Use an html template
                [String]$Mailtemplate = $ExecutionContext.InvokeCommand.ExpandString("$Mailtemplate")
                if (("$Mailtemplate" -ne '') -and (Test-Path -Path $Mailtemplate) -and ((Get-Item -Path $MailTemplate).Extension -eq '.html')) {
                    $BodyAsHtml = $true
                    $Body = Get-Content -Path $MailTemplate
                    $Body = $Body.Replace('<h4 style="color: #ff0000;"></h4>','')
                    Write-Log -Message ('[{0}] Using the html email template [{1}]' -f $InvocationName, $Mailtemplate)
                }
                else {
                    Write-Log -Message ('[{0}] Cannot use the html email template [{1}], using the default one' -f $InvocationName, $Mailtemplate) -Type Warning
                }
            }

            try {
                $Attachments = New-Object -TypeName System.Collections.ArrayList
                $null = $Attachments.Add($reportFullPath)
                $MailAttachment | Where-Object { ($null -ne $_) -and (Test-Path -Path "$_") } | ForEach-Object { $null = $Attachments.Add($_) }

                [String]$MailIdentityFile = $ExecutionContext.InvokeCommand.ExpandString("$MailIdentityFile")
                if (("$MailIdentityFile" -eq '') -or (! (Test-Path -Path $MailIdentityFile))) {
                    throw "Could not find $MailIdentityFile"
                }
                $Credential = Import-Clixml -Path $MailIdentityFile
                $MailParams = @{
                    BodyAsHtml  = $BodyAsHtml
                    Body        = $ExecutionContext.InvokeCommand.ExpandString("$Body".Replace('<p></p>','')) # Remove the paragraph if $FirstLine is empty
                    From        = $MailSender
                    To          = $MailRecipient
                    Subject     = $MailSubject
                    Encoding    = [System.Text.Encoding]::UTF8
                    UseSsl      = $true
                    Credential  = $Credential
                    SmtpServer  = $SmtpServer
                    Port        = $SMTPPort
                    Priority    = $Priority
                    ErrorAction = 'Stop'
                }
                if ($Attachments.Count -gt 0) {
                    Write-Log -Message ('[{0}] Adding attachments: {1}' -f $InvocationName, ($Attachments -join ', '))
                    $MailParams.Attachments = [String[]]$Attachments
                }
                Write-Log -Message ('[{0}] Sending the email' -f $InvocationName, ($Attachments -join ', '))
                Send-MailMessage @MailParams
                Write-Log -Message ('[{0}] The email was sent successfully' -f $InvocationName, ($Attachments -join ', '))
            }
            catch {
                Write-Log -Message ('[{0}] Failed to send the email' -f $InvocationName) -Type Error
            }
        }
        #endregion email
    }
    end {
        # End function and report memory usage
        $MemoryUsage = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1MB), 2)
        $MemoryUsageAfter = [Math]::Round(([System.GC]::GetTotalMemory('forcefullcollection') / 1MB), 2)
        Write-Log -Message "[$InvocationName] End of function. Memory usage: $MemoryUsage MB ($MemoryUsageAfter MB after cleanup)"
    }
}