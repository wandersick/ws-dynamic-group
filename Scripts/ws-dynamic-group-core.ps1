# Script Directory
# Example: c:\ws-dynamic-group
$scriptDir = "c:\ws-dynamic-group"

# Action to perform on usernames to groups
# Example: /add /del
$action = "/add"

# Create a new directory by randomizing a unique value made up of day time.
# Example: 20190227_095047AM
$currentDateTime = Get-Date -format "yyyyMMdd_hhmmsstt"

# Backup existing group members to a log file

<# $users = import-csv "$ScriptDir\01_Incoming\incoming.csv"
ForEach ($user in $users){
    $username = $($users.username)
    $groupname = $($users.groupname)
    net localgroup `"$groupname`" `"$username`" $action
} #>

