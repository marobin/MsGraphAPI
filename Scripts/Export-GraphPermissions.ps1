[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 0)]
    [String]$Destination
)

function ConvertFrom-HTMLTable {
    <#
    .SYNOPSIS
    Function for converting ComObject HTML object to common PowerShell object.

    .DESCRIPTION
    Function for converting ComObject HTML object to common PowerShell object.
    ComObject can be retrieved by (Invoke-WebRequest).parsedHtml or IHTMLDocument2_write methods.

    In case table is missing column names and number of columns is:
    - 2
        - Value in the first column will be used as object property 'Name'. Value in the second column will be therefore 'Value' of such property.
    - more than 2
        - Column names will be numbers starting from 1.

    .PARAMETER table
    ComObject representing HTML table.

    .PARAMETER tableName
    (optional) Name of the table.
    Will be added as TableName property to new PowerShell object.

    .EXAMPLE
    $pageContent = Invoke-WebRequest -Method GET -Headers $Headers -Uri "https://docs.microsoft.com/en-us/mem/configmgr/core/plan-design/hierarchy/log-files"
    $table = $pageContent.ParsedHtml.getElementsByTagName('table')[0]
    $tableContent = @(ConvertFrom-HTMLTable $table)

    Will receive web page content >> filter out first table on that page >> convert it to PSObject

    .EXAMPLE
    $Source = Get-Content "C:\Users\Public\Documents\MDMDiagnostics\MDMDiagReport.html" -Raw
    $HTML = New-Object -Com "HTMLFile"
    $HTML.IHTMLDocument2_write($Source)
    $HTML.body.getElementsByTagName('table') | % {
        ConvertFrom-HTMLTable $_
    }

    Will get web page content from stored html file >> filter out all html tables from that page >> convert them to PSObjects

    .LINK
    https://doitpshway.com/how-to-createupdateread-html-table-on-confluence-wiki-page-using-powershell
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.__ComObject] $table,

        [string] $tableName
    )

    PROCESS {
        $twoColumnsWithoutName = $False

        if ($tableName) { $tableNameTxt = "'$tableName'" }

        [String[]]$ColumnNameList = ($table.getElementsByTagName('th') | Select-Object -ExpandProperty InnerText) -replace '^\s*|\s*$'

        if ($ColumnNameList.Count -eq 0) {
            $numberOfColumns = @($table.getElementsByTagName('tr')[0].getElementsByTagName('td')).count
            if ($numberOfColumns -eq 2) {
                $twoColumnsWithoutName = $true
                Write-Verbose "Table $tableNameTxt has two columns without column names. Resultant object will use first column as objects property 'Name' and second as 'Value'"
            }
            elseif ($numberOfColumns) {
                Write-Warning "Table $tableNameTxt doesn't contain column names, numbers will be used instead"
                $ColumnNameList = 1..$numberOfColumns
            }
            else {
                throw "Table $tableNameTxt doesn't contain column names and summarization of columns failed"
            }
        }

        if ($twoColumnsWithoutName -eq $true) {
            # table has two columns without names
            $property = [ordered]@{ }

            $RowList = $table.getElementsByTagName('tr')
            Foreach ($Row in $RowList) {
                # read table per row and return object
                $columnValue = ($Row.getElementsByTagName('td') | Select-Object -ExpandProperty InnerText) -replace '^\s*|\s*$'
                if ($columnValue) {
                    # use first column value as object property 'Name' and second as a 'Value'
                    $property.($columnValue[0]) = $columnValue[1]
                }
                else {
                    # row doesn't contain <td>
                }
            }
            if ($tableName) {
                $property.TableName = $tableName
            }

            New-Object -TypeName PSObject -Property $property
        }
        else {
            # table doesn't have two columns or they are named
            $RowList = $table.getElementsByTagName('tr')
            Foreach ($Row in $RowList) {
                # read table per row and return object
                $columnValue = ($Row.getElementsByTagName('td') | Select-Object -ExpandProperty InnerText) -replace '^\s*|\s*$'
                if ($columnValue) {
                    $property = [ordered]@{ }
                    $i = 0
                    foreach ($Column in $ColumnNameList) {
                        $property.$Column = $columnValue[$i]
                        ++$i
                    }
                    if ($tableName) {
                        $property.TableName = $tableName
                    }

                    New-Object -TypeName PSObject -Property $property
                }
                else {
                    # row doesn't contain <td>, its probably row with column names
                }
            }
        }
    }
}

If (! (Test-Path -Path $Destination)) {
    $null = New-Item -Path $Destination -ItemType Directory -Force
}


$uri = 'https://learn.microsoft.com/en-us/graph/permissions-reference'
$WebRequest = Invoke-WebRequest -Uri $Uri

$TitleH3List = $WebRequest.ParsedHtml.getElementsByTagName('h3') | Select-Object -ExpandProperty InnerText
$TableList = $WebRequest.ParsedHtml.getElementsByTagName('table')

$Index = 0
$(
    Foreach ($Table in $TableList) {
        [String]$Permission = "$($TitleH3List[$Index])".Trim()

        $ConvertedTable = $Table | ConvertFrom-HTMLTable
        $RSCTable = ($ConvertedTable | Measure-Object -Property Name -ErrorAction Ignore).Count -gt 0
        $StandardTable = ($ConvertedTable | Measure-Object -Property Category -ErrorAction Ignore).Count -gt 0
        If ($null -eq $ConvertedTable) { continue }
        If ($StandardTable) {
            If ($Permission.IndexOf(' ') -ne -1) { $index++; continue }
            $Object,$Action,$Scope = $Permission.Split('.')

            foreach ($Column in ('Identifier','DisplayText','Description','AdminConsentRequired')) {
                New-Variable -Name $Column -Value $ConvertedTable.Where({ $_.Category -eq $Column }) -Force
            }
            foreach ($Category in ('Application', 'Delegated')) {
                [PSCustomObject]@{
                    Permission   = $Permission
                    Object       = $Object
                    Action       = $Action
                    #Scope        = $Scope
                    Category     = $Category
                    AdminConsent = "$($AdminConsentRequired.$Category)".Trim()
                    Identifier   = "$($Identifier.$Category)".Trim()
                    DisplayText  = "$($DisplayText.$Category)".Trim()
                    Description  = "$($Description.$Category)".Trim()
                }
            }
        }
        ElseIf ($RSCTable) {
            Foreach ($Item in $ConvertedTable) {
                $Object,$Action,$Scope = "$($Item.Name)".Split('.')
                [PSCustomObject]@{
                    Permission   = $Item.Name
                    Object       = $Object
                    Action       = $Action
                    #Scope        = $Scope
                    Category     = 'RSC'
                    AdminConsent = ''
                    Identifier   = $Item.ID
                    DisplayText  = $Item.'Display text'
                    Description  = $Item.Description
                }
            }
        }
        Else {
            Continue
        }
        $index++
    }
) | Export-Csv -Path "$Destination\MSGraph-Permission-Reference.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force
