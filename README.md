# AWS-Snapshots-Powershell
This script is created to take instant snapshots of specified volumes, tag them, and then determine whether snapshots can be deleted if there are two or more.

This has not been designed for bulk Volume snapshotting - each volume needs to have a block added manually. I mainly did it this way because when I tried doing it by pulling all the IDs it would snapshot one at a time. I needed them all to snapshot at the same time.
