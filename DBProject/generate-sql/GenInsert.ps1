param(
    [int]$cutoff_id,
    [string]$jsonFile,
    [string]$outputFile
)
$cutoff_id = 1

# $jsonFile = 'DBProject\generate-sql\insert_copy_cobol.json'
# $outputFile = 'DBProject\insert-sql\20251112_copy_cobol.sql'

# $jsonFile = 'DBProject\generate-sql\insert_copy_java.json'
# $outputFile = 'DBProject\insert-sql\20251112_copy_java.sql'

# $jsonFile = 'DBProject\generate-sql\insert_program_cobol.json'
# $outputFile = 'DBProject\insert-sql\20251112_program_cobol.sql'

$jsonFile = 'DBProject\generate-sql\insert_program_java.json'
$outputFile = 'DBProject\insert-sql\20251112_program_java.sql'

# ==========================================
# 設定部
# ==========================================
$mysqlExe = "mysql.exe"
$user = "root"
$password = "qawsedrf"
$database = "dd"
function Invoke-MySqlQuery($query) {
    $args = @(
        "-u", $user,
        "-p$($password)",
        "-D", $database,
        "-e", $query,
        "--batch",
        "--skip-column-names"
    )
    & $mysqlExe @args
}
# ==========================================
# 関数：外部キー関係を全取得
# ==========================================
function Get-ForeignKeyMap {


    $query = @"
SELECT TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
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
            if (-not $map.ContainsKey($table)) {
                $map[$table] = @{}
            }
            $map[$table][$col] = $reftb
        }
    }
    return $map
}

# ==========================================
# 関数：参照先のIDを解決する（自動判定）
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
    # $result = & $mysqlExe -u$user -p$password -D$database -e $query --batch --skip-column-names
    if ($result) { return [int]$result } else { return -1 }
}

# ==========================================
# メイン処理
# ==========================================

$json = Get-Content $jsonFile | ConvertFrom-Json
$inputDir = $json.input_directory
$table = $json.table_name

# JSON columns をハッシュテーブルに変換
$colMap = [ordered]@{}
$json.columns.PSObject.Properties | ForEach-Object {
    $colMap[$_.Name] = $_.Value
}
$fkMap = Get-ForeignKeyMap

$insertLines = @()

foreach ($file in Get-ChildItem $inputDir -Recurse) {
    $hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash.ToLower()
    $name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $path = $file.FullName.Replace("\", "/")

    $values = @{}
    foreach ($col in $colMap.Keys) {
        switch ($colMap[$col]) {
            "cutoff_id" { $values[$col] = $cutoff_id }
            "hash" { $values[$col] = $hash }
            "file_path" { $values[$col] = $path }
            "program_name" { $values[$col] = $name }
            "copy_name" { $values[$col] = $name }
            default { $values[$col] = "NULL" }
        }
    }
    # 外部キーごとの処理方針
    $fkPolicy = @{
        "cutoff_id"  = { param($refTable, $name) return $cutoff_id }
        "created_by" = { param($refTable, $name) return "system" }
    }

    # 外部キー解決
    if ($fkMap.ContainsKey($table)) {
        foreach ($fkCol in $fkMap[$table].Keys) {
            $refTable = $fkMap[$table][$fkCol]
            if ($fkPolicy.ContainsKey($fkCol)) {
                $resolvedId = & $fkPolicy[$fkCol] $refTable $name
            }
            else {
                $resolvedId = Resolve-ForeignId $refTable $name
            }
            $values[$fkCol] = $resolvedId
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
Write-Host "? $outputFile に INSERT文を出力しました"
