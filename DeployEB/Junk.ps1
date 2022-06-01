param (
    [switch]$development = $false,
    [switch]$production = $false
)

Add-Type -AssemblyName "System.Windows.Forms"


If ($development -and $production) {
    Write-Error "Error: Cannot specify both -Development and -Production flags.  Must be one or the other."
    Exit
} ElseIf (-not ($development -or $production)) {
    Write-Error "Error: Need to specify either the -Development or -Production flag."
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


Function GetFileList {
    [OutputType([System.Collections.Generic.List[String]])]
    Param (
        [System.IO.FileSystemInfo] $dir,
        [String[]] $excludeList
    )
    [System.Collections.Generic.List[String]] $retVal = New-Object -TypeName "System.Collections.Generic.List[String]"

    If (Test-Path $dir.FullName) {
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

[String] $zipExePath = "C:\Program Files\7-Zip\7z.exe"


[String[]] $ignore = @(
    "private.config",
    "build",
    "deploy",
    ".git",
    ".gitignore",
    ".project",
    "node_modules",
    ".next\cache"
)

[String] $baseDir = ".."

[String] $ebExtensionsDir = "$baseDir\deploy\config\config.ebextensions"
[String] $ebSrcConfig = Tern $production "prod.options.config" "dev.options.config"

[String] $baseDirFullPath = (New-Object -TypeName "System.IO.DirectoryInfo" (Join-Path -Path $PSScriptRoot -ChildPath $baseDir)).FullName
[String] $ebConfigSrcFullPath = (New-Object -TypeName "System.IO.FileInfo" (Join-Path -Path $PSScriptRoot -ChildPath "$ebExtensionsDir\$ebSrcConfig")).FullName

[String] $destDir = "$baseDir\build"
[String] $tmpZipDir = "$baseDir\build\tmp"

[String] $destZipProd = "ridiculousrevisions-website-prod.zip"
[String] $destZipDev = "ridiculousrevisions-website-dev.zip"

[String] $destZip = Tern $production $destZipProd $destZipDev

[String] $ebHttpsConfigPath = "$ebExtensionsDir\https-instance-securitygroup.config"
[String] $ebHttpsConfigFullPath = (New-Object -TypeName "System.IO.FileInfo" (Join-Path -Path $PSScriptRoot -ChildPath $ebHttpsConfigPath)).FullName

[System.Collections.Generic.List[String]] $fullPathIgnoreList = New-Object -TypeName "System.Collections.Generic.List[String]"

$ignore | ForEach-Object {
    [String] $joinedPath = Join-Path -Path $baseDirFullPath -ChildPath $_
    $fullPathIgnoreList.Add($joinedPath)
}

[System.Windows.Forms.OpenFileDialog] $fileDlg
[System.Windows.Forms.DialogResult] $dlgResult = [System.Windows.Forms.DialogResult]::None

#Choose private config file from dialog
$fileDlg = New-Object System.Windows.Forms.OpenFileDialog
$fileDlg.Title = "Choose a Private Config File"
$fileDlg.InitialDirectory = [Environment]::GetEnvironmentVariable("USERPROFILE")
$fileDlg.Filter = "Private config files (*.config)|*.config"
$dlgResult = $fileDlg.ShowDialog()

If($dlgResult -ne [System.Windows.Forms.DialogResult]::OK) {
    Exit
}
[String] $privateConfigFileSourcePath = $fileDlg.FileName
$fileDlg = $null

#Choose server cert file
$fileDlg = New-Object System.Windows.Forms.OpenFileDialog
$fileDlg.Title = "Choose a HTTPS cert"
$fileDlg.Filter = "PEM files (*.pem)|*.pem"
$dlgResult = $fileDlg.ShowDialog()

If($dlgResult -ne [System.Windows.Forms.DialogResult]::OK) {
    Exit
}

[String[]] $httpsCertContents = [System.IO.File]::ReadAllLines($fileDlg.FileName)
$fileDlg = $null


#Choose private key that goes with cert file
$fileDlg = New-Object System.Windows.Forms.OpenFileDialog
$fileDlg.Title = "Choose a HTTPS private key"
$fileDlg.Filter = "PEM files (*.pem)|*.pem"
$dlgResult = $fileDlg.ShowDialog()

If($dlgResult -ne [System.Windows.Forms.DialogResult]::OK) {
    Exit
}

[String[]] $httpsKeyContents = [System.IO.File]::ReadAllLines($fileDlg.FileName)
$fileDlg = $null

[System.Collections.Generic.List[String]] $ebHttpsConfigContents = New-Object -TypeName 'System.Collections.Generic.List[String]'  -ArgumentList @(,[System.IO.File]::ReadAllLines($ebHttpsConfigFullPath))
# replace tags with appropriately indented key values
$ebHttpsConfigContents = ReplaceinYAML $ebHttpsConfigContents '[[CERT_CONTENTS]]' $httpsCertContents
$ebHttpsConfigContents = ReplaceinYAML $ebHttpsConfigContents '[[PRIVATE_KEY_CONTENTS]]' $httpsKeyContents


#Remove old next build files
[String] $dotNextDirFullPath = (New-Object -TypeName "System.IO.DirectoryInfo" (Join-Path -Path $PSScriptRoot -ChildPath "$baseDir\.next")).FullName

If (Test-Path $dotNextDirFullPath) {
    Write-Host "Removing $dotNextDirFullPath..."
    Remove-Item -Path $dotNextDirFullPath -Recurse -Force
}

if ($production) {
    #Have to run build before production copy of code exists
    $origLocation = Get-Location
    Set-Location -Path $baseDirFullPath
    &npm run build
    Set-Location -Path $origLocation # restore to original working directory
}


[System.Collections.Generic.List[String]] $fullPathList = GetFileList (New-Object -TypeName "System.IO.DirectoryInfo" $baseDirFullPath) $fullPathIgnoreList

[int] $chopLength = $baseDirFullPath.Length
if (-not $baseDirFullPath.EndsWith([System.IO.Path]::PathSeparator)) {
    ++$chopLength #add one more onto the chop length
}
[System.Collections.Generic.List[String]] $relPathList = New-Object -TypeName "System.Collections.Generic.List[String]"
$fullPathList | ForEach-Object {
    [String] $relPath = $_.Substring($chopLength)
    $relPathList.Add($relPath)
}

If (Test-Path $tmpZipDir) {
    Remove-Item -Path $tmpZipDir -Force -Recurse
}

[string] $tmpZipDirFullPath = (New-Object -TypeName "System.IO.DirectoryInfo" (Join-Path -Path $PSScriptRoot -ChildPath $tmpZipDir)).FullName
[string] $destDirFullPath = (New-Object -TypeName "System.IO.DirectoryInfo" (Join-Path -Path $PSScriptRoot -ChildPath $destDir)).FullName

Write-Host "Copying files to temp directory: $tmpZipDirFullPath..."
$relPathList | ForEach-Object {
    [System.IO.FileInfo] $destFileObj = New-Object -TypeName "System.IO.FileInfo" "$tmpZipDirFullPath\$_"
    [System.IO.DirectoryInfo] $destDirObj = $destFileObj.Directory

    If (-not (Test-Path $destDirObj.FullName)) {
        New-Item -Path $destDirObj.FullName -Type Directory -Force | Out-Null
    }

    Copy-Item -LiteralPath "$baseDirFullPath\$_" -Destination "$tmpZipDirFullPath\$_" -Force
}

Write-Host "Copying private config to temp directory: $tmpZipDirFullPath"
Copy-Item -LiteralPath $privateConfigFileSourcePath -Destination "$tmpZipDirFullPath\private.config"


#Copy over correct config file to .ebextensions
[String] $tmpEbExtensionsFullPath = "$tmpZipDirFullPath\.ebextensions"
New-Item -Path $tmpEbExtensionsFullPath -Type Directory -Force | Out-Null
Copy-Item -Path $ebConfigSrcFullPath -Destination "$tmpEbExtensionsFullPath\options.config"

#Copy over .conf file to nginx path if it exists
[String] $tmpNginxPath = "$tmpZipDirFullPath\.platform\nginx"
[String] $nginxConfigSrcFullPath = (New-Object -TypeName 'System.IO.FileInfo' (Join-Path -Path $PSScriptRoot -ChildPath 'config\config.platform\nginx\nginx.conf')).FullName

If (Test-Path $nginxConfigSrcFullPath) {
    New-Item $tmpNginxPath -ItemType Directory
    Copy-Item -Path $nginxConfigSrcFullPath -Destination $tmpNginxPath
}

Write-Host "Writing https config to temp directory: $tmpZipDirFullPath"

WriteLinesToUnixFile "$tmpEbExtensionsFullPath\https-instance-securitygroup.config" $ebHttpsConfigContents

Write-Host "Zipping files in temp dir..."

[String] $destZipFullPath = "$destDirFullPath\$destZip"

If (Test-Path $destZipFullPath) {
    Remove-Item -Path $destZipFullPath -Force
}

Write-Host "Dest dir: $destDirFullPath"

&"$zipExePath" a -tzip "$destZipFullPath" "$tmpZipDirFullPath\*" -aoa

#Compress-Archive -Path "$tmpZipDirFullPath\*" -DestinationPath $destZipFullPath

Write-Host "Done"