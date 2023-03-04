
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop";
$PrivateKey = "glpat-irT7vscDKVPZnFNznvog";
$Headers = @{ 'PRIVATE-TOKEN'=$PrivateKey };
$JobCount = 25;
$JobTimer = 220;
$GitLabApiUrl = "https://gitlab.taxcom.ru/api/v4";
$GitLabApiprojectId = "/projects/352";
$GitlabApiPipelinesPart = "/pipelines/";
$GitlabApiJobPart = "/jobs/";
$GitlabApiPartCom = "/repository/commits/";
$FeatureTrim  = ($ENV:gitlabBranch).TrimStart("feature/");
$TrimValue = $FeatureTrim;
$GitlabMergeRequestLastCommit =  $ENV:gitlabMergeRequestLastCommit;
$GetgitlabActionType = $ENV:gitlabActionType;
$GitLabBranch = $ENV:gitlabBranch;
$SourceOrioMkTwo = "\\RandomMachine\Builds\RandomFolder\";
$SourceInstallerOrioMkTwo = "\\RandomMachine\Builds\Tests\"
Write-host "gitlab action type - " $GetgitlabActionType;
 
$JobNamefeature = "Success (feature)";
$JobNameIntegrated = "Success (integrated)";
$JobNameRelease = "Success (release)";

$InstallPathAgent = $SourceOrioMkTwo + $TrimValue + '\Windows\Installer.exe';
write-host -BackgroundColor DarkMagenta "Installer agent path -" $InstallPathAgent;

$DestinationAgent = $SourceInstallerOrioMkTwo + "InstallFile";
write-host -BackgroundColor DarkMagenta "DestinationAgent Tests path -" $DestinationAgent;

$SourceTests = $SourceOrioMkTwo + $TrimValue + '\Windows\WindowsTestsNew';
write-host -BackgroundColor DarkMagenta "source Tests path -" $SourceTests;
$DestinationForNewTests = "C:\tools\WindowsTestsNew";
write-host -BackgroundColor DarkMagenta "Destination For New Tests path -" $DestinationForNewTests;

Write-host 'Handler for gitlabBranch'
write-host "gitlabMergecommit -" $GitlabMergeRequestLastCommit;
write-host 'feature get taxag -' $featureTrim;
write-host  'trim taxag -' $TrimValue;

$UrlCommit = $GitLabApiUrl + $GitLabApiprojectId + $GitlabApiPartCom + $GitlabMergeRequestLastCommit;
write-host -BackgroundColor Green -ForegroundColor Black $UrlCommit;
  
if($GitLabBranch -eq "master")
{
    Write-Error -Message "this branch don't need tests -" $GitLabBranch -ErrorAction Stop;
    Exit;
}

$WebResponseCommit = Invoke-WebRequest -Method Get -Uri $UrlCommit -Headers $Headers; 

<# Parsing the response in Json #>
$KeyValueCommit = ConvertFrom-json $WebResponseCommit.Content; 
$CommitMessage = $KeyValueCommit.message ;
Write-Host $CommitMessage;

if($WebResponseCommit.StatusCode -ne '200')
{
    Write-Error -Message "Status code invaled(need 200) -"  $WebResponseCommit.StatusCode;
    Exit;
}

if($GetgitlabActionType -ne "PUSH")
{
  Write-Error -Message $GetgitlabActionType "Action type wrong";
  Exit;
}

if($CommitMessage -ne "needAutoTest")
{
   currentBuild.rawBuild.@result = hudson.model.Result.SUCCESS
  
}
<# Get the commit by last commit #>

   
<# Extract the pipelineId #>
    $PipeId = $KeyValueCommit.last_pipeline.id;
    Write-Host = "pipeid -" $PipeId;

    $UrlJobsPipeline = $GitLabApiUrl + $GitLabApiprojectId + $GitlabApiPipelinesPart + $PipeId + $GitlabApiJobPart;
    write-host -BackgroundColor Green -ForegroundColor Black $UrlJobsPipeline;

<# Extract all jobs with PipelineId #>
    
    $WebResponsePipelineJobs = Invoke-WebRequest -Method Get -Uri $UrlJobsPipeline -Headers $Headers; 
    $ConvertJobsToJson = ConvertFrom-json $WebResponsePipelineJobs.Content;
    
    Write-host "all jobs with - "$PipeId;
        
<# Loop through the entire API response in search of TaxcomAgentTestsWin #>
  :checkResponse foreach($StageEnd in $ConvertJobsToJson)
  {
<# When the required job is found by name, take its id #>
    if($StageEnd.name -eq $JobNamefeature -or $StageEnd.name -eq $JobNameIntegrated -or $StageEnd.name -eq $JobNameRelease)
    {
     Write-host "-----------------";    
     Write-host -ForegroundColor Blue "our job: Job ID -" $StageEnd.id "Job Name -" $StageEnd.name;
     Write-host -BackgroundColor Green -ForegroundColor Blue "job id - "$StageEnd.id;   
     Write-host "job stage - "$StageEnd.stage;
     Write-host "job status - "$StageEnd.status;
     Write-host "job name - "$StageEnd.name;
     Write-host "-----------------";    
     break checkResponse;
    }
   }
   
