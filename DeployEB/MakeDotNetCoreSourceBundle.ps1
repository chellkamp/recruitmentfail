using namespace System.Management.Automation

param (
    [switch]$debug = $false,
    [switch]$release = $false
)

Add-Type -AssemblyName "System.Windows.Forms"

Import-Module (Join-Path $PSScriptRoot -ChildPath "..\Scripts\FileUtil.psm1") -Force
Import-Module (Join-Path $PSScriptRoot -ChildPath "..\Scripts\CustomObjectUtil.psm1") -Force

If ($debug -and $release) {
    Write-Error "Error: Cannot specify both -Debug and -Release flags.  Must be one or the other."
    Exit
} ElseIf (-not ($debug -or $release)) {
    Write-Error "Error: Need to specify either the -Debug or -Release flag."
    Exit
}

# Poor man's ternary operator
Function Tern($condition, $condTrue, $condFalse) {
    If ($condition) {
        Return $condTrue
    } Else {
        Return $condFalse
    }
}

#Looks for any lines containing the specified text.
#That whole line will be replaced by the file contents,
#indented at the same level as the original line.
Function ReplaceinYAML {
    [OutputType([System.Collections.Generic.List[String]])]
    Param (
        [System.Collections.Generic.IEnumerable[String]] $srcLines,
        [String] $oldValue,
        [System.Collections.Generic.IEnumerable[String]] $newValue
    )

    [System.Collections.Generic.List[String]] $retVal = New-Object -TypeName 'System.Collections.Generic.List[String]'

    $srcLines | ForEach-Object {
        [String] $srcLine = $_
        [int] $foundIdx = $srcLine.IndexOf($oldValue)
        If ($foundIdx -lt 0) {
            #Nothing to change here.  Just add as-is back to the output
            $retVal.Add($srcLine)
        } Else {
            #Found a line that needs to be replaced with file contents
            #Get leading whitespace
            [String] $leadingWhitespace = ($srcLine | Select-String -Pattern '^\s*')[0].Matches[0].Value

            #Prepend leading whitespace onto each line in $newValue and add to the output
            $newValue | ForEach-Object {
                $retVal.Add($leadingWhitespace + $_)
            }
        }
    }#end loop over source lines

    return $retVal
}


Function GetFileList {
    [OutputType([System.Collections.Generic.List[String]])]
    Param (
        [System.IO.FileSystemInfo] $dir,
        [String[]] $excludeList
    )
    [System.Collections.Generic.List[String]] $retVal = New-Object -TypeName "System.Collections.Generic.List[String]"

    If (Test-Path -LiteralPath $dir.FullName) {
        Get-ChildItem -Path $dir.FullName | ForEach-Object {
            [System.IO.FileSystemInfo] $curItem = $_

            # Check whether the item is excluded by the list
            [bool] $exclude = $false
            If ($excludeList -ne $null) {
                [int] $num = $excludeList.Length
                For ([int] $exIdx = 0; -not $exclude -and $exIdx -lt $num; ++$exIdx) {
                    If ($curItem.FullName -like $excludeList[$exIdx]) {
                        $exclude = $true
                    }  
                }
            }

            If (-not $exclude) {
                If ($curItem.Attributes -band [System.IO.FileAttributes]::Directory) {
                    [System.Collections.Generic.List[String]] $subRange = GetFileList $curItem $excludeList
                    if ($subRange.Count -gt 0) {
                        $retVal.AddRange($subRange)
                    }
                } Else {
                    $retVal.Add($curItem.FullName)
                }
            }
        }
    }

    Return $retVal
}


