# Script directory
# Example: c:\ws-dynamic-group
$scriptDir = "c:\ws-dynamic-group"

# CSV filename to process
$csvFile = "incoming.csv"

# Action to perform on users and groups
# Example: /add /del
$action = "/add"

# Remove existing users from group (only effective when action="/add")
# Example: $true
$removeExUsersFromGroup = $true

# Create a new directory by randomizing a unique value made up of day time.
# Example: 20190227_095047AM
$currentDateTime = Get-Date -format "yyyyMMdd_hhmmsstt"

# Move 01_Incoming\incoming.csv to a directory of ransomized name inside 02_Processing
New-Item "$scriptDir\02_Processing\$currentDateTime" -Force -ItemType "directory"
Copy-Item "$scriptDir\01_Incoming\$csvFile" "$scriptDir\02_Processing\$currentDateTime\$csvFile" -Force
Remove-Item "$scriptDir\01_Incoming\$csvFile" -force 

$users = import-csv "$scriptDir\02_Processing\$currentDateTime\$csvFile"
ForEach ($user in $users){
    $username = $($users.username)
    $groupname = $($users.groupname)
    # Backup existing group members to a log file (Output File: ExistingGroupMemberBackup_GroupName.csv)
    Get-LocalGroup "$groupname" | Get-LocalGroupMember | Export-CSV "$scriptDir\02_Processing\$currentDateTime\ExistingGroupMemberBackup_$groupname.csv"
    # Perform action on user and group
    <# net localgroup `"$groupname`" `"$username`" $action #>
}
