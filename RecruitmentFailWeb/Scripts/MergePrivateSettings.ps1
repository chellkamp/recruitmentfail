using namespace System.Management.Automation

param (
    [String] $PrivateSettingsFile = "",
    [String] $ProjectSettingsFile = ""
)

Import-Module (Join-Path $PSScriptRoot -ChildPath "..\..\Scripts\CustomObjectUtil.psm1") -Force
Import-Module (Join-Path $PSScriptRoot -ChildPath "..\..\Scripts\FileUtil.psm1") -Force

If (-not ($PrivateSettingsFile -and $ProjectSettingsFile)) {
    Write-Host "Must specify both PrivateSettingsFile and ProjectSettingsFile"
    Exit
}

Write-Host "Merging private settings [$PrivateSettingsFile] into existing settings [$ProjectSettingsFile]..."


[PSCustomObject] $PrivateJsonObj = Get-Content -LiteralPath $PrivateSettingsFile | ConvertFrom-Json
[PSCustomObject] $ProjectJsonObj = Get-Content -LiteralPath $ProjectSettingsFile | ConvertFrom-Json

MergeInto $ProjectJsonObj $PrivateJsonObj

WriteToFileUTF8 $ProjectSettingsFile ($ProjectJsonObj | ConvertTo-Json -Depth 100)

Write-Host "Merged private settings into main project settings."
