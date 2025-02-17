﻿If ($PSVersiontable.PSVersion.Major -le 2) {$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path}
Import-Module $PSScriptRoot\CommonUtils.psm1 -Force
#covered -i -p -q -r -v -c -S -C
#todo: -F, -l and -P should be tested over the network
$tI = 0
$suite = "SCP"
Describe "Tests for scp command" -Tags "CI" {
    BeforeAll {
        if($OpenSSHTestInfo -eq $null)
        {
            Throw "`$OpenSSHTestInfo is null. Please run Set-OpenSSHTestEnvironment to set test environments."
        }

        $testDir = "$($OpenSSHTestInfo["TestDataPath"])\$suite"
        $fileName1 = "test.txt"
        $fileName2 = "test2.txt"
        $fileName3 = "test3.txt"
        $wildcardFileName1 = "te?t.txt"
        $wildcardFileName2 = "test*"
        $SourceDirName = "SourceDir"
        $SourceDir = Join-Path $testDir $SourceDirName
        $SourceFilePath = Join-Path $SourceDir $fileName1
        $SourceFilePath3 = Join-Path $SourceDir $fileName3
        $SourceFileWildCardFile1 = Join-Path $SourceDir $wildcardFileName1
        $DestinationDir = Join-Path "$($OpenSSHTestInfo["TestDataPath"])\SCP" "DestDir"
        $DestinationDirWildcardPath = Join-Path "$($OpenSSHTestInfo["TestDataPath"])\SCP" "DestD?r"
        $DestinationFilePath = Join-Path $DestinationDir $fileName1        
        $NestedSourceDir= Join-Path $SourceDir "nested"
        $NestedSourceFilePath = Join-Path $NestedSourceDir $fileName2
        $null = New-Item $SourceDir -ItemType directory -Force -ErrorAction SilentlyContinue
        $null = New-Item $NestedSourceDir -ItemType directory -Force -ErrorAction SilentlyContinue
        $null = New-item -path $SourceFilePath -ItemType file -force -ErrorAction SilentlyContinue
        $null = New-item -path $NestedSourceFilePath -ItemType file -force -ErrorAction SilentlyContinue
        "Test content111" | Set-content -Path $SourceFilePath
        "Test content333" | Set-content -Path $SourceFilePath3
        "Test content in nested dir" | Set-content -Path $NestedSourceFilePath
        $null = New-Item $DestinationDir -ItemType directory -Force -ErrorAction SilentlyContinue
        $sshcmd = (get-command ssh).Path        

        $server = $OpenSSHTestInfo["Target"]
        $port = $OpenSSHTestInfo["Port"]
        $ssouser = $OpenSSHTestInfo["SSOUser"]

        $testData = @(
            @{
                Title = 'Simple copy local file to local file'
                Source = $SourceFilePath                   
                Destination = $DestinationFilePath
            },
            @{
                Title = 'Simple copy local file to remote file'
                Source = $SourceFilePath
                Destination = "test_target:$DestinationFilePath"
                Options = "-S `"$sshcmd`""
            },
            @{
                Title = 'Simple copy remote file to local file'
                Source = "test_target:$SourceFilePath"
                Destination = $DestinationFilePath
                Options = "-p -c aes128-ctr -C"
            },            
            @{
                Title = 'Simple copy local file to local dir'
                Source = $SourceFilePath
                Destination = $DestinationDir
            },
            @{
                Title = 'simple copy local file to remote dir'         
                Source = $SourceFilePath
                Destination = "test_target:$DestinationDir"
                Options = "-C -q"
            },
            @{
                Title = 'simple copy remote file to local dir'
                Source = "test_target:$SourceFilePath"
                Destination = $DestinationDir
            },
            @{
                Title = 'Simple copy local file with wild card name to local dir'
                Source = $SourceFileWildCardFile1
                Destination = $DestinationDir
            },
            @{
                Title = 'simple copy remote file with wild card name to local dir'
                Source = "test_target:$SourceFileWildCardFile1"
                Destination = $DestinationDir
            },
            @{
                Title = 'simple copy local file to remote dir with wild card name'         
                Source = $SourceFilePath
                Destination = "test_target:$DestinationFilePath"
                Options = "-C -q"
            }
        )

        $testData1 = @(
            @{
                Title = 'copy from local dir to remote dir'
                Source = $sourceDir
                Destination = "test_target:$DestinationDir"
                Options = "-r -p -c aes128-ctr"
            },
            @{
                Title = 'copy from local dir to local dir'
                Source = $sourceDir
                Destination = $DestinationDir
                Options = "-r "
            },
            @{
                Title = 'copy from remote dir to local dir'            
                Source = "test_target:$sourceDir"
                Destination = $DestinationDir
                Options = "-C -r -q"
            }
        )

        # for the first time, delete the existing log files.
        if ($OpenSSHTestInfo['DebugMode'])
        {
            Clear-Content "$env:ProgramData\ssh\logs\ssh-agent.log" -Force -ErrorAction SilentlyContinue
            Clear-Content "$env:ProgramData\ssh\logs\sshd.log" -Force -ErrorAction SilentlyContinue
        }

        function CheckTarget {
            param([string]$target)
            if(-not (Test-path $target))
            {
                if( $OpenSSHTestInfo["DebugMode"])
                {
                    Copy-Item "$env:ProgramData\ssh\logs\ssh-agent.log" "$testDir\failedagent$tI.log" -Force -ErrorAction SilentlyContinue
                    Copy-Item "$env:ProgramData\ssh\logs\sshd.log" "$testDir\failedsshd$tI.log" -Force -ErrorAction SilentlyContinue
                    
                    # clear the ssh-agent, sshd logs so that next testcase will get fresh logs.
                    Clear-Content "$env:ProgramData\ssh\logs\ssh-agent.log" -Force -ErrorAction SilentlyContinue
                    Clear-Content "$env:ProgramData\ssh\logs\sshd.log" -Force -ErrorAction SilentlyContinue
                }
             
                return $false
            }
            return $true
        }
    }
    AfterAll {

        if($OpenSSHTestInfo -eq $null)
        {
            #do nothing
        }
        elseif( -not $OpenSSHTestInfo['DebugMode'])
        {
            if(-not [string]::IsNullOrEmpty($SourceDir))
            {
                Get-Item $SourceDir | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
            if(-not [string]::IsNullOrEmpty($DestinationDir))
            {
                Get-Item $DestinationDir | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    BeforeAll {
        $null = New-Item $DestinationDir -ItemType directory -Force -ErrorAction SilentlyContinue
    }

    AfterEach {
        Get-ChildItem $DestinationDir -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Start-Sleep 1
        $tI++
    }       
    

    It 'File copy: <Title> ' -TestCases:$testData {
        param([string]$Title, $Source, $Destination, [string]$Options)
        iex  "scp $Options $Source $Destination"
        $LASTEXITCODE | Should Be 0
        #validate file content. DestPath is the path to the file.
        CheckTarget -target $DestinationFilePath | Should Be $true

        $equal = @(Compare-Object (Get-ChildItem -path $SourceFilePath) (Get-ChildItem -path $DestinationFilePath) -Property Name, Length ).Length -eq 0
        $equal | Should Be $true

        if($Options.contains("-p ") -and [environment]::OSVersion.Version.Major -ge 10)
        {
            $equal = @(Compare-Object (Get-ChildItem -path $SourceFilePath).LastWriteTime.DateTime (Get-ChildItem -path $DestinationFilePath).LastWriteTime.DateTime ).Length -eq 0
            $equal | Should Be $true
        }
    }
                
    It 'Directory recursive copy: <Title> ' -TestCases:$testData1 {
        param([string]$Title, $Source, $Destination, [string]$Options)                        
            
        iex  "scp $Options $Source $Destination"
        $LASTEXITCODE | Should Be 0
        CheckTarget -target (join-path $DestinationDir $SourceDirName) | Should Be $true

        $equal = @(Compare-Object (Get-Item -path $SourceDir ) (Get-Item -path (join-path $DestinationDir $SourceDirName) ) -Property Name, Length).Length -eq 0        
        $equal | Should Be $true

        if($Options.contains("-p "))
        {
            $equal = @(Compare-Object (Get-Item -path $SourceDir).LastWriteTime.DateTime (Get-Item -path (join-path $DestinationDir $SourceDirName)).LastWriteTime.DateTime).Length -eq 0            
            $equal | Should Be $true
        }

        $equal = @(Compare-Object (Get-ChildItem -Recurse -path $SourceDir) (Get-ChildItem -Recurse -path (join-path $DestinationDir $SourceDirName) ) -Property Name, Length).Length -eq 0
        $equal | Should Be $true

        if($Options.contains("-p ") -and $IsWindows -and ($PSVersionTable.PSVersion.Major -gt 2))
        {
            $equal = @(Compare-Object (Get-ChildItem -Recurse -path $SourceDir).LastWriteTime.DateTime (Get-ChildItem -Recurse -path (join-path $DestinationDir $SourceDirName) ).LastWriteTime.DateTime).Length -eq 0            
            $equal | Should Be $true
        }
    }

    It 'File copy: path contains wildcards ' {
        $Source = Join-Path $SourceDir $wildcardFileName2
        scp -p $Source $DestinationDir
        $LASTEXITCODE | Should Be 0
        #validate file content. DestPath is the path to the file.
        CheckTarget -target $DestinationFilePath | Should Be $true
        CheckTarget -target (Join-path $DestinationDir $fileName3) | Should Be $true

        $equal = @(Compare-Object (Get-ChildItem -path $Source) (Get-ChildItem -path (join-path $DestinationDir $wildcardFileName2)) -Property Name, Length ).Length -eq 0
        $equal | Should Be $true
        
        $equal = @(Compare-Object (Get-ChildItem -path $Source).LastWriteTime.DateTime (Get-ChildItem -path (join-path $DestinationDir $wildcardFileName3)).LastWriteTime.DateTime ).Length -eq 0
        $equal | Should Be $true        
    }
}   
