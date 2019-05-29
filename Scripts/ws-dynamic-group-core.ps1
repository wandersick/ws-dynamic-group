# Name: ws-dynamic-group
# Version: 2.0
# Author: wandersick

# Descriptions: 
# - Monitor a flat file (CSV) for additions or removal of users in a local/domain group by comparing users in the file with users in a system
#   (For scheduling, add it to a task using Task Scheduler)
#   - If users exist in CSV but not in system, add the users
#   - If users exist in system but not in CSV, delete the users
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
$mainLogic = $true # Perform the main function of the script
    $userAddition = $true # Perform user addition for each user that is in CSV but not in system
    $userDeletion = $true # Perform user deletion for each user that is in system but not in CSV
$backupAfter = $true # Record final group members to a log file (Output File: GroupMemberAfter_GroupName.csv)

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
    $directoryMode = "Domain"

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

# ------- Settings - Group Name -------

# Custom group name
# - One group name can be specified here in each script
# Example: $customGroupName = "tutors" 
$customGroupName = "tutors"

# ---------------------------------------------------------------------------------

# [Main Body of Script]

# In static 'LDAP' input mode, it automatically assumes 'Domain' and overrides 'Local' directoryMode (if configured)
If ($inputMode -ieq 'Dynamic') {
    $directoryMode = "Domain"
    # Generate CSV from AD domain by running specified LDAP filter
    if ($mainLogic -eq $true) {
        Get-ADUser -LDAPFilter "$ldapFilter" | Select-Object -ExpandProperty SamAccountName > "$scriptDir\01_Incoming\$csvFile" 
    }
}

# Move 01_Incoming\incoming.csv to a directory of randomized name inside 02_Processing
New-Item "$scriptDir\02_Processing\$currentDateTime" -Force -ItemType "directory"
Copy-Item "$scriptDir\01_Incoming\$csvFile" "$scriptDir\02_Processing\$currentDateTime\$csvFile" -Force
Remove-Item "$scriptDir\01_Incoming\$csvFile" -force 

# Pre-create 03_Done directory
New-Item "$scriptDir\03_Done\$currentDateTime" -Force -Itemtype Directory

# -------------------------------------------------------------------------------------------
# [ Backup - Before ]
# -------------------------------------------------------------------------------------------

# Backup existing group members to a log file (Output File: GroupMemberBefore_GroupName.csv)
 
# Required to be true for Compare-Object since v2.0
$backupBefore = $true

if ($backupBefore -eq $true) {
    $csvGroupname = $customGroupName
    if ($directoryMode -ieq "Local") {
        Get-LocalGroup "$csvGroupname" | Get-LocalGroupMember | Select-Object -ExpandProperty Name > "$scriptDir\02_Processing\$currentDateTime\LocalGroupMemberBefore_$csvGroupname.csv"
    } elseif ($directoryMode -ieq "Domain") {
        Get-ADGroup "$csvGroupname" | Get-ADGroupMember | Select-Object -ExpandProperty Name > "$scriptDir\02_Processing\$currentDateTime\DomainGroupMemberBefore_$csvGroupname.csv" 
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
 
if ($mainLogic -eq $true) {
    if ($userAddition -eq $true) {

        # Take action on users who only exist in the CSV
        if ($directoryMode -ieq "Local") {
            # Instead of a try-catch block, `@(Get-Content file | Select-Object)` is in use to work around an issue in which `Compare-Object` outputs errors when the number of object to compare is zero
            $beingAddedUsers = Compare-Object @(Get-Content "$scriptDir\02_Processing\$currentDateTime\LocalGroupMemberBefore_$csvGroupname.csv" | Select-Object) @(Get-Content "$scriptDir\02_Processing\$currentDateTime\$csvFile" | Select-Object) | Where-Object {$_.SideIndicator -eq "=>"} | Select-Object -ExpandProperty inputObject
        } elseif ($directoryMode -ieq "Domain") {
            $beingAddedUsers = Compare-Object @(Get-Content "$scriptDir\02_Processing\$currentDateTime\DomainGroupMemberBefore_$csvGroupname.csv" | Select-Object) @(Get-Content "$scriptDir\02_Processing\$currentDateTime\$csvFile" | Select-Object) | Where-Object {$_.SideIndicator -eq "=>"} | Select-Object -ExpandProperty inputObject
        }

        ForEach ($beingAddedUser in $beingAddedUsers) {
            # Add user, who are only found in CSV but not in system, to the group '$customGroupName' defined at the top variable of this script
            if ($directoryMode -ieq "Local") {
                # Todo*: Add-LocalGroupMember -Group "" -Member ""
                net localgroup `"$customGroupName`" `"$beingAddedUser`" /add
            } elseif ($directoryMode -ieq "Domain") {
                # Todo*: Add-ADGroupMember -Identity "" -Members ""
                net group `"$customGroupName`" `"$beingAddedUser`" /add
                # *A workaround is currently in use to acquire correct variable content as `"...`". This requires traditional CLI commands
                #  Although this works, I left it as a todo for this part to be written in PowerShell without the workaround
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

        # Take action on users who only exist in the system but not in CSV
        if ($directoryMode -ieq "Local") {
            # Instead of a try-catch block, `@(Get-Content file | Select-Object)` is in use to work around an issue in which `Compare-Object` outputs errors when the number of object to compare is zero
            $beingDeletedUsers = Compare-Object @(Get-Content "$scriptDir\02_Processing\$currentDateTime\LocalGroupMemberBefore_$csvGroupname.csv" | Select-Object) @(Get-Content "$scriptDir\02_Processing\$currentDateTime\$csvFile" | Select-Object) | Where-Object {$_.SideIndicator -eq "<="} | Select-Object -ExpandProperty inputObject
        } elseif ($directoryMode -ieq "Domain") {
            $beingDeletedUsers = Compare-Object @(Get-Content "$scriptDir\02_Processing\$currentDateTime\DomainGroupMemberBefore_$csvGroupname.csv" | Select-Object) @(Get-Content "$scriptDir\02_Processing\$currentDateTime\$csvFile" | Select-Object) | Where-Object {$_.SideIndicator -eq "<="} | Select-Object -ExpandProperty inputObject
        }

        ForEach ($beingDeletedUser in $beingDeletedUsers) {
            # Add user, who are only found in system but not in CSV, to the group '$customGroupName' defined at the top variable of this script
            if ($directoryMode -ieq "Local") {
                # Todo*: Add-LocalGroupMember -Group "" -Member ""
                net localgroup `"$customGroupName`" `"$beingDeletedUser`" /del
            } elseif ($directoryMode -ieq "Domain") {
                # Todo*: Add-ADGroupMember -Identity "" -Members ""
                net group `"$customGroupName`" `"$beingDeletedUser`" /del
                # *A workaround is currently in use to acquire correct variable content as `"...`". This requires traditional CLI commands
                #  Although this works, I left it as a todo for this part to be written in PowerShell without the workaround
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
        Get-LocalGroup "$csvGroupname" | Get-LocalGroupMember | Select-Object -ExpandProperty Name > "$scriptDir\02_Processing\$currentDateTime\LocalGroupMemberAfter_$csvGroupname.csv"
    } elseif ($directoryMode -ieq "Domain") {
        Get-ADGroup "$csvGroupname" | Get-ADGroupMember | Select-Object -ExpandProperty Name > "$scriptDir\02_Processing\$currentDateTime\DomainGroupMemberAfter_$csvGroupname.csv"
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
