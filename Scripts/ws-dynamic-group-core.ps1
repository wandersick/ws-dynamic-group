# Script directory
# Example: c:\ws-dynamic-group
$scriptDir = "c:\ws-dynamic-group"

# CSV filename to process
$csvFile = "incoming.csv"

# 'Local' (workgroup) or 'Domain' mode - this scripts support workgroup mode where local group would be enumerated
$directoryMode = "Local"

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
$csv2Items = import-csv "$scriptDir\02_Processing\$currentDateTime\$csvFile"

# Backup existing group members to a log file (Output File: GroupMemberBefore_GroupName.csv)
ForEach ($csvItem in $csvItems) {
    $csvGroupname = $($csvItem.groupname)
    if ($directoryMode -ieq "Local") {
        Get-LocalGroup "$csvGroupname" | Get-LocalGroupMember | Export-CSV "$scriptDir\02_Processing\$currentDateTime\LocalGroupMemberBefore_$csvGroupname.csv" -Force
    } elseif ($directoryMode -ieq "Domain") {
        Get-ADGroup "$csvGroupname" | Get-ADGroupMember | Export-CSV "$scriptDir\02_Processing\$currentDateTime\DomainGroupMemberBefore_$csvGroupname.csv" -Force 
    }
}

# Enumberate each line from CSV
ForEach ($csvItem in $csvItems) {
    $csvUsername = $($csvItem.username)
    $csvGroupname = $($csvItem.groupname)

    # For the group being processed, acquire existing group members from it in current system into an array
    if ($directoryMode -ieq "Local") {
        $sysGroupMembers = Get-LocalGroup "$csvGroupname" | Get-LocalGroupMember
    } elseif ($directoryMode -ieq "Domain") {
        $sysGroupMembers = Get-ADGroup "$csvGroupname" | Get-ADGroupMember
    }

    # Enumberate group members of the group from current system
    # For each username in CSV, compare with group member in current system
    ForEach ($sysGroupMember in $sysGroupMembers) {
        $userSysCheck = $false
        $sysGroupMemberName = $($sysGroupMember.name).split("\\")[-1]
        # Enumberate users from CSV (alternative variable) and DELETE existing users in system not found in CSV
        ForEach ($csv2Item in $csv2Items) {
            $csv2Username = $($csv2Item.username)
 
            if ($sysGroupMemberName -eq $csv2Username) {
                $userSysCheck = $true
            }
 
            if ($userSysCheck -eq $true) {
                # Break out of the ForEach loop if true to prevent from needless further processing
                Break
            }
        }
        # In case user does not exist in CSV but in system, remove the user from group in system.
        # This won't apply to users who exist in CSV and in system to prevent interruption to the users
        if ($userSysCheck -eq $false) {
            if ($directoryMode -ieq "Local") {
                # Retired: net localgroup `"$csvGroupname`" `"$sysGroupMember`" /del 
                Remove-LocalGroupMember -Group "$csvGroupname" -Member "$sysGroupMember"
            } elseif ($directoryMode -ieq "Domain") {
                Remove-ADGroupMember -Identity "$csvGroupname" -Members "$sysGroupMember"
            }
        }
    }
     # Perform usersadd action on user and group

     # This also applies to users who already exist in CSV and in system, so there can be harmless error messages that can be safely ignored:
     # "System error 1378 has occurred." "The specified account name is already a member of the group"
     if ($directoryMode -ieq "Local") {
        # Retired: net localgroup `"$csvGroupname`" `"$csvUsername`" /add
        Add-LocalGroupMember -Group "$csvGroupname" -Member "$sysGroupMember"
    } elseif ($directoryMode -ieq "Domain") {
        Add-ADGroupMember -Identity "$csvGroupname" -Members "$sysGroupMember"
    }
    
}

# Record final group members to a log file (Output File: GroupMemberAfter_GroupName.csv)
ForEach ($csvItem in $csvItems) {
    $csvGroupname = $($csvItem.groupname)
    if ($directoryMode -ieq "Local") {
        Get-LocalGroup "$csvGroupname" | Get-LocalGroupMember | Export-CSV "$scriptDir\02_Processing\$currentDateTime\LocalGroupMemberAfter_$csvGroupname.csv" -Force
    } elseif ($directoryMode -ieq "Domain") {
        Get-ADGroup "$csvGroupname" | Get-ADGroupMember | Export-CSV "$scriptDir\02_Processing\$currentDateTime\DomainGroupMemberAfter_$csvGroupname.csv" -Force
    }
}

# Move processed folder to 03_Done
Copy-Item "$scriptDir\02_Processing\$currentDateTime\" "$scriptDir\03_Done\$currentDateTime\" -Recurse -Force
Remove-Item "$scriptDir\02_Processing\$currentDateTime\" -Recurse -Force

# Write dummy file to 'Processed' folder to signal completion of script
Write-Output "The existence of this file indicates the script has been run until the end." | Out-File "$scriptDir\03_Done\$currentDateTime\Completed"