Function BuildSecGroupFile {
    Param (
        [String] $destPath,
        [String] $srcTemplatePath,
        [String] $certPath,
        [String] $keyPath
    )
    [System.Collections.Generic.List[String]] $srcTemplateContents = New-Object -TypeName 'System.Collections.Generic.List[String]'  -ArgumentList @(,[System.IO.File]::ReadAllLines($srcTemplatePath))
    [String[]] $httpsCertContents = [System.IO.File]::ReadAllLines($certPath)
    [String[]] $httpsKeyContents = [System.IO.File]::ReadAllLines($keyPath)

    $srcTemplateContents = ReplaceinYAML $srcTemplateContents '[[CERT_CONTENTS]]' $httpsCertContents
    $srcTemplateContents = ReplaceinYAML $srcTemplateContents '[[PRIVATE_KEY_CONTENTS]]' $httpsKeyContents

    [String] $destDir = (New-Object -TypeName "System.IO.DirectoryInfo" $destPath).Parent.FullName
    CreateDirIfNotExists $destDir
    WriteLinesToUnixFile $destPath $srcTemplateContents
}

[String] $buildConfig = Tern $debug "Debug" "Release"


[String] $zipExePath = "C:\Program Files\7-Zip\7z.exe"
[String] $deployConfigFullPath = JoinToFullPath $PSScriptRoot "deploy.config.json"
[String] $buildFullPath = JoinToFullPath $PSScriptRoot "..\BuildEB"
[String] $tmpFullPath = JoinToFullPath $buildFullPath "tmp"
[String] $srcNginxConfFullPath = JoinToFullPath $PSScriptRoot "config\config.platform\nginx\nginx.conf"
[String] $destNginxConfFullPath = JoinToFullPath "$tmpFullPath" ".platform\nginx\nginx.conf"
[String] $srcSecurityGroupConfigFullPath = JoinToFullPath $PSScriptRoot ".\config\config.ebextensions\https-instance-securitygroup.config"
[String] $destSecurityGroupConfigFullPath = JoinToFullPath "$tmpFullPath" ".ebextensions\https-instance-securitygroup.config"

[PSCustomObject] $deployConfig = Get-Content -LiteralPath $deployConfigFullPath | ConvertFrom-Json

[String] $srcBundleFullPath = JoinToFullPath $buildFullPath "$($deployConfig.name)-$($buildConfig).zip"


[String] $customAppsettingsFullPath = ChooseFileFromDlg "Choose App Settings File" "JSON config files (*.json) | *.json" -SetToUserProfile
[String] $srcCertFullPath = ChooseFileFromDlg "Choose HTTPS Cert File" "cert files (*.pem) | *.pem"
[String] $srcPrivateKeyFullPath = ChooseFileFromDlg "Choose HTTPS Private Key File" "key files (*.pem) | *.pem"

#Initialize additional information inside the deploy config object
$deployConfig.projectFile = JoinToFullPath $PSScriptRoot $deployConfig.projectFile

# Delete directories holding old zip file contents
RemoveDirIfExists $tmpFullPath

# Delete zip file
RemoveDirIfExists $srcBundleFullPath

# Build and zip up the project

Write-Host "Building $($deployConfig.projectFile) for $($buildConfig)..."

CreateDirIfNotExists $tmpFullPath

Write-Host "Publishing..."

dotnet publish "-o:`"$tmpFullPath`"" "`"$($deployConfig.projectFile)`"" "-t:Clean,Rebuild" "-p:MergePrivateSettings=false;Configuration=$buildConfig"

If ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to publish $($curEntry.projectFile)"
    Exit
}


# Merge the app settings from the user-selected file into the file in the publishing folder

[String] $publishedAppSettingsFileFullPath = JoinToFullPath $tmpFullPath "appsettings.json"
[PSCustomObject] $destSettingsObj = Get-Content -Path $publishedAppSettingsFileFullPath | ConvertFrom-Json 
[PSCustomObject] $srcSettingsObj = Get-Content -Path $customAppSettingsFullPath | ConvertFrom-Json

MergeInto $destSettingsObj $srcSettingsObj
WriteToFileUTF8 $publishedAppSettingsFileFullPath ($destSettingsObj | ConvertTo-Json -Depth 100)

# Copy nginx.conf
CreatePathAndCopy $destNginxConfFullPath $srcNginxConfFullPath

# Configure HTTPS-related security groups
BuildSecGroupFile $destSecurityGroupConfigFullPath $srcSecurityGroupConfigFullPath $srcCertFullPath $srcPrivateKeyFullPath


&"$zipExePath" a -tzip "$srcBundleFullPath" "$($tmpFullPath)\*" -aoa
