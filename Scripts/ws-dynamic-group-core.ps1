# c:\ws-dynamic-group
$scriptDir = "c:\ws-dynamic-group"
# /add /del
$action = "/add"

$users = import-csv "$ScriptDir\01_Incoming\incoming.csv"
ForEach ($user in $users){
$username = $($users.username)
$groupname = $($users.groupname)
net localgroup `"$groupname`" `"$username`" $action
}