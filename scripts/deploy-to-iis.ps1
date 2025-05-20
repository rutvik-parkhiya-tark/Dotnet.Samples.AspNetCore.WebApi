param (
    [string]$SourcePath,
    [string]$SiteName,
    [string]$DestinationPath = ""
)

Import-Module WebAdministration

# Set default destination path if not provided
if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
    $DestinationPath = Join-Path -Path $PSScriptRoot -ChildPath $SiteName
}

# Validate paths
if (-not (Test-Path $SourcePath)) {
    Write-Error "Source path '$SourcePath' does not exist."
    return
}

if (-not (Get-Website -Name $SiteName -ErrorAction SilentlyContinue)) {
    Write-Error "Website '$SiteName' does not exist."
    return
}

# Ensure destination folder exists
if (-not (Test-Path $DestinationPath)) {
    New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
}

# Set folder permissions
$appPoolName = (Get-Website -Name $SiteName).ApplicationPool
Write-Host "Resolved App Pool Name: $appPoolName"

# Stop app pool and site before deployment
Write-Host "Stopping site '$SiteName' and app pool '$appPoolName'..."
# Stop the app pool only if it's running
if ((Get-WebAppPoolState -Name $appPoolName).Value -eq "Started") {
    Stop-WebAppPool -Name $appPoolName
    Write-Host "App pool '$appPoolName' stopped."
} else {
    Write-Host "App pool '$appPoolName' is already stopped."
}

# Stop the site only if it's running
if ((Get-Website -Name $SiteName).State -eq "Started") {
    Stop-Website -Name $SiteName
    Write-Host "Website '$SiteName' stopped."
} else {
    Write-Host "Website '$SiteName' is already stopped."
}


$acl = Get-Acl $DestinationPath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS AppPool\$appPoolName", "Read,ReadAndExecute,ListDirectory", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($rule)
Set-Acl $DestinationPath $acl
Write-Host "Permissions set for IIS AppPool\$appPoolName on $DestinationPath."

# Clean and copy files
Remove-Item "$DestinationPath\*" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$SourcePath\*" -Destination $DestinationPath -Recurse -Force
Write-Host "Published files copied from $SourcePath to $DestinationPath."

# Restart or start app pool
if ((Get-WebAppPoolState -Name $appPoolName).Value -eq "Stopped") {
    Start-WebAppPool -Name $appPoolName
    Write-Host "App pool '$appPoolName' was stopped and has been started."
} else {
    Restart-WebAppPool -Name $appPoolName
    Write-Host "App pool '$appPoolName' restarted."
}

# Ensure website is started
if ((Get-Website -Name $SiteName).State -ne "Started") {
    Start-Website -Name $SiteName
    Write-Host "Website '$SiteName' started."
} else {
    Write-Host "Website '$SiteName' is already running."
}


Write-Host "==== Deployment completed! ===="
