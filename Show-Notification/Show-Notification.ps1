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

        # Function to sanitize input to prevent XML injection
        function Sanitize-XmlInput {
            param([string]$InputString)

            if ([string]::IsNullOrEmpty($InputString)) {
                return $InputString
            }

            # Replace XML special characters with their entities
            $sanitized = $InputString -replace '&', '&amp;'
            $sanitized = $sanitized -replace '<', '&lt;'
            $sanitized = $sanitized -replace '>', '&gt;'
            $sanitized = $sanitized -replace '"', '&quot;'
            $sanitized = $sanitized -replace "'", '&apos;'

            return $sanitized
        }

        # Function to validate and sanitize file paths
        function Test-ValidImagePath {
            param([string]$Path)

            if ([string]::IsNullOrWhiteSpace($Path)) {
                return $false
            }

            # Check for path traversal
            if ($Path -match '\.\.') {
                throw "Path contains directory traversal sequences: $Path"
            }

            # Validate the path
            if (-not (Test-Path -Path $Path -PathType Leaf -ErrorAction SilentlyContinue)) {
                throw "The specified image file does not exist: $Path"
            }

            # Check for valid image extensions
            $validExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.ico')
            $extension = [System.IO.Path]::GetExtension($Path).ToLower()

            if ($extension -notin $validExtensions) {
                throw "Invalid image file extension: $extension"
            }

            return $true
        }
    }

    process {
        try {
            # Sanitize input strings to prevent XML injection
            $safeTitle = Sanitize-XmlInput -InputString $ToastTitle
            $safeText = Sanitize-XmlInput -InputString $ToastText

            # Validate AppLogo if provided
            if ($AppLogo) {
                Test-ValidImagePath -Path $AppLogo | Out-Null
            }

            # Validate Buttons parameter type and sanitize values
            if ($Buttons -and $Buttons.GetType() -ne [hashtable]) {
                throw "The Buttons parameter must be a hashtable."
            }

            # Insert title and text into the XML
            $textElements = $xml.GetElementsByTagName("text")
            $textElements[0].AppendChild($xml.CreateTextNode($safeTitle)) > $null
            if ($textElements.Count -gt 1) {
                $textElements[1].AppendChild($xml.CreateTextNode($safeText)) > $null
            }

            # If an AppLogo is provided, incorporate it into the notification
            if ($AppLogo) {
                $imageElements = $xml.GetElementsByTagName("image")
                if ($imageElements.Count -gt 0) {
                    # Sanitize path for XML attribute
                    $safeAppLogo = Sanitize-XmlInput -InputString $AppLogo
                    $imageElements[0].SetAttribute("src", $safeAppLogo)
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
                    # Sanitize button text and arguments
                    $safeButtonText = Sanitize-XmlInput -InputString $buttonText
                    $safeButtonArgs = Sanitize-XmlInput -InputString $Buttons[$buttonText]

                    $button.SetAttribute("content", $safeButtonText)
                    $button.SetAttribute("arguments", $safeButtonArgs)
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
