# cd generate-sql
# .\GenInsert.ps1 -CutoffId 3 -InputDir "../data/cobol_raw/programs"

param(
    # [Parameter(Mandatory=$true)]
    # [int]$CutoffId,

    # [Parameter(Mandatory=$true)]
    # [string]$InputDir,

    # [string]$OutputDir = "../insert-sql"
)

$CutoffId=3
$InputDir="../data/cobol_raw/programs"
$OutputDir = "../insert-sql"

# ディレクトリ存在確認
if (!(Test-Path $InputDir)) {
    Write-Host "入力ディレクトリが存在しません: $InputDir" -ForegroundColor Red
    exit 1
}

# 出力ディレクトリ作成
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# 今日の日付
$today = (Get-Date).ToString("yyyyMMdd")
$outputFile = Join-Path $OutputDir "${today}_program_cobol.sql"

# COBOLファイル一覧取得
$files = Get-ChildItem -Path $InputDir -File -Recurse

if ($files.Count -eq 0) {
    Write-Host "対象ファイルがありません: $InputDir" -ForegroundColor Yellow
    exit 0
}

Write-Host "対象ファイル数: $($files.Count)" -ForegroundColor Cyan
Write-Host "出力SQL: $outputFile" -ForegroundColor Cyan

$valuesList = @()

foreach ($f in $files) {

    # パス（相対パス or 絶対パス） ※必要に応じ変更可
    $path = $f.FullName.Replace("\","/")

    # SHA-256
    $hash = (Get-FileHash -Algorithm SHA256 -Path $f.FullName).Hash.ToLower()

    # program_name = ファイル名（拡張子なし）
    $programName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)

    # VALUES句用にSQLエスケープ
    $pathSql = $path.Replace("'", "''")
    $programNameSql = $programName.Replace("'", "''")

    $valuesList += "($CutoffId, '$pathSql', '$hash', '$programNameSql')"
}

# SQL文生成
$sql = @()
$sql += "INSERT INTO program_cobol (cutoff_id, file_path, hash, program_name)"
$sql += "VALUES"
$sql += ($valuesList -join ",`n")
$sql += ";"

# 出力
$sql | Set-Content -Path $outputFile -Encoding UTF8

Write-Host "SQL生成完了: $outputFile" -ForegroundColor Green
