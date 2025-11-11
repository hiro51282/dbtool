param(
    # [Parameter(Mandatory = $true)]
    # [int]$CutoffId,                # 断面ID（外部キー）

    # [Parameter(Mandatory = $true)]
    # [string]$JsonPath,             # 設定JSON

    # [Parameter(Mandatory = $true)]
    # [string]$OutputSqlPath         # 出力SQLファイル
)
$scriptpath = (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $scriptpath
# ------------------------------------------------------
# 0. パラメータ（テスト用デフォルト値）

$CutoffId = 3
$JsonPath = "./insert_program_java.json"
$OutputSqlPath = "./../insert-sql/20251111_program_java.sql"
# ------------------------------------------------------
# 1. JSON 読み込み
# ------------------------------------------------------
if (!(Test-Path $JsonPath)) {
    Write-Error "JSON file not found: $JsonPath"
    exit 1
}

$json = Get-Content $JsonPath -Raw | ConvertFrom-Json

$inputDir = $json.input_directory
$tableName = $json.table_name
# JSON columns をハッシュテーブルに変換
$colMap = [ordered]@{}
$json.columns.PSObject.Properties | ForEach-Object {
    $colMap[$_.Name] = $_.Value
}

$paramFile = $json.rename_param_file   # COBOL→COBOL名変換パラメータ（任意）

# ------------------------------------------------------
# 2. 変換パラメータ（AAA TAB ABC）から逆マップ作成
# ------------------------------------------------------
$reverseMap = @{}
if ($paramFile -and (Test-Path $paramFile)) {
    foreach ($line in Get-Content $paramFile) {
        if ($line.Trim() -eq "") { continue }

        $parts = $line -split "`t"
        if ($parts.Length -ge 2) {
            $orig = $parts[0].Trim().ToUpper()   # AAA
            $conv = $parts[1].Trim().ToUpper()   # ABC

            # 逆マップ ABC → AAA
            $reverseMap[$conv] = $orig
        }
    }
}

# ------------------------------------------------------
# 3. DB検索のための MySQL コマンド（ローカル接続前提）
# ------------------------------------------------------
function Query($sql) {
    $cmd = "mysql -N -e `" $sql `" dd"
    return Invoke-Expression $cmd 2>$null
}

# ------------------------------------------------------
# 4. COBOL の program_id を解決する関数
# ------------------------------------------------------
function Resolve-CobolId($javaName) {

    # Step 1: Java名 → Upper にする
    $upper = $javaName.ToUpper()

    # DB検索（直接一致）
    $sql = "SELECT id FROM program_cobol WHERE program_name = '$upper';"
    $rows = Query $sql

    if ($rows.Count -eq 1) {
        return [int]$rows
    }

    # Step 2: 変換パラメータの逆マップで検索
    if ($reverseMap.ContainsKey($upper)) {
        $origName = $reverseMap[$upper]

        $sql2 = "SELECT id FROM program_cobol WHERE program_name = '$origName';"
        $rows2 = Query $sql2

        if ($rows2.Count -eq 1) {
            return [int]$rows2
        }
    }

    # Step 3: 解決できなかった
    return -1
}

# ------------------------------------------------------
# 5. SHA-256 を計算する関数
# ------------------------------------------------------
function Get-FileHashHex($path) {
    $h = Get-FileHash $path -Algorithm SHA256
    return $h.Hash.ToLower()
}

# ------------------------------------------------------
# 6. 出力先 SQL を初期化
# ------------------------------------------------------
"BEGIN;" | Out-File $OutputSqlPath -Encoding utf8

# ------------------------------------------------------
# 7. 入力ディレクトリからファイル一覧を取得して INSERT を生成
# ------------------------------------------------------
$files = Get-ChildItem $inputDir -Recurse -File

foreach ($f in $files) {

    $fullPath = $f.FullName.Replace("\", "/")
    $fileName = $f.BaseName        # 拡張子なし
    $hash = Get-FileHashHex $f.FullName

    # カラムマッピングに従って値を設定
    $values = @{}

    foreach ($key in $colMap.Keys) {
        switch ($colMap[$key]) {

            "cutoff_id" { $values[$key] = $CutoffId }
            "file_path" { $values[$key] = $fullPath }
            "hash" { $values[$key] = $hash }
            "program_name" { $values[$key] = $fileName }  # Java/Cobol 名
            "copy_name" { $values[$key] = $fileName }

            "program_id" {
                $progid = Resolve-CobolId $fileName
                $values[$key] = $progid
            }

            default {
                $values[$key] = ""
            }
        }
    }

    # INSERT行を作成
    $cols = ($colMap.Keys -join ", ")
    $vals = ($values.Keys | ForEach-Object {
            $v = $values[$_]
            if ($v -is [int]) { "$v" }   # 数値 → クォートしない
            else { "'$v'" }              # 文字列 → シングルクォート
        }) -join ", "


    "INSERT INTO $tableName ($cols) VALUES ($vals);" | Out-File $OutputSqlPath -Append -Encoding utf8
}

"COMMIT;" | Out-File $OutputSqlPath -Append -Encoding utf8

Write-Host "Generated SQL → $OutputSqlPath"
