[uri]$Script:McrBase = "https://mcr.microsoft.com/v2/"

function Get-McrImageCatalog {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param ()

    $CatalogUri = New-Object uri $Script:McrBase, "_catalog"
    Invoke-RestMethod $CatalogUri
}

function Get-McrImageTagsList {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $TagsListUri = New-Object uri $Script:McrBase, "$Name/tags/list"
    Invoke-RestMethod $TagsListUri
}

function Get-McrImageReferenceManifest {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Reference
    )

    $ManifestUri = New-Object uri $Script:McrBase, "$Name/manifests/$Reference"
    $ManifestResponse = Invoke-RestMethod $ManifestUri
    if (-not $ManifestResponse) {
        return
    }

    $ManifestResponse.history = $ManifestResponse.history | ForEach-Object {
        if (($_ | Get-Member v1Compatibility -ErrorAction "SilentlyContinue")) {
            $_.v1Compatibility | ConvertFrom-Json
        }
        else {
            $_
        }
    } | ForEach-Object {
        $ManifestHistoryCreated = [datetimeoffset]$_.created
        if ($ManifestHistoryCreated) {
            $_.created = $ManifestHistoryCreated
        }
        $_
    } | ForEach-Object {
        $ManifestHistoryOsVersion = $null
        if (($_ | Get-Member "os.version" -ErrorAction "SilentlyContinue") -and `
                [version]::TryParse($_. { os.version }, [ref] $ManifestHistoryOsVersion)) {
            $_. { os.version } = $ManifestHistoryOsVersion
        }
        $_
    }

    $ManifestResponse
}

function Get-McrImageAllManifests {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $TagList = Get-McrImageTagsList $Name

    if ($TagList.name) {
        $Name = $TagList.name
    }

    $Percent100Length = (1.0).ToString("P2").Length
    $TagCountValue = ($TagList.tags | Measure-Object).Count
    $TagCountString = $TagCountValue.ToString("N0")
    $TagCountLength = $TagCountString.Length

    $TagProcessIdx = 0
    $ImageActivity = "Getting Image manifests for repository: $Name"
    $ImageActivityId = Get-Random
    $TagList.tags | ForEach-Object -Process {
        [string]$TagName = $_
        [double]$TagProgress = ([double]$TagProcessIdx) / ([double]$TagCountValue)
        [int]$TagPercent = $TagProgress * 100
        $TagStatus = "$($TagProcessIdx.ToString("N0").PadLeft($TagCountLength)) / $($TagCountString) ($($TagProgress.ToString("P2").PadLeft($Percent100Length)))"
        $ManifestTarget = "$($McrBase.Host)/${Name}:${TagName}"
        Write-Progress -Activity $ImageActivity -Id $ImageActivityId `
            -Status $TagStatus -PercentComplete $TagPercent `
            -CurrentOperation $ManifestTarget
        if ($PSCmdlet.ShouldProcess($ManifestTarget, "Get-McrImageReferenceManifest")) {
            Get-McrImageReferenceManifest -Name $Name -Reference $TagName -ErrorAction "SilentlyContinue"
        }
        $TagProcessIdx++
    } -End {
        Write-Progress -Activity $ImageActivity -Id $ImageActivityId -Completed
    }
}

function Group-McrImageManifests {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Position = 0)]
        [PSCustomObject[]]$ImageManifests
    )

    $ImageManifests | Group-Object -Property name, architecture, {
        $Result = ($_.fsLayers | Select-Object -First 1 -Property blobSum)
        if ($Result) {
            $Result."blobSum"
        }
    }, {
        $Result = ($_.history | Select-Object -First 1 -Property os)
        if ($Result) {
            $Result."os"
        }
    }, {
        $Result = ($_.history | Select-Object -First 1 -Property "os.version")
        if ($Result) {
            $Result."os.version"
        }
    } | ForEach-Object {
        [Microsoft.PowerShell.Commands.GroupInfo]$ManifestGroupInfo = $_
        $ManifestArchitecture = $ManifestGroupInfo.Values[1]
        $ManifestOs = $ManifestGroupInfo.Values[3]
        $ManifestOsVersion = $ManifestGroupInfo.Values[4]
        $ManifestDate = ($ManifestGroupInfo.Group | ForEach-Object {
            ($_.history | Measure-Object -Property created -Maximum).Maximum
        } | Measure-Object -Maximum).Maximum
        $ManifestTags = $ManifestGroupInfo.Group | Sort-Object -Descending {
            ($_.history | Measure-Object -Property created -Maximum).Maximum
        }

        [PSCustomObject]@{
            architecture = $ManifestArchitecture;
            os = $ManifestOs;
            "os.version" = $ManifestOsVersion;
            lastModified = $ManifestDate;
            manifests = $ManifestTags;
            image = $ManifestTags[0].name;
            tag = $ManifestTags[0].tag;
            tagNames = ($ManifestTags | ForEach-Object { $_.tag } | Sort-Object);
        }
    } | Sort-Object -Property "os.version" -Descending
}
