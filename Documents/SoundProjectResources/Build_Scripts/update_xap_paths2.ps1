$ErrorActionPreference = "Stop"

$xapPath = "I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioTools\.temp\sc_shared_banks\SC_shared_banks_FA_global.xap"
$baseDir = "I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioTools\.temp\sc_shared_banks"
$pcmDir = "I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioTools\.temp\sc_shared_banks\pcm_wavs"

# 旧提取目录映射
$oldDirs = @{}
$oldDirs["AmbientTest"] = "$baseDir\Ambient"
$oldDirs["FMV_BG"] = "$baseDir\FMV"
$oldDirs["Op_Briefing"] = "$baseDir\OP_Briefing"
$oldDirs["Tutorial_SE"] = "$baseDir\Tutorial_SE"
$oldDirs["Music"] = "$baseDir\Music\Music_Final\Looped"

# 读取 .xap 内容
$rawContent = [System.IO.File]::ReadAllText($xapPath)
$lines = $rawContent -split "
"

# 对每个共享 bank，建立旧文件 -> pcm_wavs 文件的 MD5 映射
$bankMappings = @{}

foreach ($bankName in $oldDirs.Keys) {
    $oldDir = $oldDirs[$bankName]
    $pcmBankDir = "$pcmDir\$bankName"
    
    if (!(Test-Path $oldDir) -or !(Test-Path $pcmBankDir)) {
        Write-Host "SKIP: $bankName (directory missing)"
        continue
    }
    
    # 计算旧文件 MD5
    $oldHashes = @{}
    foreach ($f in (Get-ChildItem $oldDir -Filter "*.wav")) {
        $hash = (Get-FileHash $f.FullName -Algorithm MD5).Hash
        $oldHashes[$f.BaseName] = $hash
    }
    
    # 计算 pcm_wavs 文件 MD5
    $pcmHashes = @{}
    foreach ($f in (Get-ChildItem $pcmBankDir -Filter "*.wav")) {
        $hash = (Get-FileHash $f.FullName -Algorithm MD5).Hash
        $pcmHashes[$f.BaseName] = $hash
    }
    
    # 建立映射：旧文件名 -> pcm_wavs 文件名
    $mapping = @{}
    foreach ($oldName in $oldHashes.Keys) {
        $oldHash = $oldHashes[$oldName]
        $match = $pcmHashes.GetEnumerator() | Where-Object { $_.Value -eq $oldHash } | Select-Object -First 1
        if ($match) {
            $mapping[$oldName] = $match.Key
        } else {
            Write-Host "WARNING: $bankName - no match for $oldName"
        }
    }
    
    $bankMappings[$bankName] = $mapping
    Write-Host "$bankName : $($mapping.Count) mappings (old=$($oldHashes.Count), pcm=$($pcmHashes.Count))"
}

# 修改 .xap 中的 File 路径
$modified = 0
for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    if ($line.Trim() -match "^File = (.+\.wav);$") {
        $filePath = $matches[1]
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
        
        # 找出属于哪个 bank
        $bankName = $null
        foreach ($bn in $oldDirs.Keys) {
            $oldDir = $oldDirs[$bn]
            if ($filePath -like "*$oldDir*") {
                $bankName = $bn
                break
            }
        }
        
        if ($bankName -and $bankMappings[$bankName].ContainsKey($fileName)) {
            $pcmFileName = $bankMappings[$bankName][$fileName]
            $newPath = "$pcmDir\$bankName\$pcmFileName.wav"
            $indent = ($line -replace "^(\s+).*", "$1")
            $lines[$i] = "$indent    File = $newPath;"
            $modified++
        }
    }
}

Write-Host "Modified $modified File paths"

# 保存修改后的 .xap
$newContent = $lines -join "
"
$backupPath = $xapPath + ".bak"
if (!(Test-Path $backupPath)) {
    [System.IO.File]::WriteAllText($backupPath, $rawContent)
}
[System.IO.File]::WriteAllText($xapPath, $newContent, [System.Text.UTF8Encoding]::new($false))
Write-Host "Saved to: $xapPath"
Write-Host "Backup at: $backupPath"