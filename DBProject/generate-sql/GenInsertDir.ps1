<#
.SYNOPSIS
  ディレクトリ内ファイルを読み込み、
  INSERT 文を生成するスクリプト（COBOL / Java 両対応）。

.PARAMETER jsonFile
  入力定義 JSON ファイルのパス

.PARAMETER outputFile
  出力 SQL ファイルのパス

.EXAMPLE
  .\GenInsertDir.ps1 -jsonFile .\config\input_program_java.json -outputFile .\insert_program_java.sql
#>
param (
    # [Parameter(Mandatory = $true)]
    # [string]$jsonFile,
    # [Parameter(Mandatory = $true)]
    # [string]$outputFile
)
# コピー句 COBOL
$jsonFile = 'DBProject\generate-sql\insert_copy_cobol.json'
$outputFile = 'DBProject\insert-sql\20251112_copy_cobol.sql'

# 処理部 COBOL
$jsonFile = 'DBProject\generate-sql\insert_program_cobol.json'
$outputFile = 'DBProject\insert-sql\20251112_program_cobol.sql'

# コピー句 Java（コピー句 COBOL登録後でないと実行できない）
$jsonFile = 'DBProject\generate-sql\insert_copy_java.json'
$outputFile = 'DBProject\insert-sql\20251112_copy_java.sql'

#処理部 Java（処理部 COBOL登録後でないと実行できない）
$jsonFile = 'DBProject\generate-sql\insert_program_java.json'
$outputFile = 'DBProject\insert-sql\20251112_program_java.sql'

# 設定読み込み
if (!(Test-Path $jsonFile)) {
    Write-Error "JSON file not found: $jsonFile"
    exit 1
}
# ==========================================
# 設定部
# ==========================================

$json = Get-Content $jsonFile | ConvertFrom-Json
$inputDir = $json.input_directory
$table = $json.table_name
$cutoffId = $json.cutoff_id

# JSON columns をハッシュテーブルに変換
$colMap = [ordered]@{}
$json.columns.PSObject.Properties | ForEach-Object {
    $colMap[$_.Name] = $_.Value
}

# ==========================================
# 関数：外部キー関係を全取得
# ==========================================
function Invoke-MySqlQuery($query) {
    $mysqlExe = "mysql.exe"
    $user = "root"
    $password = "qawsedrf"
    $database = "dd"

    $sqlargs = @(
        "-u", $user,
        "-p$($password)",
        "-D", $database,
        "-e", $query,
        "--batch",
        "--skip-column-names"
    )
    & $mysqlExe @sqlargs
}

# ==========================================
# 廃止関数：外部キー関係を全取得
# ==========================================
function Get-ForeignKeyMap {


    $query = @"
SELECT 
    TABLE_NAME, 
    COLUMN_NAME, 
    REFERENCED_TABLE_NAME, 
    REFERENCED_COLUMN_NAME 
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = '$database'
  AND REFERENCED_TABLE_NAME IS NOT NULL;
"@
    $result = Invoke-MySqlQuery $query
    $map = @{}
    foreach ($line in $result) {
        $parts = $line -split "\t"
        if ($parts.Length -eq 4) {
            $table = $parts[0]
            $col = $parts[1]
            $reftb = $parts[2]
            $refcname = $parts[3]
            if (-not $map.ContainsKey($table)) {
                $map[$table] = @()
            }
            $map[$table] += [PSCustomObject]@{
                COLUMN_NAME            = $col
                REFERENCED_TABLE_NAME  = $reftb
                REFERENCED_COLUMN_NAME = $refcname
            }
        }
    }
    return $map
}

# ==========================================
# 廃止関数：参照先のIDを解決する（自動判定）
# ==========================================
function Resolve-ForeignId($refTable, $searchName) {
    $colName = ""
    switch ($refTable) {
        "program_cobol" { $colName = "program_name" }
        "copy_cobol" { $colName = "copy_name" }
        "cutoff" { $colName = "id" }  # cutoff は直接 ID 指定
        default { return -1 }  # 未対応テーブル
    }

    if ($refTable -eq "cutoff") {
        return $searchName  # cutoff_id は直接渡される想定
    }

    $query = "SELECT id FROM $refTable WHERE $colName = '$searchName' LIMIT 1;"
    $result = Invoke-MySqlQuery $query
    if ($result) { return [int]$result } else { return -1 }
}

