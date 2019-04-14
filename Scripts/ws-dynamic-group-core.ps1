# Name: ws-dynamic-group
# Version: 1.3
# Author: wandersick

# Descriptions: 
# - Monitor a flat file (CSV) for additions or removal of users in a group (e.g. for scheduling using Task Scheduler)
# - Specify usernames dynamically or statically
#   - Dynamic: The CSV input file can be dynamically created according to an LDAP query (specified in the script) from a live Active Directory domain
#   - Static: Users may also statically pre-create the CSV input file (in a location and filename defined in the script)
# - Specify group name at the top variable section of the script
# - Apply the changes (addition/deletion) to system accordingly, either locally (workgroup) or on a domain controller (Active Directory)
#   - There is support for both local (workgroup) and domain (Active Directory) environments

# More Details: https://github.com/wandersick/ws-dynamic-group

# ---------------------------------------------------------------------------------

# [Editable Settings]

# ------- General Settings -------

# Script directory
# - Determine the working directory of the script and the relative path
# - Tip: If multiple instances are required, create copies of the script folder structure and set each scriptDir to be:
#   - Example 1: "c:\ws-dynamic-group\1" (where this script can be located at c:\ws-dynamic-group\Scripts\1\ws-dynamic-group-core.ps1)
#   - Example 2: "c:\ws-dynamic-group\2" (and so on)
$scriptDir = "c:\ws-dynamic-group"

# Format of date and time 
# - Used for uniquely naming and creating a new directory on each run by randomizing a value made up of day time
# - Example: Get-Date -format "yyyyMMdd_hhmmsstt" (e.g. "20190227_095047AM")
$currentDateTime = Get-Date -format "yyyyMMdd_hhmmsstt"

# ------- Section(s) of Script to Run -------
# 
$backupBefore = $false # Backup existing group members to a log file (Output File: GroupMemberBefore_GroupName.csv)
$mainLogic = $true # Perform the main function of the script
    $userAddition = $true # Perform user addition for each user that is in CSV but not in system
    $userDeletion = $true # Perform user deletion for each user that is in system but not in CSV
$backupAfter = $false # Record final group members to a log file (Output File: GroupMemberAfter_GroupName.csv)

# ------- Settings - Input Source -------

# Input mode
# - Either case-insensitive 'static' (CSV) or 'dynamic' (LDAP)
#   - Static: Acquire CSV file precreated and pre-inputted by user in 01_Incoming directory
#   - Dynamic: Also ends up being a CSV file, but generated live via a LDAP filter from current Active Directory domain 
# - Note: dynamic LDAP input mode automatically assumes 'Domain' and overrides 'Local' directory Mode
# - Example 1: $inputMode = "Dynamic"
# - Example 2: $inputMode = "Static"
$inputMode = "Static"

    # Directory mode (for both input modes)
    # - Determine whether to interact with local (workgroup) or domain (AD) authentication provider
    # - Either case-insensitive 'Local' or 'Domain'
    #   - 'Local' (workgroup) directory mode where local group would be enumerated,
    #   - 'Domain' directory mode which is only supported to be run on a domain controller
    # - Note: If input mode is set to dynamic (LDAP), this has no effect and is automatically assumed to be "Domain"
    # - Example 1: $directoryMode = "Local"
    # - Example 2: $directoryMode = "Domain"
    $directoryMode = "Local"

    # ------- Settings - Dynamic Input Mode -------

    # LDAP filter
    # - Acquire a list of users from AD domain to generate a CSV file for further processing (used by dynamic LDAP input mode)
    # - Example 1: (samAccountName=s9999*)
    # - Example 2: ((mailNickname=id*)(whenChanged>=20180101000000.0Z))(|(userAccountControl=514))(|(memberof=CN=VIP,OU=Org,DC=test,DC=com)))
    $ldapFilter = "(samAccountName=*)"

    # ------- Settings - Static Input Mode -------

    # CSV filename
    # - For processing inside 01_Incoming folder (used by static CSV input mode)
    # - Example: $csvFile = "incoming.csv"
    $csvFile = "incoming.csv"

# ------- Settings - Group Name Source -------

# Custom group name
# - One group name can be specified here in each script
# Example: $customGroupName = "tutors" 
$customGroupName = "tutors"

# ---------------------------------------------------------------------------------

# [Main Body of Script]

