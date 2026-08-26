# Scan E:\BGM库 and regenerate CATALOG.md; commit & push only when content changed.
# Runs daily via Windows Task Scheduler (task: "BGM Catalog Sync"). PowerShell 5.1 compatible.
$ErrorActionPreference = 'Stop'
$LibRoot = 'E:\BGM库'
$RepoDir = 'D:\bgm-search-cheatsheet'
$Catalog = Join-Path $RepoDir 'CATALOG.md'
$LogFile = Join-Path $env:LOCALAPPDATA 'bgm-catalog-sync.log'

function Log($msg) {
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg"
}

try {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# 曲库目录')
    $lines.Add('')
    $lines.Add('> 由 sync_catalog.ps1 每日自动生成，请勿手工编辑。文件本体在本地 `E:\BGM库`，此处仅为库存索引（遵守 Pixabay 许可，不再分发素材）。')
    $lines.Add('> 精选使用笔记见 [LIBRARY.md](LIBRARY.md)。同步历史见 git log。')
    $lines.Add('')

    $dirs = Get-ChildItem -Path $LibRoot -Directory | Sort-Object Name
    foreach ($d in $dirs) {
        $files = Get-ChildItem -Path $d.FullName -File |
            Where-Object { $_.Extension -match '^\.(mp3|wav|flac|m4a|ogg|aif|aiff)$' } |
            Sort-Object Name
        if ($d.Name -eq '_inbox') {
            if (-not $files) { continue }  # empty inbox: omit section entirely
            $lines.Add("## _inbox（待分类：$($files.Count) 首积压）")
        } else {
            $lines.Add("## $($d.Name)")
        }
        $lines.Add('')
        if (-not $files) { $lines.Add('（空）'); $lines.Add(''); continue }
        $lines.Add('| 文件 | 大小 | 入库日期 | 来源 |')
        $lines.Add('|---|---|---|---|')
        foreach ($f in $files) {
            $sizeMB = [math]::Round($f.Length / 1MB, 1)
            $date = $f.LastWriteTime.ToString('yyyy-MM-dd')
            $src = ''
            if ($f.BaseName -match '-(\d{5,7})$') { $src = "Pixabay #$($Matches[1])" }
            $lines.Add("| $($f.Name) | ${sizeMB}MB | $date | $src |")
        }
        $lines.Add('')
    }

    # BOM-less UTF-8 regardless of PS version, so reruns never produce spurious diffs
    [System.IO.File]::WriteAllLines($Catalog, $lines, (New-Object System.Text.UTF8Encoding $false))

    git -C $RepoDir add CATALOG.md
    git -C $RepoDir diff --cached --quiet -- CATALOG.md
    if ($LASTEXITCODE -ne 0) {
        git -C $RepoDir commit -m 'chore: sync library catalog' | Out-Null
        Log 'catalog changed, committed'
    } else {
        Log 'no change'
    }
    # Always push: no-op when up to date, and delivers any commit stranded by an earlier network failure
    git -C $RepoDir push --quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Log 'push failed (will retry next run)' } else { Log 'push ok' }
} catch {
    Log "ERROR: $($_.Exception.Message)"
    exit 1
}
