$unxwb = "I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioTools\unxwb.exe"
$scSounds = "I:\SteamLibrary\steamapps\common\Supreme Commander\sounds"
$voPath = "$scSounds\Voice\US_BAK"

$offsets = @{
    "AmbientTest" = "0x032F"
    "FMV_BG" = "0x034A"
    "Op_Briefing" = "0x080C"
    "Tutorial_SE" = "0x043C"
    "Music" = "0x048C"
    "A01_VO" = "0x06ED"
    "A02_VO" = "0x0663"
    "A03_VO" = "0x05E6"
    "A04_VO" = "0x05E6"
    "A05_VO" = "0x0951"
    "A06_VO" = "0x0870"
    "C01_VO" = "0x0A96"
    "C02_VO" = "0x08F2"
    "C03_VO" = "0x08D9"
    "C04_VO" = "0x0893"
    "C05_VO" = "0x0951"
    "C06_VO" = "0x0A50"
    "E01_VO" = "0x0929"
    "E02_VO" = "0x0AF0"
    "E03_VO" = "0x09F1"
    "E04_VO" = "0x0A35"
    "E05_VO" = "0x0BC2"
    "E06_VO" = "0x0AF0"
}

$sharedBanks = @("AmbientTest", "FMV_BG", "Op_Briefing", "Tutorial_SE", "Music")
$voBanks = @("A01_VO","A02_VO","A03_VO","A04_VO","A05_VO","A06_VO","C01_VO","C02_VO","C03_VO","C04_VO","C05_VO","C06_VO","E01_VO","E02_VO","E03_VO","E04_VO","E05_VO","E06_VO")
$allBanks = $sharedBanks + $voBanks

$outputFile = "I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioTools\.temp\sc_shared_banks\xsb_cue_order.txt"
$sb = [System.Text.StringBuilder]::new()

foreach ($bank in $allBanks) {
    $isShared = $sharedBanks -contains $bank
    $xsbFile = if ($isShared) { "$scSounds\$bank.xsb" } else { "$voPath\$bank.xsb" }
    $xwbFile = if ($isShared) { "$scSounds\$bank.xwb" } else { "$voPath\$bank.xwb" }
    $outDir = "I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\AudioTools\.temp\sc_shared_banks\xsb_order\$bank"
    
    if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    
    $offset = $offsets[$bank]
    & $unxwb -b $xsbFile $offset -d $outDir $xwbFile 2>&1 | Out-Null
    
    # unxwb outputs files named by cue name. Get them by file system order (which is alphabetical)
    # But we need the physical order from the XWB, which is the cue order from the XSB
    # The files are named by cue name, so we need to capture the unxwb output order
    $output = & $unxwb -b $xsbFile $offset -d $outDir $xwbFile 2>&1
    $cueNames = @()
    foreach ($line in $output) {
        if ($line -match '\.wav$') {
            $name = ($line.Trim() -split '\s+')[-1] -replace '\.wav$',''
            $cueNames += $name
        }
    }
    
    $count = $cueNames.Count
    [void]$sb.AppendLine("=== $bank ($count cues) ===")
    for ($i = 0; $i -lt $count; $i++) {
        [void]$sb.AppendLine("[$i] $($cueNames[$i])")
    }
    [void]$sb.AppendLine("")
    Write-Host "$bank : $count cues"
}

[System.IO.File]::WriteAllText($outputFile, $sb.ToString())
Write-Host ""
Write-Host "Done: $outputFile"