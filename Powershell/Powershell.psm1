$ErrorActionPreference = "Stop"

$DownloadDir = "/tmp"
$InstallDir = "/opt/powershell"
$SymlinkDir = "/usr/bin"
$PwshSymlink = Join-Path $SymlinkDir pwsh
$RepoOwner = "Powershell"
$RepoName = "Powershell"
$ReleasesPath = Join-Path $InstallDir releases.json
$Releases = @()

if (Test-Path $ReleasesPath -PathType Leaf) {
    $Releases = Get-Content $ReleasesPath -Raw | ConvertFrom-Json
}

function Get-PowershellInstalledVersion {
    param (
        [string]
        $Version
    )

    $InstalledReleases = @()

    Get-ChildItem $InstallDir -Directory | ForEach-Object {
        $InstalledReleases += [PSCustomObject]@{
            Name = $_.Name
            Path = $_.FullName
            Symlink = Join-Path $SymlinkDir "pwsh$($_.Name)"
        }
    }

    if (-not $Version) {
        $InstalledReleases
    } else {
        $InstalledReleases | Where-Object Name $Version -EQ
    }
}

function Get-PowershellAvailableVersion {
    param (
        [string]
        $Version,
        [switch]
        $Force
    )

    $ReturnValue = {
        if (-not $Version) {
            $Script:Releases
        } else {
            $Script:Releases | Where-Object Name $Version -EQ
        }
    }

    if ((-not $Force) -and $Script:Releases) {
        return $ReturnValue.Invoke()
    }

    $Script:Releases = @()
    $RestUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases?per_page=100"
    $Response = Invoke-RestMethod $RestUrl -Method Get

    foreach ($Release in $Response) {
        $Name = $Release.tag_name
        $Url = $Release.assets | Where-Object Name "*linux-x64.tar.gz" -Like | Select-Object -First 1 -ExpandProperty browser_download_url
        if (-not $Name -or -not $Url) {
            continue
        }
        $Script:Releases += [PSCustomObject]@{
            Name = $Name
            Url = $Url
        }
    }

    $Script:Releases | ConvertTo-Json | Out-File $ReleasesPath

    $ReturnValue.Invoke()
}

function Install-Powershell {
    param (
        [Parameter(Mandatory)]
        [string]
        $Version,
        [switch]
        $Switch
    )

    if (-not (Test-Path $InstallDir -PathType Container)) {
        New-Item $InstallDir -ItemType Directory | Out-Null
    }

    $InstalledRelease = Get-PowershellInstalledVersion $Version
    if ($InstalledRelease) {
        throw "已经安装了 $Version 版本！"
    }

    $AvailableRelease = Get-PowershellAvailableVersion $Version
    if (-not $AvailableRelease) {
        throw "不支持安装 $Version 版本"
    }

    $DownloadUrl = $AvailableRelease.Url
    $FileName = Split-Path -Leaf $DownloadUrl
    $DownloadPath = Join-Path $DownloadDir $FileName
    Invoke-WebRequest $DownloadUrl -OutFile $DownloadPath

    $InstallPath = Join-Path $InstallDir $Version
    New-Item $InstallPath -ItemType Directory -Force | Out-Null
    tar zxf $DownloadPath -C $InstallPath

    $SymlinkPath = Join-Path $SymlinkDir "pwsh$Version"
    $SymlinkTarget = Join-Path $InstallPath pwsh
    chmod 755 $SymlinkTarget
    New-Item $SymlinkPath -ItemType SymbolicLink -Value $SymlinkTarget -Force | Out-Null

    Write-Host "Powershell $Version 安装好了！！！"

    if ($Switch) {
        Switch-Powershell $Version
    }
}

function Uninstall-Powershell {
    param (
        [Parameter(Mandatory)]
        [string]
        $Version
    )

    $InstalledRelease = Get-PowershellInstalledVersion $Version
    if (-not $InstalledRelease) {
        throw "未安装 $Version 版本！"
    }

    $PwshTarget = (Get-Item $PwshSymlink).Target
    $DestTarget = (Get-Item $InstalledRelease.Symlink).Target
    if ($PwshTarget -eq $DestTarget) {
        throw "请先切换版本"
    }

    Remove-Item $InstalledRelease.Symlink -Force
    Remove-Item $InstalledRelease.Path -Recurse -Force

    Write-Host "Powershell $Version 卸载好了！！！"
}

function Switch-Powershell {
    param (
        [Parameter(Mandatory)]
        [string]
        $Version
    )

    $InstalledRelease = Get-PowershellInstalledVersion $Version
    if (-not $InstalledRelease) {
        throw "未安装 $Version 版本！"
    }

    $DestTarget = Join-Path $InstallDir $Version pwsh
    if (-not (Test-Path $InstalledRelease.Symlink)) {
        New-Item $InstalledRelease.Symlink -ItemType SymbolicLink -Value $DestTarget | Out-Null
    }
    if (Test-Path $PwshSymlink) {
        Remove-Item $PwshSymlink -Force
    }

    New-Item $PwshSymlink -ItemType SymbolicLink -Value $InstalledRelease.Symlink | Out-Null

    Write-Host "Powershell 切换到 $Version 版本了！！！"
}

function InstalledVersionCompleter {
    param (
        $commaName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    (Get-ChildItem $InstallDir -Directory).Name | Where-Object { $_ -like "$wordToComplete*" }
}

function AvailableVersionCompleter {
    param (
        $commaName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    $Releases.Name | Where-Object { $_ -like "$wordToComplete*" }
}

Register-ArgumentCompleter -CommandName Get-PowershellInstalledVersion, Uninstall-Powershell -ParameterName Version -ScriptBlock { InstalledVersionCompleter @args }
Register-ArgumentCompleter -CommandName Get-PowershellAvailableVersion, Install-Powershell -ParameterName Version -ScriptBlock { AvailableVersionCompleter @args }