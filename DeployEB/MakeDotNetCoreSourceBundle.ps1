using namespace Microsoft.PowerShell.Commands
using namespace System.Management.Automation

param (
    [switch]$debug = $false,
    [switch]$release = $false
)

Add-Type -AssemblyName "System.Windows.Forms"

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


Function WriteLinesToUnixFile {
    Param (
        [String] $filePath,
        [System.Collections.Generic.IEnumerable[String]] $lines
    )

    [System.Text.UTF8Encoding] $encoding = New-Object -TypeName 'System.Text.UTF8Encoding' $false
    [byte] $newLine = $encoding.GetBytes("`n")[0]


    [System.IO.FileStream] $fs = New-Object -TypeName 'System.IO.FileStream' -ArgumentList @($filePath, [System.IO.FileMode]::Create)


    $lines | ForEach-Object {
        [byte[]] $bytes = $encoding.GetBytes($_)
        $fs.Write($bytes, 0, $bytes.Length)
        $fs.WriteByte($newLine)
    }

    $fs.Close()
}

Function WriteToFileUTF8 {
    Param (
        [String] $filePath,
        [String] $contents
    )

    [System.Text.UTF8Encoding] $encoding = New-Object -TypeName 'System.Text.UTF8Encoding' $false
    [byte[]] $bytes = $encoding.GetBytes($contents)
    [System.IO.FileStream] $fs = New-Object -TypeName 'System.IO.FileStream' -ArgumentList @($filePath, [System.IO.FileMode]::Create)
    $fs.Write($bytes, 0, $bytes.Length)
    $fs.Close()
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


# Open a dialog box for the user to select a file
Function ChooseFileFromDlg {
    [OutputType([String])]
    Param (
        [String] $dlgTitle, #title of dialog box
        [String] $dlgFilter #file filter for dialog box
    )
    [System.Windows.Forms.OpenFileDialog] $fileDlg = $null
    [System.Windows.Forms.DialogResult] $dlgResult = [System.Windows.Forms.DialogResult]::None

    #Choose file from dialog
    $fileDlg = New-Object System.Windows.Forms.OpenFileDialog
    $fileDlg.Title = $dlgTitle
    $fileDlg.InitialDirectory = [Environment]::GetEnvironmentVariable("USERPROFILE")
    $fileDlg.Filter = $dlgFilter
    $dlgResult = $fileDlg.ShowDialog()

    If($dlgResult -ne [System.Windows.Forms.DialogResult]::OK) {
        Exit
    }

    Return $fileDlg.FileName
}

Function GetFullPathFromRel {
    [OutputType([String])]
    Param(
        [String] $relPath
    )

    Return (New-Object -TypeName "System.IO.FileInfo" (Join-Path $PSScriptRoot -ChildPath $relPath)).FullName
}

Function JoinToFullPath {
    [OutputType([String])]
    Param (
        [switch] $File,
        [String] $fullPath,
        [String] $childPath
    )
    Return (New-Object -TypeName "System.IO.FileInfo" (Join-Path $fullPath -ChildPath $childPath)).FullName
}

Function CreateDirIfNotExists {
    Param (
        [String] $path
    )

    If (-not (Test-Path -LiteralPath $path)) {
        New-Item -Path $path -ItemType Directory -Force
    }
}

Function RemoveDirIfExists {
    Param (
        [String] $path
    )

    If (Test-Path -LiteralPath $path) {
        Remove-Item -Recurse -Force -LiteralPath $path
    }
}

Function CreatePathAndCopy {
    Param (
        [String] $destPath,
        [String] $srcPath
    )

    [String] $destDir = (New-Object -TypeName "System.IO.DirectoryInfo" $destPath).Parent.FullName
    CreateDirIfNotExists $destDir

    Copy-Item -LiteralPath $srcPath -Destination $destPath
}

# Merge one PSCustomObject into another
Function MergeInto {
    Param (
        [PSCustomObject] $dest,
        [PSCustomObject] $src
    )

    $src | Get-Member | ForEach {
        [MemberDefinition] $curMember = $_
        If ($curMember.MemberType -eq [PSMemberTypes]::NoteProperty) {
            [String] $propName = $curMember.Name
            [MemberDefinition] $destMember = $dest | Get-Member -Name $propName -MemberType NoteProperty
            If ($destMember -ne $null) {

                # If the source and destination prop are both custom objects, then merge them.
                If (($src.$propName -is [PSCustomObject]) -and ($dest.$propName -is [PSCustomObject])) {
                    MergeInto $dest.$propName $src.$propName
                } Else {

                    # Overwrite the destination prop with the source prop for all other type combos
                    $dest.$propName = $src.$propName
                }
            } Else {

                # Completely new prop for the destination object
                $dest | Add-Member -MemberType NoteProperty -Name $propName -Value $src.$propName
            }
        }
    }

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
[String] $deployConfigFullPath = GetFullPathFromRel "deploy.config.json"
[String] $buildFullPath = GetFullPathFromRel "..\BuildEB"
[String] $tmpFullPath = JoinToFullPath $buildFullPath "tmp"
[String] $srcNginxConfFullPath = GetFullPathFromRel "config\config.platform\nginx\nginx.conf"
[String] $destNginxConfFullPath = JoinToFullPath "$tmpFullPath" ".platform\nginx\nginx.conf"
[String] $srcSecurityGroupConfigFullPath = GetFullPathFromRel ".\config\config.ebextensions\https-instance-securitygroup.config"
[String] $destSecurityGroupConfigFullPath = JoinToFullPath "$tmpFullPath" ".ebextensions\https-instance-securitygroup.config"

[PSCustomObject] $deployConfig = Get-Content -LiteralPath $deployConfigFullPath | ConvertFrom-Json

[String] $srcBundleFullPath = JoinToFullPath $buildFullPath "$($deployConfig.name)-$($buildConfig).zip"

[String] $customAppsettingsFullPath = ChooseFileFromDlg "Choose App Settings File" "JSON config files (*.json) | *.json"

[String] $srcCertFullPath = ChooseFileFromDlg "Choose HTTPS Cert File" "cert files (*.pem) | *.pem"
[String] $srcPrivateKeyFullPath = ChooseFileFromDlg "Choose HTTPS Private Key File" "key files (*.pem) | *.pem"

#Initialize additional information inside the deploy config object
$deployConfig.projectFile = GetFullPathFromRel $deployConfig.projectFile

# Delete directories holding old zip file contents
RemoveDirIfExists $tmpFullPath

# Delete zip file
RemoveDirIfExists $srcBundleFullPath

# Build and zip up the project

Write-Host "Building $($deployConfig.projectFile)..."

dotnet build "`"$($deployConfig.projectFile)`"" "-t:Clean,Rebuild" "-p:Configuration=$buildConfig"

If ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build $($deployConfig.projectFile)"
    Exit
}

CreateDirIfNotExists $tmpFullPath
dotnet publish "-o:`"$tmpFullPath`"" "`"$($deployConfig.projectFile)`""
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
