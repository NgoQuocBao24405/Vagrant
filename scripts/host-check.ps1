# host-check.ps1 - kiem tra may Windows truoc khi dung lab (in PASS/FAIL/WARN tung muc)
# Chay: mo PowerShell (nen Run as Administrator) trong thu muc repo:
#   powershell -ExecutionPolicy Bypass -File .\scripts\host-check.ps1
# Exit code 0 = khong co FAIL.

$ErrorActionPreference = 'SilentlyContinue'
$results = New-Object System.Collections.ArrayList
function Add-Result($status, $item, $detail) {
    [void]$results.Add([pscustomobject]@{ KetQua = $status; Muc = $item; ChiTiet = $detail })
}

# 1. Windows va phan cung
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
Add-Result 'INFO' 'Windows' "$($os.Caption) build $($os.BuildNumber)"
$ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
Add-Result ($(if ($ramGB -ge 7.5) {'PASS'} else {'FAIL'})) 'RAM >= 8 GB' "$ramGB GB"
$drive = (Get-Location).Drive.Name
$freeGB = [math]::Round((Get-PSDrive $drive).Free / 1GB, 1)
Add-Result ($(if ($freeGB -ge 40) {'PASS'} elseif ($freeGB -ge 25) {'WARN'} else {'FAIL'})) "O $drive`: trong >= 40 GB" "$freeGB GB"

# 2. Hypervisor cua Windows (nguyen nhan "rua xanh" trong VirtualBox)
$hv = [bool]$cs.HypervisorPresent
Add-Result ($(if (-not $hv) {'PASS'} else {'WARN'})) 'HypervisorPresent = False' "HypervisorPresent=$hv (True -> VirtualBox chay che do NEM, cham)"
$dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard
if ($dg) {
    $vbs = @('Tat','Bat nhung khong chay','Dang chay')[[int]$dg.VirtualizationBasedSecurityStatus]
    $svc = ($dg.SecurityServicesRunning | ForEach-Object { switch ($_) { 1 {'CredentialGuard'} 2 {'MemoryIntegrity'} 3 {'SecureLaunch'} 4 {'SMM'} 5 {'KernelStackProtection'} default {$null} } }) -join ', '
    Add-Result ($(if ($dg.VirtualizationBasedSecurityStatus -eq 2) {'WARN'} else {'PASS'})) 'VBS (Core isolation) tat' "VBS: $vbs; dich vu dang chay: $svc"
}
$bcd = (bcdedit /enum '{current}' 2>$null | Select-String 'hypervisorlaunchtype') -replace '\s+', ' '
if ($bcd) { Add-Result 'INFO' 'bcdedit' "$bcd" } else { Add-Result 'INFO' 'bcdedit' 'can quyen Admin de doc (hoac chua dat)' }

# 3. VirtualBox
$vbDir = $env:VBOX_MSI_INSTALL_PATH
if (-not $vbDir) { $vbDir = 'C:\Program Files\Oracle\VirtualBox\' }
$vbm = Join-Path $vbDir 'VBoxManage.exe'
if (Test-Path $vbm) {
    $vbv = (& $vbm --version).Trim()
    Add-Result ($(if ($vbv -like '7.2.*') {'PASS'} else {'FAIL'})) 'VirtualBox 7.2.x' $vbv
} else { Add-Result 'FAIL' 'VirtualBox 7.2.x' "khong thay $vbm" }

# 4. Vagrant, box, plugin
$vg = (vagrant --version) -replace 'Vagrant ', ''
if ($vg) {
    Add-Result ($(if ($vg.Trim() -eq '2.4.9') {'PASS'} else {'WARN'})) 'Vagrant 2.4.9' $vg.Trim()
    $boxes = vagrant box list -i 2>$null | Out-String
    $hasBox = $boxes -match 'bento/ubuntu-24.04\s+\(virtualbox, 202510.26.0'
    Add-Result ($(if ($hasBox) {'PASS'} else {'FAIL'})) 'Box bento/ubuntu-24.04 202510.26.0 trong cache' ($(if ($hasBox) {'co'} else {'chua co - xem docs/HuongDan buoc 2'}))
    $plugins = vagrant plugin list 2>$null | Out-String
    Add-Result ($(if ($plugins -match 'vagrant-vbguest') {'WARN'} else {'PASS'})) 'Khong dung plugin vagrant-vbguest' $plugins.Trim()
} else { Add-Result 'FAIL' 'Vagrant 2.4.9' 'khong chay duoc lenh vagrant' }

# 5. Git
$git = git --version
if ($git) {
    Add-Result 'PASS' 'Git' $git
    $acrlf = git config --global core.autocrlf
    Add-Result ($(if ($acrlf -eq 'input') {'PASS'} else {'WARN'})) 'git core.autocrlf = input' "hien tai: '$acrlf'"
} else { Add-Result 'FAIL' 'Git' 'chua cai Git' }

# 6. Ban sao luu box (khuyen nghi)
$arch = 'D:\vagrant-boxes\metadata.json'
Add-Result ($(if (Test-Path $arch) {'PASS'} else {'WARN'})) 'Ban luu tru box cuc bo' ($(if (Test-Path $arch) {$arch} else {'chua co - chay scripts\box-archive.ps1'}))

# In ket qua
''
foreach ($r in $results) {
    $color = switch ($r.KetQua) { 'PASS' {'Green'} 'FAIL' {'Red'} 'WARN' {'Yellow'} default {'Gray'} }
    Write-Host ('{0,-5} {1,-48} {2}' -f $r.KetQua, $r.Muc, $r.ChiTiet) -ForegroundColor $color
}
$nFail = @($results | Where-Object KetQua -eq 'FAIL').Count
''
if ($nFail -gt 0) { Write-Host "$nFail muc FAIL - xem docs\HuongDan_Tuan1-5.md" -ForegroundColor Red; exit 1 }
Write-Host 'Khong co FAIL. WARN = nen sua nhung van chay duoc.' -ForegroundColor Green
exit 0