<# Handler for checking the Job state #>

 $i = 0
 While($i -ne $JobCount)
 {
<# Make a request by job id #>
  try{

  $UrlJob = $GitLabApiUrl + $GitLabApiprojectId + $GitlabApiJobPart + $stageEnd.id
  Write-host -BackgroundColor Green -ForegroundColor Black "urlJob" $UrlJob;
  
  $webResponseJob = Invoke-WebRequest -Method Get -Uri $UrlJob -Headers $headers 
  $keyValueJob = ConvertFrom-json $webResponseJob.Content;

  $saveStatus = $keyValueJob.status;
  Write-host "keyValueJob status" -BackgroundColor Green -ForegroundColor Black $saveStatus;

  $saveName = $keyValueJob.name;
  Write-host "keyValueJob name" -BackgroundColor Green -ForegroundColor Black $saveName;

  $saveId = $keyValueJob.id;
  Write-host "keyValueJob id" -BackgroundColor Green -ForegroundColor Black $saveId;

  
  $savePipelineId = $keyValueJob.pipeline.id;
  $UrlPipelineCheck = $GitLabApiUrl + $GitLabApiprojectId + $GitlabApiPipelinesPart + $PipeId;
  Write-host -BackgroundColor Green -ForegroundColor Black "UrlPipeline" $UrlPipelineCheck;
  
  $WebResponsePipeline = Invoke-WebRequest -Method Get -Uri $UrlPipelineCheck -Headers $Headers 
  $keyValueJob = ConvertFrom-json $WebResponsePipeline.Content;  
  $PipelineStatus = $keyValueJob.status;

  Write-host -ForegroundColor Green "Status pipeline - " $PipelineStatus "ID" $PipeId;
  if($PipelineStatus -eq "failed" -or $PipelineStatus -eq "canceled")
  {
    Write-Error -Message "Houston, we have a problem. with" + $PipeLineStatus -ErrorAction Stop;
    break;
  }
<# Check the job state and if it is not in success status, wait 150 seconds and poll again (do this 30 times) #>


  if($saveStatus -eq "success")
    {

    Write-host -BackgroundColor Green "-----------------";    

    Write-host "job status ready - ID" + $saveId + $saveStatus +"Job name " + $saveName +;
    Write-host "time job finish - " $saveFinishTime;
    Write-host "Jenkins Work"; 

    Write-host -BackgroundColor Green "Begin Script copy test exe folder";
    Copy-Item -Path $sourceTests -Destination $DestinationForNewTests -recurse -Force;
	Write-host =  -BackgroundColor Green  "End Script copy test"; 
    
    Write-host -BackgroundColor Green "Begin copy Agent Installer exe";
    Copy-Item -Path $InstallPathAgent -Destination $DestinationAgent -recurse -Force;
  	Write-host =  -BackgroundColor Green  "End copy Agent Installer exe";
 
    break
    }
    elseif($saveStatus -ne "success")
    {
        Write-host "job status not ready - "$saveStatus "Job name " + $saveName +;
        Write-host "time job finish - " $saveFinishTime;
        
        Wait-Event -SourceIdentifier "ProcessStarted" -Timeout $JobTimer
    }
    $i++
    Write-host -BackgroundColor DarkYellow -ForegroundColor Red "Counter - "$i; 
    }
    catch
    {
       Write-host "broke - " $saveStatus;
       Wait-Event -SourceIdentifier "ProcessStarted" -Timeout 5;
       Write-Error -Message "Houston, we have a problem." -ErrorAction Stop;
       break;
    }
<# End of Job state handler #>
    }  




[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$LabelTrim  = ($ENV:JOB_BASE_NAME).TrimStart("label=")
$LabelValue = $LabelTrim  
$PathJenkinsWorkSpace = $ENV:WORKSPACE;
$SourcePath = "C:\tools\toolstestsRepo\"
$DbName = "TestValues.db";
$ConfigName = "config.json";

Write-host 'label job -' $labelValue

Write-host = "Begin Script copy DB SQLIte"

$DBPath = $SourcePath + $DbName
Write-host = $DBPath "DB path"
Copy-Item -Path $DBPath -Destination $PathJenkinsWorkSpace -recurse -Force 

Write-host = "End Script copy Db SQLIte"

Write-host = "Begin Script copy Config"

$ConfPath = $SourcePath + $ConfigName;
Write-host = $ConfPath "Conf path";

Copy-Item -Path $ConfPath -Destination $PathJenkinsWorkSpace -recurse -Force 

Write-host = "Begin Script copy Config";
