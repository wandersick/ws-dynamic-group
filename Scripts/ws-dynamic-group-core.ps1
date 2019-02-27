# Script directory
# Example: c:\ws-dynamic-group
$scriptDir = "c:\ws-dynamic-group"

# CSV filename to process
$csvFile = "incoming.csv"

# Action to perform on usernames to groups
# Example: /add /del
$action = "/add"

# Create a new directory by randomizing a unique value made up of day time.
# Example: 20190227_095047AM
$currentDateTime = Get-Date -format "yyyyMMdd_hhmmsstt"

# Move 01_Incoming\incoming.csv to a directory of ransomized name inside 02_Processing
New-Item "$scriptDir\02_Processing\$currentDateTime" -Force -ItemType "directory"
Copy-Item "$scriptDir\01_Incoming\$csvFile" "$scriptDir\02_Processing\$currentDateTime\$csvFile" -Force
Remove-Item "$scriptDir\01_Incoming\$csvFile" -force 

# Backup existing group members to a log file

$users = import-csv "$ScriptDir\01_Incoming\incoming.csv"
ForEach ($user in $users){
    $username = $($users.username)
    $groupname = $($users.groupname)
    net localgroup `"$groupname`" `"$username`" $action
}

