param(
    [string]$ConfigPath = ".\Config.json"
)

# 設定読み込み
if (!(Test-Path $ConfigPath)) {
    Write-Host "Config.json が見つかりません: $ConfigPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $ConfigPath | ConvertFrom-Json

$mysqlExe = $config.mysql_path
$confighost     = $config.host
$user     = $config.user
$pass     = $config.password
$db       = $config.database

if (!(Test-Path $mysqlExe)) {
    Write-Host "mysql.exe が見つかりません: $mysqlExe" -ForegroundColor Red
    exit 1
}

Write-Host "=== SQL実行開始 ===" -ForegroundColor Cyan

# schema/*.sql を昇順に取得
$files = Get-ChildItem -Path "./schema" -Filter "*.sql" | Sort-Object Name

foreach ($f in $files) {
    Write-Host "実行中: $($f.Name)" -ForegroundColor Yellow

    & $mysqlExe `
        --host=$confighost `
        --user=$user `
        --password=$pass `
        --database=$db `
        -e "source $($f.FullName)"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "エラー発生: $($f.Name)" -ForegroundColor Red
        exit 1
    }
}

Write-Host "=== 全SQLの実行が完了しました ===" -ForegroundColor Green
