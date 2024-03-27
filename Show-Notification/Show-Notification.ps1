function Show-Notification {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ToastTitle,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ToastText,

        [ValidateSet('ToastImageAndText01', 'ToastImageAndText02', 'ToastImageAndText03', 'ToastImageAndText04')]
        [string]$TemplateType = 'ToastImageAndText04', # Default to a template that supports buttons

        [ValidateRange(0.1, 60)]
        [double]$ExpirationTime = 1,

        [string]$AppLogo, # Path to the app logo image

        [switch]$Silent,

        [hashtable]$Buttons # New parameter for buttons as a hashtable
    )

    begin {
        if (-not ([System.Management.Automation.PSTypeName]'Windows.UI.Notifications.ToastNotificationManager').Type) {
            throw 'This function requires the Windows 10 SDK or later.'
        }

        # Retrieve the specified template type for the toast notification
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::$TemplateType)
        $xml = [xml]$template.GetXml()
    }

    process {
        try {
            # Validate AppLogo if provided
            if ($AppLogo -and -not (Test-Path -Path $AppLogo -PathType Leaf)) {
                throw "The specified AppLogo image file does not exist: $AppLogo"
            }

            # Validate Buttons parameter type
            if ($Buttons -and $Buttons.GetType() -ne [hashtable]) {
                throw "The Buttons parameter must be a hashtable."
            }

            # Insert title and text into the XML
            $textElements = $xml.GetElementsByTagName("text")
            $textElements[0].AppendChild($xml.CreateTextNode($ToastTitle)) > $null
            if ($textElements.Count -gt 1) {
                $textElements[1].AppendChild($xml.CreateTextNode($ToastText)) > $null
            }

            # If an AppLogo is provided, incorporate it into the notification
            if ($AppLogo) {
                $imageElements = $xml.GetElementsByTagName("image")
                if ($imageElements.Count -gt 0) {
                    $imageElements[0].SetAttribute("src", $AppLogo)
                }
            }

            if ($Buttons) {
                # Adding actions (buttons) to the toast notification
                $actions = $xml.CreateElement("actions")

                # Create an input field for responses (useful for interactive notifications)
                $input = $xml.CreateElement("input")
                $input.SetAttribute("id", "userResponse")
                $input.SetAttribute("type", "text")
                $input.SetAttribute("placeHolderContent", "Type a response")
                $actions.AppendChild($input) > $null

                # Iterate over provided buttons and add them to the notification
                foreach ($buttonText in $Buttons.Keys) {
                    $button = $xml.CreateElement("action")
                    $button.SetAttribute("content", $buttonText)
                    $button.SetAttribute("arguments", $Buttons[$buttonText])
                    $button.SetAttribute("activationType", "foreground")
                    $actions.AppendChild($button) > $null
                }

                # Append the actions to the main toast XML
                $xml.toast.AppendChild($actions) > $null
            }

            # Prepare the XML for the toast notification
            $serializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
            $serializedXml.LoadXml($xml.OuterXml)

            # Create and show the toast notification
            $toast = [Windows.UI.Notifications.ToastNotification]::new($serializedXml)
            $toast.Tag = "PowerShell"
            $toast.Group = "PowerShell"
            $toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes($ExpirationTime)
            $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PowerShell")
            $notifier.Show($toast)
        }
        catch [System.Exception] {
            $errorMessage = $_.Exception.Message
            if (-not $Silent) {
                Write-Error "Failed to show notification due to an error: $errorMessage"
            }
        }
    }
}
