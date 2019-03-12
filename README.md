# Dynamic Group (ws-dynamic-group)

* Run as a scheduled task to monitor a flat file (CSV) for additions or removal of users in one or more groups
* Apply the changes to system accordingly, locally or on a domain controller (Active Directory)
* Support local (workgroup) and domain (Active Directory) environments (See [More Settings](#More-Settings) section below)

For details, see [Detailed Flow](#Detailed-Flow) section below.

# Getting Started

1. Git clone or download the files of this repository
2. Extract to c:\ws-dynamic-group (or a location specified in the script)
3. Create '01_Incoming\incoming.csv' according to [Flat File Schema](#Flat-File-Schema) section below
4. Create a Windows scheduled task which runs 'ws-dynamic-group-core.ps1'

# Requirements

* Windows or Windows Server which can execute PowerShell from required modules, where:
  * The PowerShell module, Microsoft.Powershell.LocalAccounts, is required for 'local' mode
  * The PowerShell module, ActiveDirectory, is required for 'domain' mode (and only Domain Controllers are supported)

# Limitations

* For 'domain' mode, the script has to be executed on a domain controller (due to the use of 'net group' commands).
  * Use of Remote Server Administration Tools (RSAT) is unsupported
* Current version aims to just 'do the job'. It could use workarounds here and there, and performance is not its priority due to the lack of the need to scale

# Flat File Schema

 Sample of Flat File (01_Incoming\incoming.csv):
```
Username,Groupname
testuser02,"full-time students"
testuser03,"full-time students"
testtutor01,tutors
testtutor02,tutors
```

# Folder Structure

The zip file should be extracted to below directory, so that the below folder structure is built:
```
C:\ws-dynamic-group
│
├───01_Incoming
│       incoming.csv
│
├───02_Processing
│
├───03_Done
│   │
│   └───20190312_030304PM
│           Completed
│           incoming.csv
│           LocalGroupMemberAfter_full-time students.csv
│           LocalGroupMemberAfter_tutors.csv
│           LocalGroupMemberBefore_full-time students.csv
│           LocalGroupMemberBefore_tutors.csv
│
└───Scripts
        ws-dynamic-group-core.ps1
```
# Detailed Flow

This section describes the [Folder Structure](#Folder-Structure) and the main actions performed by each execution of the script.
1. Create a unique folder for each execution (to improve organization and avoid conflict)
   - Randomize a unique value made up of day time in milliseconds
2. Backup existing group members to a file
   - [Local|Domain]GroupMemberBefore_(groupName).csv
3. Acquire 'incoming.csv' from '01_Incoming' folder and move it to '02_Processing' folder for processing
4. Perform action (add/delete) on users and groups specified in CSV
   - Add users from flat file to AD group
   - Delete users in existing groups which are not specified in CSV
5. Move completed folders to '03_Done' folder
6. Back up final group members to a file
   - [Local|Domain]GroupMemberAfter_(groupName).csv
7. Write a file named 'Completed' to '03_Done' when the script ends

# More Settings

Settings that can be modified at [Editable Settings] section in 'Scripts\ws-dynamic-group-core.ps1':

```PowerShell
# [Editable Settings]

# Script directory
# Example: c:\ws-dynamic-group where this script can be located at c:\ws-dynamic-group\Scripts\ws-dynamic-group-core.ps1
$scriptDir = "c:\ws-dynamic-group"

# CSV filename to process
$csvFile = "incoming.csv"

# 'Local' (workgroup) or 'Domain' mode - this scripts support local (workgroup) mode where local group would be enumerated, or domain mode which is only supported to be run on a domain controller (RSAT is unsupported due to the use of "net group" command)
$directoryMode = "Local"

# Create a new directory by randomizing a unique value made up of day time.
# Example: 20190227_095047AM
$currentDateTime = Get-Date -format "yyyyMMdd_hhmmsstt"
```

# Release Notes

* Version 1.0 - 20190312
    * Monitor a flat file (CSV) for additions or removal of users in one or more groups (as a scheduled task)
    * Apply the changes to system accordingly, locally or on a domain controller (Active Directory)
    * Support local (workgroup) and domain (Active Directory) environments