# ============================================
# DBProject ディレクトリ構成 自動生成スクリプト
# ============================================

$root = "DBProject"

# 作成するディレクトリ一覧
$dirs = @(
    "$root/schema",
    "$root/data/cobol_raw",
    "$root/data/java_raw",
    "$root/data/processed",
    "$root/generate-sql",
    "$root/insert-sql",
    "$root/execute",
    "$root/queries"
)

# 作成する空ファイル一覧
$files = @(
    "$root/schema/001_create_tables.sql",
    "$root/schema/002_alter_tables_xxxx.sql",
    "$root/schema/README.md",

    "$root/generate-sql/GenInsert.ps1",
    "$root/generate-sql/GenUpdate.ps1",
    "$root/generate-sql/GenDelete.ps1",
    "$root/generate-sql/GenAssetHash.ps1",
    "$root/generate-sql/LoadFiles.ps1",

    "$root/insert-sql/20250101_initial_insert.sql",
    "$root/insert-sql/20250315_new_cutoff.sql",
    "$root/insert-sql/20250403_fix_paths.sql",

    "$root/execute/RunSql.ps1",
    "$root/execute/Config.json",

    "$root/queries/find_latest_cutoff.sql",
    "$root/queries/list_java_by_cutoff.sql",
    "$root/queries/check_integrity.sql"
)

Write-Host "◆ DBProject ディレクトリを作成します..."

# ディレクトリ作成
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d | Out-Null
        Write-Host "  [DIR]   $d"
    } else {
        Write-Host "  [SKIP]  $d (exists)"
    }
}

# ファイル作成
foreach ($f in $files) {
    if (-not (Test-Path $f)) {
        New-Item -ItemType File -Path $f | Out-Null
        Write-Host "  [FILE]  $f"
    } else {
        Write-Host "  [SKIP]  $f (exists)"
    }
}

Write-Host "`n? 完了しました！ DBProject の初期構成が生成されました。"
