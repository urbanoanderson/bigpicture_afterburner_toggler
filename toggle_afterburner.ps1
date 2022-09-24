# Elevates if not admin (necessary for closing processes)
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = "-c cd '$pwd'; & `"" + $MyInvocation.MyCommand.Path + "`""
        Start-Process powershell -Verb runas -ArgumentList $CommandLine
        Exit
    }
}

function Show-Notification {
    [cmdletbinding()]
    Param (
        [string]
        $ToastTitle,
        [string]
        $ToastText
    )

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)

    $RawXml = [xml] $Template.GetXml()
    ($RawXml.toast.visual.binding.text|where {$_.id -eq "1"}).AppendChild($RawXml.CreateTextNode($ToastTitle)) > $null
    ($RawXml.toast.visual.binding.text|where {$_.id -eq "2"}).AppendChild($RawXml.CreateTextNode($ToastText)) > $null

    $SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $SerializedXml.LoadXml($RawXml.OuterXml)

    $Toast = [Windows.UI.Notifications.ToastNotification]::new($SerializedXml)
    $Toast.Tag = "PowerShell"
    $Toast.Group = "PowerShell"
    $Toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(1)

    $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PowerShell")
    $Notifier.Show($Toast);
}

$process = Get-Process -Name "MSIAfterburner" -ErrorAction SilentlyContinue -ErrorVariable ProcessError
$processRiva = Get-Process -Name "RTSS" -ErrorAction SilentlyContinue -ErrorVariable ProcessError
$processHooksLoader = Get-Process -Name "RTSSHooksLoader64" -ErrorAction SilentlyContinue -ErrorVariable ProcessError
$processEncoderServer = Get-Process -Name "EncoderServer" -ErrorAction SilentlyContinue -ErrorVariable ProcessError

# If Process not opened: start MSI Afterburner
if ($null -eq $process) {
	Start-Process -WindowStyle Hidden "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe"
	$toasterText = "ON"
}
else {
	Stop-Process -Id $process.Id
	Stop-Process -Id $processRiva.Id
	Stop-Process -Id $processHooksLoader.Id
	Stop-Process -Id $processEncoderServer.Id
	$toasterText = "OFF"
}

# Show ON or OFF notification based on what's now the state of afterburner
Show-Notification -ToastTitle "Toggle MSI Afterburner" -ToastText $toasterText

Exit