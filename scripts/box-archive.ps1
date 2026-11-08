# box-archive.ps1 - xuat box tu cache Vagrant thanh file .box, tinh SHA256, tao catalog metadata.json
# Ly do: HCP Vagrant het ho tro 02/11/2026 va du kien go toan bo 31/12/2026.
# Chay trong thu muc repo:
#   powershell -ExecutionPolicy Bypass -File .\scripts\box-archive.ps1
#   (tuy chon) -Dest E:\vagrant-boxes  de luu sang o khac
param(
    [string]$Dest = 'D:\vagrant-boxes',
    [string]$Box = 'bento/ubuntu-24.04',
    [string]$Version = '202510.26.0'
)
$ErrorActionPreference = 'Stop'
$fileName = "bento-ubuntu-24.04-$Version-virtualbox-amd64.box"
$boxPath = Join-Path $Dest $fileName
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

if (Test-Path $boxPath) {
    Write-Host "Da co $boxPath - bo qua buoc repackage." -ForegroundColor Yellow
} else {
    Write-Host "Xuat box tu cache (mat vai phut, file ~1 GB tro len)..."
    Push-Location $Dest
    try {
        vagrant box repackage $Box virtualbox $Version
        if ($LASTEXITCODE -ne 0) { throw "vagrant box repackage loi (box co trong 'vagrant box list -i' khong?)" }
        Rename-Item -Path (Join-Path $Dest 'package.box') -NewName $fileName
    } finally { Pop-Location }
}

Write-Host 'Tinh SHA256...'
$hash = (Get-FileHash $boxPath -Algorithm SHA256).Hash.ToLower()
"$hash  $fileName" | Out-File -Encoding ascii (Join-Path $Dest 'SHA256SUMS.txt')

$url = 'file:///' + ($boxPath -replace '\\', '/')
$catalog = [ordered]@{
    name     = $Box
    versions = @(@{
        version   = $Version
        providers = @(@{
            name                 = 'virtualbox'
            architecture         = 'amd64'
            default_architecture = $true
            url                  = $url
            checksum_type        = 'sha256'
            checksum             = $hash
        })
    })
}
$json = $catalog | ConvertTo-Json -Depth 6
# Ghi UTF-8 KHONG BOM (Vagrant/Ruby doc JSON co BOM co the loi)
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $Dest 'metadata.json'), $json, $enc)
$repoBoxes = Join-Path (Split-Path $PSScriptRoot -Parent) 'boxes'
New-Item -ItemType Directory -Force -Path $repoBoxes | Out-Null
[System.IO.File]::WriteAllText((Join-Path $repoBoxes 'metadata.json'), $json, $enc)

Write-Host ''
Write-Host "Xong:" -ForegroundColor Green
Write-Host "  $boxPath"
Write-Host "  SHA256 $hash"
Write-Host "  $(Join-Path $Dest 'metadata.json')  (va ban sao boxes\metadata.json trong repo)"
Write-Host ''
Write-Host 'Viec tiep theo: chep ca thu muc' $Dest 'sang 2 noi (o ngoai + Google Drive).'
