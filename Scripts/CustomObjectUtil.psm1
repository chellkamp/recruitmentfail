using namespace Microsoft.PowerShell.Commands
using namespace System.Management.Automation

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
