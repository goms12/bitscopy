Import-Module bitstransfer

function setBitsCopy
{
    param([String]$source, [String]$destination, [Int]$checkJob)
    $testOnly = 0
    $sleepSeconds = 3
    # Looping backdays for checkjob in the past $checkJob days
    for($j = 0; $j -ge $checkJob; $j--)
    {
        $copyPattern = (Get-Date).AddDays($j).ToString("yyyy_MM_dd")
        $files = Get-ChildItem -Path $source -Filter *$copyPattern* | Where-Object {$_.Name -notmatch '1205'} | Sort-Object Length
        Write-Host ("About to copy " + $files.Count + " files to " + $destination + " ...")

        #Looping for each files
        for($i = 0; $i -lt $files.Count; $i++)
        {
            $srcFile = $files[$i].FullName
            $dstFile = $destination + "\" + $files[$i].Name
            $getJob = Get-BitsTransfer -Name $files[$i].Name -ErrorAction SilentlyContinue
            Write-Host("Copying" + $srcFile)
            
            #Check the file already exist in destination or check the job already exist or not.
            #If 1 of this condition fullfilled, the job not generated.If two condition not fullfilled, the job created.
            If((Test-Path $dstFile) -or ($getJob.DisplayName -eq $files[$i].Name))
            {
                Write-Host("File or Job already exist: " + $dstFile)
            }
            Else
            {
                $bitsjob = Start-BitsTransfer -Source $srcfile -Destination $Destination -Asynchronous -Priority High -RetryInterval 60 -DisplayName $files[$i].Name -MaxDownloadTime 604800 -TransferType Upload 

                While(($bitsjob.JobState -eq "Transferring") -or ($bitsjob.JobState -eq "connecting") -or ($bitsjob -eq "TransientError"))
                {
                    #Write-Output $bitsjob.JobState
                    $bytetrf = ($bitsjob.BytesTransferred / $bitsjob.BytesTotal)
                    Write-Host ($bitsjob.JobState.ToString() + "-" + $("{0:P2}" -f $bytetrf))
                    Sleep $sleepSeconds
                }
                
                #Switch statement for handle the state for the bitstransfer job.
                Switch($bitsjob.JobState)
                {
                    "Transferred" 
                    {
                        Complete-BitsTransfer -BitsJob $bitsjob
                        #Add log
                        Add-Content D:\log_backup_$(get-date -Format "yyyy_MM").log -Value "`n $(Get-Date -Format yyyy-MM-dd)|$(Get-Date -UFormat %T)|Copied|$($files[$i].FullName)"
                    }
                    "Error" 
                    {
                        $bitsjob | Remove-BitsTransfer
                        $bitsjob = Start-BitsTransfer -Source $srcfile -Destination $Destination -Asynchronous -Priority High -RetryInterval 60 -DisplayName $files[$i].Name -MaxDownloadTime 604800 -TransferType Upload

                    } #List the errors
                    "Suspended" {Get-BitsTransfer | Resume-BitsTransfer}
                    default
                    {
                        Write-Output $bitsjob.JobState
                        "Begin Job"
                    }
                }
            } 
        } 
    } 
}

#Example function
setBitsCopy "\\192.168.XX.XX\database$\" "\\192.168.XX.XX\backup$\database" "-2"
