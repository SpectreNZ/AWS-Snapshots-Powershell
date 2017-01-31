# Check if an event log source for this script exists; create one if it doesn't.
function logsetup {
	if (!([System.Diagnostics.EventLog]::SourceExists('AWS PowerShell Utilities')))
		{ New-Eventlog -LogName "Application" -Source "AWS PowerShell Utilities" }
}

#Sets the access credentials of the Amazon account and stores as Snapshots profile. This is using the Snasphots user.
Set-AWSCredentials -AccessKey XXXXXXXXXXXXXX -SecretKey XXXXXXXXXXXXXXX -StoreAs Snapshots

#Sets the profile as Snapshots to ensure it runs
Set-AWSCredentials -ProfileName Snapshots

#Set Region
Set-DefaultAWSRegion -Region XXXXXXXX

#Add backupDate parameter to add time to snapshot description
$backupDate = Get-Date -f 'F'

#Execute snapshots
try
{
    #Take the snapshot of the specific volume ID for a drive on the instance - stops if Error happens and proceeds to Catch
    $snapshotSERVERNAME = New-EC2Snapshot -VolumeId vol-XXXXXXX -Description "$backupDate" -ErrorAction Stop
	#Add name of server as tag to snapshot
	New-ec2tag -ResourceId $snapshotSERVERNAME.SnapshotId -Tag @{Key="Name"; Value="SERVERNAME"} -ErrorAction Stop
	#Add tag of Automatic to Snapshot for retention
	New-ec2tag -ResourceId $snapshotSERVERNAME.SnapshotId -Tag @{Key="Automatic"; Value="Yes"} -ErrorAction Stop

	#Write success to Event log
	write-eventlog -Logname "Application" -EntryType "Information" -EventID 1 -Source "AWS PowerShell Utilities" -Message "SERVERNAME AWS Snapshot Successful"
}
catch
{
	#Catch the error
	$ErrorMessage = $_.Exception.Message

	#Catch the error
    $FailedItem = $_.Exception.ItemName

	#Write Failure to Event log
	write-eventlog -Logname "Application" -EntryType "Information" -EventID 0 -Source "AWS PowerShell Utilities" -Message "Cloud6 AWS EU Snapshot Failure - Please Investigate: $FailedItem $ErrorMessage"
}

#Rinse and repeat for next Cloud
#Copy and paste from Try and Catch and change Volume ID's ect to snapshot additional volumes


##########################################################################################################
#
# Retention
#
##########################################################################################################

#This will keep the latest 2 snapshots. Change the -gt 2 to another number to keep the latest X snapshots etc.


#Get list of snapshots with the tags: Name: Automatic Value: Yes
$Snapshots = Get-EC2Snapshot | ? { $_.Tags.Count -gt 0 -and $_.Tags.Key -eq "Automatic" -and $_.Tags.Value -eq "Yes" }

#Ties the snapshots back to a Volume ID - so we can determine how many snapshots there are for the volume
$objects = ($Snapshots | Group-Object -Property volumeid).name
foreach ($object in $objects)
{
	$volume_snapshots = $Snapshots | Where-Object {$_.volumeid -eq $object}
		IF($volume_snapshots.count -gt 2)
			{
				$volume_snapshots_to_remove = $volume_snapshots | sort starttime | select -First ($volume_snapshots.count - 2)
				Foreach($snapshot in $volume_snapshots_to_remove)
				{
					Try 
					{
					Remove-EC2Snapshot -SnapshotId $snapshot.SnapshotId -Force
					write-eventlog -Logname "Application" -EntryType "Information" -EventID 66 -Source "AWS PowerShell Utilities" -Message "Snapshots Removed Successfully $volume_snapshots_to_remove"
					}
					
					catch 
					{
					#Catch the error
					$ErrorMessage = $_.Exception.Message
					#Catch the error
					$FailedItem = $_.Exception.ItemName
					#Write Failure to Event log
					write-eventlog -Logname "Application" -EntryType "Information" -EventID 67 -Source "AWS PowerShell Utilities" -Message "Snapshot Deletion Failed - Please Investigate: $FailedItem $ErrorMessage"
					}
				}
			}
		Else
		{
		write-eventlog -Logname "Application" -EntryType "Information" -EventID 68 -Source "AWS PowerShell Utilities" -Message "No Snapshots to Delete"
		}
}
