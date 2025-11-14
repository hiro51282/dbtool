param (
    [string]$jsonPath,
    [string]$outputPath
)
# $jsonPath = 'DBProject\generate-sql\insertFile_change_name_program.json'
# $outputPath = 'DBProject\insert-sql\20251112_change_name_program.sql'

$jsonPath = 'DBProject\generate-sql\insertFile_change_name_copy.json'
$outputPath = 'DBProject\insert-sql\20251112_change_name_copy.sql'
# === 設定読み込み ===
$json = Get-Content $jsonPath | ConvertFrom-Json
$table = $json.table_name
$cutoff_id = $json.cutoff_id
$inputFile = $json.input_file
$delimiter = if ($json.delimiter) { $json.delimiter } else { "`t" }
$colMap = [ordered]@{}
$json.columns.PSObject.Properties | ForEach-Object {
    $colMap[$_.Name] = $_.Value
}
# === 出力初期化 ===
$out = @()

# === 入力行処理 ===
Get-Content $inputFile | ForEach-Object {
    if ($_ -match "^\s*$") { return }  # 空行スキップ
    $parts = $_ -split $delimiter

    $values = [ordered]@{}

    foreach ($col in $colMap.Keys) {
        $mapVal = $colMap[$col]

        if ($mapVal -is [int] -or ($mapVal -match '^\d+$')) {
            # 数値の場合 → インデックス参照
            $idx = [int]$mapVal
            if ($idx -lt $parts.Count) {
                $values[$col] = $parts[$idx].Trim()
            }
            else {
                $values[$col] = ""
            }
        }
        elseif ($mapVal -eq "cutoff_id") {
            $values[$col] = $cutoff_id
        }
        else {
            $values[$col] = $mapVal
        }
    }

    # === SQL組み立て ===
    $cols = ($values.Keys -join ", ")
    $vals = ($values.Keys | ForEach-Object {
            $v = $values[$_]
            if ($v -is [int]) { return $v }
            elseif ([string]::IsNullOrWhiteSpace($v)) { return "NULL" }
            else { return "'$v'" }
        }) -join ", "

    $out += "INSERT INTO $table ($cols) VALUES ($vals);"
}

# === 出力 ===
$out | Out-File -FilePath $outputPath -Encoding UTF8
Write-Host " Generated SQL file: $outputPath"
