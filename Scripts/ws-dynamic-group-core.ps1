# Script directory
# Example: c:\ws-dynamic-group
$scriptDir = "c:\ws-dynamic-group"

# CSV filename to process
$csvFile = "incoming.csv"

# Create a new directory by randomizing a unique value made up of day time.
# Example: 20190227_095047AM
$currentDateTime = Get-Date -format "yyyyMMdd_hhmmsstt"

# Move 01_Incoming\incoming.csv to a directory of ransomized name inside 02_Processing
New-Item "$scriptDir\02_Processing\$currentDateTime" -Force -ItemType "directory"
Copy-Item "$scriptDir\01_Incoming\$csvFile" "$scriptDir\02_Processing\$currentDateTime\$csvFile" -Force
Remove-Item "$scriptDir\01_Incoming\$csvFile" -force 

# Import users and groups from CSV into an array
$csvItems = import-csv "$scriptDir\02_Processing\$currentDateTime\$csvFile"
# Alternative, for user deletion in sub-function
$csv2rrItems = import-csv "$scriptDir\02_Processing\$currentDateTime\$csvFile"

# Backup existing group members to a log file (Output File: GroupMemberBefore_GroupName.csv)
ForEach ($csvItem in $csvItems) {
    $csvGroupname = $($csvItems.groupname)
    Get-LocalGroup "$csvGroupname" | Get-LocalGroupMember | Export-CSV "$scriptDir\02_Processing\$currentDateTime\GroupMemberBefore_$csvGroupname.csv" -Force
}

# Enumberate each line from CSV
ForEach ($csvItem in $csvItems) {
    $csvUsername = $($csvItems.username)
    $csvGroupname = $($csvItems.groupname)

    # For the group being processed, acquire existing group members from it in current system into an array
    $sysGroupMembers = Get-LocalGroup "$csvGroupname" | Get-LocalGroupMember

    # Enumberate group members of the group from current system
    # For each username in CSV, compare with group member in current system
    ForEach ($sysGroupMember in $sysGroupMembers) {
        $userExistsInCsvAndSys = $false
        $sysGroupMemberName = $($sysGroupMembers.name)
        # Enumberate users from CSV (alternative variable) and DELETE existing users in system not found in CSV
        ForEach ($csv2Item in $csv2Items) {
            $csv2Username = $($csv2Items.username)
            if ($csv2Username -eq $sysGroupMemberName) {
                $userExistsInCsvAndSys = $true
            }
            if ($userExistsInCsvAndSys -eq $true) {
                # Break out of the ForEach loop if true to prevent from needless further processing
                Break
            }
        }
        # If user does not exist in CSV but in system, remove the user from group
        if ($userExistsInCsvAndSys -eq $false) {
            net localgroup `"$csvGroupname`" `"$sysGroupMember`" /del 
        }
    }
     # Perform action on user and group
     net localgroup `"$csvGroupname`" `"$csvUsername`" /add
}

# Record final group members to a log file (Output File: GroupMemberAfter_GroupName.csv)
ForEach ($csvItem in $csvItems) {
    $csvGroupname = $($csvItems.groupname)
    Get-LocalGroup "$csvGroupname" | Get-LocalGroupMember | Export-CSV "$scriptDir\02_Processing\$currentDateTime\GroupMemberAfter_$csvGroupname.csv" -Force
}

# Move processed folder to 03_Done
