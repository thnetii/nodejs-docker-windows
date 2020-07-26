function Get-NodeJsDistIndex {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param ()

    $NodeJsDistIndexUri = "https://nodejs.org/dist/index.json"
    [PSCustomObject[]]$NodeJsDistArray = Invoke-RestMethod -Uri $NodeJsDistIndexUri
    $NodeJsDistArray | ForEach-Object {
        $_ | Add-Member -MemberType NoteProperty -Name "date.string" -Value $_.date
        $_.date = ($_ | Get-NodeJsDistReleaseDate)

        $_ | Add-Member -MemberType NoteProperty -Name "version.string" -Value $_.version
        $_.version = ($_ | Get-NodeJsDistVersion)

        $DistUriDict = New-Object "System.Collections.Generic.Dictionary[string,uri]" @([System.StringComparer]::OrdinalIgnoreCase)
        $DistInfo = $_
        $_.files | ForEach-Object {
            $DistUriDict[$_] = $DistInfo | Get-NodeJsDistUri -Type $_
        }
        $_ | Add-Member -MemberType NoteProperty -Name uris -Value $DistUriDict | Out-Null

        $_
    }
}

function Get-NodeJsDistUri {
    [CmdletBinding()]
    [OutputType([uri])]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [PSCustomObject]$InputObject,
        [string]$Type = "win-x64-zip"
    )

    begin {
        [uri]$NodejsRootUri = "https://nodejs.org/dist/"
    }

    process {
        [System.Text.StringBuilder]$RelativePath = New-Object System.Text.StringBuilder
        $RelativePath.Append($InputObject."version.string") | Out-Null
        $RelativePath.Append("/") | Out-Null
        $RelativePath.Append("node-") | Out-Null
        $RelativePath.Append($InputObject."version.string") | Out-Null
        switch -Wildcard ($Type) {
            "src" {
                $RelativePath.Append(".tar.xz") | Out-Null
                break
            }
            "headers" {
                $RelativePath.Append("-headers.tar.xz") | Out-Null
                break
            }
            "osx-x64-pkg" {
                $RelativePath.Append(".pkg") | Out-Null
                break
            }
            "osx-x64-tar" {
                $RelativePath.Append("-darwin-x64.tar.xz") | Out-Null
                break
            }
            "win-x64-zip" {
                $RelativePath.Append("-win-x64.zip") | Out-Null
                break
            }
            "win-x64-7z" {
                $RelativePath.Append("-win-x64.7z") | Out-Null
                break
            }
            "win-x64-msi" {
                $RelativePath.Append("-x64.msi") | Out-Null
                break
            }
            "win-x64-exe" {
                $RelativePath.Clear() | Out-Null
                $RelativePath.Append($InputObject."version.string") | Out-Null
                $RelativePath.Append("/win-x64/") | Out-Null
                break
            }
            "win-x86-zip" {
                $RelativePath.Append("-win-x86.zip") | Out-Null
                break
            }
            "win-x86-7z" {
                $RelativePath.Append("-win-x86.7z") | Out-Null
                break
            }
            "win-x86-msi" {
                $RelativePath.Append("-x86.msi") | Out-Null
                break
            }
            "win-x86-exe" {
                $RelativePath.Clear() | Out-Null
                $RelativePath.Append($InputObject."version.string") | Out-Null
                $RelativePath.Append("/win-x86/") | Out-Null
                break
            }
            "linux-*" {
                $RelativePath.Append("-") | Out-Null
                $RelativePath.Append($Type) | Out-Null
                $RelativePath.Append(".tar.xz") | Out-Null
                break
            }
            default {
                $RelativePath.Append("-") | Out-Null
                $RelativePath.Append($Type) | Out-Null
                $RelativePath.Append(".tar.gz") | Out-Null
                break
            }
        }
        New-Object uri $NodejsRootUri, $RelativePath.ToString()
    }
}

function Get-NodeJsDistVersion {
    [CmdletBinding()]
    [OutputType([version])]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [PSCustomObject]$InputObject
    )

    [version]([string]($InputObject.version)).TrimStart('v')
}

