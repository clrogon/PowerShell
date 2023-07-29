<#
.Synopsis
   Short description
.DESCRIPTION
   The purpose of this function is to purely to display text from the PowerShell icon in the notification area.
   https://www.computerperformance.co.uk/powershell/function-show-balloontip/
.EXAMPLE
   Show-BalloonTip -Text 'Look at me!' -Title 'Tip from Guy'
.EXAMPLE
   Show-BalloonTip -Text 'Look at me!' -Title 'Tip from Guy' -Icon Error -Timeout 20000
#>
Function Global:Show-BalloonTip
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Title help description
        [Parameter(Mandatory=$true)]$Title,
        # Text help description
        [Parameter(Mandatory=$true)]$Text,
        # Info help. Should be one of the following options 'None','Info','Warning','Error'
        $Icon = 'Info',
        # Timeout help. Sets the time that the balloon appears in milliseconds.  The default in this script $10000 is ten seconds.
        $Timeout = 10000
    )

    Process
    {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    if ($PopUp -eq $null)
    {
        $PopUp = New-Object System.Windows.Forms.NotifyIcon
    }
    #$PID is process identifier for the program that runs the script, and that would be PowerShell.
    $Path = Get-Process -Id $PID | Select-Object -ExpandProperty Path
    #$PopUp.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($Path)
    #Icons Avaialble Information | Error | Warning | Error
    $PopUp.Icon = [System.Drawing.SystemIcons]::Information
    $PopUp.BalloonTipIcon = $Icon
    $PopUp.BalloonTipText = $Text
    $PopUp.BalloonTipTitle = $Title
    $PopUp.Visible = $true
    $PopUp.ShowBalloonTip($Timeout)
    } # End of Process
}# End of Function
