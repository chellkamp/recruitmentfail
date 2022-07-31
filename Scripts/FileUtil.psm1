
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

# Open a dialog box for the user to select a file
Function ChooseFileFromDlg {
    [OutputType([String])]
    Param (
        [String] $dlgTitle, #title of dialog box
        [String] $dlgFilter, #file filter for dialog box
        [switch] $SetToUserProfile
    )
    [System.Windows.Forms.DialogResult] $dlgResult = [System.Windows.Forms.DialogResult]::None
    [System.Windows.Forms.OpenFileDialog] $fileDlg = New-Object System.Windows.Forms.OpenFileDialog

    If ($SetToUserProfile) {
        $fileDlg.InitialDirectory = [Environment]::GetEnvironmentVariable("USERPROFILE")
    }


    #Choose file from dialog
    $fileDlg.Title = $dlgTitle    
    $fileDlg.Filter = $dlgFilter
    $dlgResult = $fileDlg.ShowDialog()

    If($dlgResult -ne [System.Windows.Forms.DialogResult]::OK) {
        Exit
    }

    Return $fileDlg.FileName
}

Function JoinToFullPath {
    [OutputType([String])]
    Param (
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
