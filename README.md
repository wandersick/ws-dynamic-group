# Dynamic Group (ws-dynamic-group)

* Monitor a flat file (CSV) for additions or removal of users in one or more groups (e.g. for scheduling using Task Scheduler)
* Dynamic and static input support
   * Dynamic: The CSV input file can be dynamically created according to an LDAP query (specified in the script) from a live Active Directory domain
   * Static: Users may also statically pre-create the CSV input file (in a location and filename defined in the script)
* Apply the changes (addition/deletion) to system accordingly, either locally (workgroup) or on a domain controller (Active Directory)
   * Support for both local (workgroup) and domain (Active Directory) environments (See [More Settings](#More-Settings) section below)

For details, see [Detailed Flow](#Detailed-Flow) section below.

# Getting Started

1. Place the script with its full [folder structure](#Folder-Structure) to a location specified in the script (By default: C:\ws-dynamic-group)
2. Create '01_Incoming\incoming.csv' according to [Flat File Schema](#Flat-File-Schema) section below
3. Create a Windows scheduled task which runs 'ws-dynamic-group-core.ps1'

# Requirements

* Windows or Windows Server which can execute PowerShell from required modules, where:
  * The PowerShell module, Microsoft.Powershell.LocalAccounts, is required for 'local' mode
  * The PowerShell module, ActiveDirectory, is required for 'domain' mode (and only Domain Controllers are supported)
* Groups has to be pre-created
  * If group(s) specified are not created, script cannot proceed
* Admin rights
  * Script has to be run with a user account in the 'Domain Admins' AD group for 'Domain' mode, or (local) 'Administrators' group 'Local' mode, in order to successfully add or delete users
* Requirements for 'static' input mode
  * incoming.csv has to be a full file containing all users (usernames) of the specified group(s) that needs to be processed.
    * For example, if only few usernames are in the CSV while the system actually has a lot of users, this will be treated as an intended deletion of the lot of users in the system unspecified in the CSV file
  * Also see notes under [Flat File Schema](#Flat-File-Schema) section


# Limitations

* For 'domain' mode, the script has to be executed on a domain controller (due to the use of 'net group' commands)
  * Use of Remote Server Administration Tools (RSAT) is unsupported
* Current version aims to just 'do the job'. It could use workarounds here and there. Performance is not its priority

# Flat File Schema

 Sample of flat file (01_Incoming\incoming.csv), where 'Groupname' column is optional and unused by dynamic LDAP input mode but static CSV input mode only:
```
Username[,Groupname]
testuser02[,"full-time students"]
testuser03[,"full-time students"]
testtutor01[,tutors]
testtutor02[,tutors]
```

Note:
* The top row (header) has to be Username (Groupname is optional and deprecated to be specifed via CSV. Specify it at the top of the script file instead)
* If group name is specified at the top of the script (i.e. at the [Settings](#Settings) section), it takes precedence. Any group name defined in the CSV has no effect
  * Only one group name is supported as defined at the top of the script
  * For static input mode, multiple group names can be defined in CSV if custom group name feature is disabled (set to false)
* Additional notes on the difference of input modes
  * For dynamic input mode ($inputMode = "dynamic"), the only way to define group name is via the top of the script
  * For static input mode ($inputMode = "static"), group names have to be defined for all users; each line of CSV must contain group name

# Folder Structure

The zip file should be extracted to below directory, so that the below folder structure is built:
```
C:\ws-dynamic-group
│
├───01_Incoming
│       incoming.csv // manually defined ('static' CSV input mode) or generated live (dynamic 'LDAP' input mode)
│
├───02_Processing
│
├───03_Done
│   │
│   └───20190312_030304PM
│           Completed // indication of completion of script
|           Completed_Backup_(Before) // indication of completion of script section: Backup (before)
|           Completed_Main_Logic // indication of completion of script section: Main Logic
|           Completed_Backup_(After) // indication of completion of script section: Backup (After)
│           incoming.csv
│           Domain|LocalGroupMemberAfter_full-time students.csv // optional: if enabled ($backupAfter is $true)
│           Domain|LocalGroupMemberAfter_tutors.csv // optional: as above
│           Domain|LocalGroupMemberBefore_full-time students.csv // optional: if enabled ($backupBefore is $true)
│           Domain|LocalGroupMemberBefore_tutors.csv // optional: as above
│
└───Scripts
        ws-dynamic-group-core.ps1
```
# Detailed Flow

This section describes the [folder structure](#Folder-Structure) and the main actions performed by each execution of the script.
1. Create a unique folder for each execution (to improve organization and avoid conflict)
   - Randomize a unique value made up of day time in milliseconds
2. Backup existing group members to a file
   - [Local|Domain]GroupMember**Before**_(groupName).csv
3. Acquire input
   - For 'dynamic' LDAP input mode, leverage specified LDAP query in the script to dynamically generate 'incoming.csv' in '01_Incoming' folder 
   - For 'static' CSV input mode, acquire 'incoming.csv' from '01_Incoming' folder (manually created by user) and move it to '02_Processing' folder for processing
4. Perform action (adding/removing users from groups) specified in CSV
   - Add users from CSV to local or AD group, if the users are in CSV but not in system
   - Remove users from existing groups, if the users are not in CSV but in system
5. Move completed folders to '03_Done' folder
6. Back up final group members to a file
   - [Local|Domain]GroupMember**After**_(groupName).csv
7. Write a file named 'Completed' to '03_Done' when the script ends

# Settings

Settings that can be modified at [Editable Settings] section in 'Scripts\ws-dynamic-group-core.ps1':

```PowerShell
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
$backupAfter = $false # Record final group members to a log file (Output File: GroupMemberAfter_GroupName.csv)

# ------- Settings - Input Source -------

# Input mode
# - Either case-insensitive 'static' (CSV) or 'dynamic' (LDAP)
#   - Static: Acquire CSV file precreated and pre-inputted by user in 01_Incoming directory
#   - Dynamic: Also ends up being a CSV file, but generated live via a LDAP filter from current Active Directory domain 
# - Note: dynamic LDAP input mode automatically assumes 'Domain' and overrides 'Local' directory Mode
# - Example 1: $inputMode = "Dynamic"
# - Example 2: $inputMode = "Static"
$inputMode = "Dynamic"

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
    $ldapFilter = ""

    # ------- Settings - Static Input Mode -------

    # CSV filename
    # - For processing inside 01_Incoming folder (used by static CSV input mode)
    # - Example: $csvFile = "incoming.csv"
    $csvFile = "incoming.csv"

# ------- Settings - Group Name Source -------

# Enable or disable custom group name feature - $true (enabled) or $false (disabled)
# - Determine how to acquire the group name
#   - If enabled, below $customGroupName is the group name and takes precedence over the CSV (if group name is defined in the CSV or not)
#   - If disabled, group name is acquired from CSV file (static input mode only)
# - If input mode is set to dynamic (LDAP), customGroup is automatically $true whatever input mode is set
# - Example: $customGroup = $false
$customGroup = $false

    # Custom group name (see above)
    # - One group name can be specified here in the script instead of CSV
    # - Supported for both dynamic LDAP input mode and static CSV input mode
    #   - For dynamic LDAP input mode, the only way to define group name is here
    #   - For static CSV input mode, it can be defined both here or manually in CSV
    # Example: $customGroupName = "tutors" 
    $customGroupName = "tutors"
```

# Release Notes

* Version 1.2 - 20190409
    * Performance enhancement
    * Script has been separated into three sections which can be optionally enabled: Backup (Before), Main Logic and Backup (After). For performance reasons, only
      * Main Logic is enabled by default
    * Within Main Logic, more granularity is achieved by further separating it into User Addition and User Deletion. Each of them can be enabled and run sequentially or in parallel as required
      * For example, two sets of the script with similar settings, with the only difference being set A having userAddition enabled and set B having userDeletion disabled, may be run in parallel to speed up user addition and deletion

* Version 1.1 - 20190315
    * Besides already supported method of statically creating CSV input file, dynamic LDAP input mode is now supported, where incoming.csv is generated according to a LDAP query specified in the script, live from current Active Directory domain

* Version 1.0 - 20190312
    * Monitor a flat file (CSV) for additions or removal of users in one or more groups (as a scheduled task)
    * Apply the changes to system accordingly, locally or on a domain controller (Active Directory)
    * Support local (workgroup) and domain (Active Directory) environments

# Tips

* Multiple instances can be achieved by creating multiple copies of the script in different locations
  * For example, the below sets of the script (scriptDir) can be created, each scheduled to run as required
    * C:\ws-dynamic-group\1, C:\ws-dynamic-group\2, C:\ws-dynamic-group\3...
* The script may be scheduled using built-in Task Scheduler of Windows or any other preferred way of start-up
* If Backup (Before) and Backup (After) are required but it is undesired to run them along with the Main Logic (increases processing time), a separate script may be used and scheduled solely for the Backup sections to run separately