# In static 'LDAP' input mode, it automatically assumes 'Domain' and overrides 'Local' directoryMode (if configured)
If ($inputMode -ieq 'Dynamic') {
    $directoryMode = "Domain"
    # Generate CSV from AD domain by running specified LDAP filter, adding 'Username' (literally) to the top row
    if ($mainLogic -eq $true) {
        Get-ADUser -LDAPFilter "$ldapFilter" | Select-Object SamAccountName | ConvertTo-CSV -NoTypeInformation -Delimiter "," | ForEach-Object {$_ -replace '"',''} | ForEach-Object {$_ -replace 'SamAccountName','Username'} > "$scriptDir\01_Incoming\$csvFile" 
    }
}

# Move 01_Incoming\incoming.csv to a directory of randomized name inside 02_Processing
New-Item "$scriptDir\02_Processing\$currentDateTime" -Force -ItemType "directory"
Copy-Item "$scriptDir\01_Incoming\$csvFile" "$scriptDir\02_Processing\$currentDateTime\$csvFile" -Force
Remove-Item "$scriptDir\01_Incoming\$csvFile" -force 

# Pre-create 03_Done directory
New-Item "$scriptDir\03_Done\$currentDateTime" -Force -Itemtype Directory

if ($mainLogic -eq $true) {
    # Import users and groups from CSV into an array
    $csvItems = import-csv "$scriptDir\02_Processing\$currentDateTime\$csvFile"
}

# -------------------------------------------------------------------------------------------
# [ Backup - Before ] 
# -------------------------------------------------------------------------------------------

# Backup existing group members to a log file (Output File: GroupMemberBefore_GroupName.csv)

if ($backupBefore -eq $true) {
    $csvGroupname = $customGroupName
    if ($directoryMode -ieq "Local") {
        Get-LocalGroup "$csvGroupname" | Get-LocalGroupMember | Export-CSV "$scriptDir\02_Processing\$currentDateTime\LocalGroupMemberBefore_$csvGroupname.csv" -Force
    } elseif ($directoryMode -ieq "Domain") {
        Get-ADGroup "$csvGroupname" | Get-ADGroupMember | Export-CSV "$scriptDir\02_Processing\$currentDateTime\DomainGroupMemberBefore_$csvGroupname.csv" -Force 
    }
}

# Write dummy file to 'Processed' folder to signal completion of backup (before)
if ($backupBefore -eq $true) {
    Write-Output "The existence of this file indicates the backup (before) has been run." | Out-File "$scriptDir\03_Done\$currentDateTime\Completion_Backup_(Before)" -Force
}

# -------------------------------------------------------------------------------------------
# [ Main Logic ] 
# -------------------------------------------------------------------------------------------

# [ User Addition ] 
 
# Enumerate each line from CSV
if ($mainLogic -eq $true) {
    if ($userAddition -eq $true) {
        ForEach ($csvItem in $csvItems) {
            $csvUsername = $($csvItem.username)
            # Acquire the group name from the top variable of this script
            $csvGroupname = $customGroupName

            # For the group being processed, acquire existing group members from it in current system into an array
            if ($directoryMode -ieq "Local") {
                $sysGroupMembers = Get-LocalGroup "$csvGroupname" | Get-LocalGroupMember
            } elseif ($directoryMode -ieq "Domain") {
                $sysGroupMembers = Get-ADGroup "$csvGroupname" | Get-ADGroupMember
            }

            # Enumerate group members of the group from current system
            # For each username in CSV, compare with group member in current system
            $userToAdd = $true
            ForEach ($sysGroupMember in $sysGroupMembers) {           
                $sysGroupMemberName = $($sysGroupMember.name).split("\\")[-1]
                if ($sysGroupMemberName -eq $csvUsername) {
                    # User already exists in system and CSV
                    $userToAdd = $false
                }
            }

            # Perform user addition action on user and group

            # This does not apply to users who already exist in CSV and in system
            if ($userToAdd -eq $true) {
                if ($directoryMode -ieq "Local") {
                    # Todo*: Add-LocalGroupMember -Group "" -Member ""
                    net localgroup `"$csvGroupname`" `"$csvUsername`" /add
                } elseif ($directoryMode -ieq "Domain") {
                    # Todo*: Add-ADGroupMember -Identity "" -Members ""
                    net group `"$csvGroupname`" `"$csvUsername`" /add
                    # *A workaround is currently in use to acquire correct variable content as `"...`". This requires traditional CLI commands
                    #  Although this works, I left it as a todo for this part to be written in PowerShell without the workaround
                }
            }
            
        }
        # Write dummy file to 'Processed' folder to signal completion of main logic - user addition
        Write-Output "The existence of this file indicates the main logic - user addition has been run." | Out-File "$scriptDir\03_Done\$currentDateTime\Completion_Main_Logic-User_Addition" -Force
    }
}