# $fkMap = Get-ForeignKeyMap

# ==========================================
# COBOL テーブルから “name → id” 辞書化
# ==========================================
function Get-CobolIdMap($cutoffId) {
    $map = @{}

    $queryCopyCob = "SELECT id, copy_name FROM copy_cobol WHERE cutoff_id = $cutoffId;"
    $rows1 = Invoke-MySqlQuery $queryCopyCob
    foreach ($r in $rows1) {
        $p = $r -split "\t"
        if ($p.Length -ge 2) { $map[$p[1].ToUpper()] = [int]$p[0] }
    }

    $queryProgCob = "SELECT id, program_name FROM program_cobol WHERE cutoff_id = $cutoffId;"
    $rows2 = Invoke-MySqlQuery $queryProgCob
    foreach ($r in $rows2) {
        $p = $r -split "\t"
        if ($p.Length -ge 2) { $map[$p[1].ToUpper()] = [int]$p[0] }
    }


    return $map
}

# ==========================================
# 名前変換テーブルから COBOL→Java 名を辞書化
# ==========================================
function Get-RenameMap($cutoffId) {
    $map = @{}

    # copy 句用
    $queryCopy = "SELECT cobol_name, java_name FROM change_name_copy WHERE cutoff_id = $cutoffId;"
    $rowsCopy = Invoke-MySqlQuery $queryCopy
    foreach ($r in $rowsCopy) {
        $p = $r -split "\t"
        if ($p.Length -ge 2) { $map[$p[0].ToUpper()] = $p[1] }
    }

    # 処理部用
    $queryProg = "SELECT cobol_name, java_name FROM change_name_program WHERE cutoff_id = $cutoffId;"
    $rowsProg = Invoke-MySqlQuery $queryProg
    foreach ($r in $rowsProg) {
        $p = $r -split "\t"
        if ($p.Length -ge 2) { $map[$p[0].ToUpper()] = $p[1] }
    }

    return $map
}

# ==========================================
# COBOL テーブルと名前変換テーブルから “Java名 → COBOL ID” 辞書化
# ==========================================
function Get-ChangeNameMap($cobolIdMap, $renameMap) {
    $map = @{}

    foreach ($cobol in $cobolIdMap.GetEnumerator()) {
        $cobolName = $cobol.Key
        $cobolId = $cobol.Value
        if ($renameMap.ContainsKey($cobolName)) {
            $cobolName = $renameMap[$cobolName]
        }
        $map[$cobolName] = $cobolId
    }

    return $map

}

$cobolIdMap = Get-CobolIdMap $cutoffId
$renameMap = Get-RenameMap $cutoffId
$changeNameMap = Get-ChangeNameMap $cobolIdMap $renameMap

# ==========================================
# メイン処理
# ==========================================
$insertLines = @()

foreach ($file in Get-ChildItem $inputDir -Recurse) {
    $hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash.ToLower()
    $name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $path = $file.FullName.Replace("\", "/")

    $values = @{}
    foreach ($col in $colMap.Keys) {
        switch ($colMap[$col]) {
            "ref_id" { $values[$col] = $changeNameMap[$name.ToUpper()] }
            "hash" { $values[$col] = $hash }
            "file_path" { $values[$col] = $path }
            "program_name" { $values[$col] = $name }
            "copy_name" { $values[$col] = $name }
            default {
                $definedval = $json.PSObject.Properties | Where-Object { $_.Name -eq $col }
                if ($definedval) {
                    $values[$col] = $definedval.Value
                }
                else {
                    $values[$col] = "NULL" 
                }
            }
        }
    }

    $cols = ($values.Keys -join ", ")
    $vals = ($values.Values | ForEach-Object {
            if ($_ -is [int]) { return $_ }
            elseif ($_ -eq "NULL") { return "NULL" }
            else { return "'$_'" }
        }) -join ", "

    $insertLines += "INSERT INTO $table ($cols) VALUES ($vals);"
}

$insertLines | Out-File $outputFile -Encoding UTF8
Write-Host " $outputFile に INSERT文を出力しました"