function Get-NodeJsDistReleaseDate {
    [CmdletBinding()]
    [OutputType([datetime])]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [PSCustomObject]$InputObject
    )

    [datetime]($InputObject.date)
}

function Get-NodeJsDistGroups {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Position = 0)]
        [PSCustomObject[]]$DistIndex,
        [switch]$ExcludeLatest,
        [switch]$ExcludeSecurity
    )

    $DistGroups = & {
        if (-not $ExcludeLatest) {
            [PSCustomObject]$LatestVersionInfo = $DistIndex | Sort-Object -Property date -Descending | Select-Object -First 1
            if ($LatestVersionInfo) {
                $LatestVersion = $LatestVersionInfo.version
            }
            [PSCustomObject]@{
                name          = "latest";
                latestVersion = $LatestVersion;
                dists         = @($LatestVersionInfo);
            }
        }
        if (-not $ExcludeSecurity) {
            $SecurityVersions = $DistIndex | Where-Object -Property security | Sort-Object -Property version -Descending
            if ($SecurityVersions) {
                [PSCustomObject]$LatestSecurityVersionInfo = $SecurityVersions | Select-Object -First 1
                if ($LatestSecurityVersionInfo) {
                    $LatestVersion = $LatestSecurityVersionInfo.version
                }
                [PSCustomObject]@{
                    name          = "security";
                    latestVersion = $LatestVersion;
                    dists         = $SecurityVersions;
                }
            }
        }
        $DistIndex | Group-Object -Property lts | ForEach-Object {
            $LtsName = $_.Name.ToLowerInvariant()
            if (-not $_.Values[0]) {
                $LtsName = "current"
            }
            $LtsVersions = $_.Group | Sort-Object -Property version -Descending
            [PSCustomObject]$LatestLtsVersionInfo = $LtsVersions | Select-Object -First 1
            if ($LatestLtsVersionInfo) {
                $LatestVersion = $LatestLtsVersionInfo.version
            }
            [PSCustomObject]@{
                name          = $LtsName;
                latestVersion = $LatestVersion;
                dists         = $LtsVersions;
            }
        }
    }

    $MinorGroupNames = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::OrdinalIgnoreCase)
    $MajorGroupNames = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::OrdinalIgnoreCase)
    $DistGroups += $DistGroups | Select-Object -Unique -Property latestVersion | ForEach-Object {
        [version]$DistVersion = $_.latestVersion
        [int]$DistMajor = $DistVersion.Major
        [int]$DistMinor = $DistVersion.Minor

        $MinorMatchingVersions = New-Object "System.Collections.ArrayList"
        $MajorMatchingVersions = New-Object "System.Collections.ArrayList"
        $DistIndex | ForEach-Object {
            if ($_.version.Major -eq $DistMajor) {
                $MajorMatchingVersions.Add($_) | Out-Null
                if ($_.version.Minor -eq $DistMinor) {
                    $MinorMatchingVersions.Add($_) | Out-Null
                }
            }
        }

        $LatestMinorMatchingVersionInfo = $MinorMatchingVersions | Select-Object -First 1
        if ($LatestMinorMatchingVersionInfo) {
            $LatestMinorMatchingVersion = $LatestMinorMatchingVersionInfo.version
        }
        $MinorMatchingName = $DistVersion.ToString(2)
        if ($MinorGroupNames.Add($MinorMatchingName)) {
            [PSCustomObject]@{
                name = $MinorMatchingName;
                latestVersion = $LatestMinorMatchingVersion;
                dists = $MinorMatchingVersions;
            }
        }

        $LatestMajorMatchingVersionInfo = $MajorMatchingVersions | Select-Object -First 1
        if ($LatestMajorMatchingVersionInfo) {
            $LatestMajorMatchingVersion = $LatestMajorMatchingVersionInfo.version
        }
        $MajorMatchingName = $DistVersion.ToString(1);
        if ($MajorGroupNames.Add($MajorMatchingName)) {
            [PSCustomObject]@{
                name = $MajorMatchingName;
                latestVersion = $LatestMajorMatchingVersion;
                dists = $MajorMatchingVersions;
            }
        }
    }

    $DistGroups | Sort-Object -Property latestVersion, name
}