# [ User Deletion ] 

# Enumerate group members of the group from current system
if ($mainLogic -eq $true) {
    if ($userDeletion -eq $true) {
        # Acquire the group name from top of script
        $csvGroupname = $customGroupName

        # For the group being processed, acquire existing group members from it in current system into an array
        if ($directoryMode -ieq "Local") {
            $sysGroupMembers = Get-LocalGroup "$csvGroupname" | Get-LocalGroupMember
        } elseif ($directoryMode -ieq "Domain") {
            $sysGroupMembers = Get-ADGroup "$csvGroupname" | Get-ADGroupMember
        }
        
        ForEach ($sysGroupMember in $sysGroupMembers) {
            $sysGroupMemberName = $($sysGroupMember.name).split("\\")[-1]

            # Enumerate group members of the group from CSV
            # For each username in system, compare with group member in CSV
            $userToKeep = $false
            ForEach ($csvItem in $csvItems) {
                $csvUsername = $($csvItem.username)
                if ($csvUsername -eq $sysGroupMemberName) {
                    # User already exists in CSV and system
                    $userToKeep = $true
                }
            }

            # Perform user deletion action on user and group

            # DELETE existing users in system not found in CSV
            # In case user does not exist in CSV but in system, remove the user from group in system.
            # This won't apply to users who exist in CSV and in system to prevent interruption to the users
            if ($userToKeep -eq $false) {
                if ($directoryMode -ieq "Local") {
                    # Todo*: Remove-LocalGroupMember -Group "" -Member ""
                    net localgroup `"$csvGroupname`" `"$sysGroupMember`" /del 
                } elseif ($directoryMode -ieq "Domain") {
                    # Todo*: Remove-ADGroupMember -Identity "" -Members ""
                    net group `"$csvGroupname`" `"$sysGroupMemberName`" /del
                }
            }
        }
        # Write dummy file to 'Processed' folder to signal completion of main logic - user deletion
        Write-Output "The existence of this file indicates the main logic - user deletion has been run." | Out-File "$scriptDir\03_Done\$currentDateTime\Completion_Main_Logic-User_Deletion" -Force
    }
}


# Write dummy file to 'Processed' folder to signal completion of main logic
if ($mainLogic -eq $true) {
    Write-Output "The existence of this file indicates the main logic has been run." | Out-File "$scriptDir\03_Done\$currentDateTime\Completion_Main_Logic" -Force
}

# -------------------------------------------------------------------------------------------
# [ Backup - After ] 
# -------------------------------------------------------------------------------------------

# Record final group members to a log file (Output File: GroupMemberAfter_GroupName.csv)
if ($backupAfter -eq $true) {
    $csvGroupname = $customGroupName
    if ($directoryMode -ieq "Local") {
        Get-LocalGroup "$csvGroupname" | Get-LocalGroupMember | Export-CSV "$scriptDir\02_Processing\$currentDateTime\LocalGroupMemberAfter_$csvGroupname.csv" -Force
    } elseif ($directoryMode -ieq "Domain") {
        Get-ADGroup "$csvGroupname" | Get-ADGroupMember | Export-CSV "$scriptDir\02_Processing\$currentDateTime\DomainGroupMemberAfter_$csvGroupname.csv" -Force
    }
}

# Write dummy file to 'Processed' folder to signal completion of backup (after)
if ($backupAfter -eq $true) {
    Write-Output "The existence of this file indicates the backup (after) has been run." | Out-File "$scriptDir\03_Done\$currentDateTime\Completion_Backup_(After)" -Force
}

# Move processed folder to 03_Done
Copy-Item "$scriptDir\02_Processing\$currentDateTime\" "$scriptDir\03_Done\$currentDateTime\" -Recurse -Force
Remove-Item "$scriptDir\02_Processing\$currentDateTime\" -Recurse -Force

# Write dummy file to 'Processed' folder to signal completion of script
Write-Output "The existence of this file indicates the script has been run until the end." | Out-File "$scriptDir\03_Done\$currentDateTime\Completion_Script" -Force
