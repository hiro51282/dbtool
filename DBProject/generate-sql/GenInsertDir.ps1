param(
    [string]$jsonFile,
    [string]$outputFile
)
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
            # $map[$table][$col] = $reftb
        }
    }
    return $map
}

# ==========================================
# 関数：参照先のIDを解決する（自動判定）
#TODO:効率悪し。改善の余地あり、いっそのこといったんハードコーディングしてから改良してもよい
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
    # 外部キーのスキップリスト
    $skipcol = @("cutoff_id")

    # 外部キー解決
    if ($fkMap.ContainsKey($table)) {
        # TODO：ハードコーディングしたほうがいいかも
        # javaテーブルに紐づくCOBOLIDの取得
        $fkMap[$table]
        #TODO$tableをSelectですべて取得するとか？
        foreach ($fkCol in $fkMap[$table]) {
            $refTable = $fkMap[$table].REFERENCED_TABLE_NAME
            if ($skipcol.Contains($fkCol.COLUMN_NAME)) {
                continue
            }
            $values[$fkCol.COLUMN_NAME] = -1
            # $values[$fkCol.COLUMN_NAME] = Resolve-ForeignId $refTable $name
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
