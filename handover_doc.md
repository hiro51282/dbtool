# 構成管理DB・スクリプト基盤

本資料は、COBOL→Java マイグレーション資産に対する構成管理を目的とした「DBプロジェクト」と「PowerShellスクリプト基盤」の運用・保守のための引き継ぎ資料です。

---
## 1. システム概要
本システムは、COBOL資産および変換後Java資産を断面ごとに整然と管理するために、以下を提供します：

- **MySQLベースの内部管理DB**
- **スクリプトによる入力データ（COBOL/Java/Excel等）の解析**
- **INSERT/UPDATE SQLの自動生成と実行**
- **構成管理・リリース管理の補助**

Gitだけでは扱いきれない以下の課題を解決：
- ブランチ断面により "どのファイルが最新か" 判断困難
- 受領断面／リリース断面の管理が曖昧
- 変換対象・不要対象の区別が属人化

---
## 2. 開発環境
### 2.1 インストール済みソフト
- MySQL 5.6/5.7
- Visual Studio Code
  - PowerShell拡張
  - SQL言語系拡張
- PowerShell 5.1（標準）

---
## 3. プロジェクト構成（ディレクトリ）
```
DBProject/
  schema/           ← CREATE/ALTER文（スキーマ管理）
  configs/          ← 定義ファイル（入力→DBマッピング）
  generate-sql/     ← SQL生成スクリプト（PowerShell）
  insert-sql/       ← 生成されたINSERT/UPDATE SQL
  queries/          ← よく使うSELECT文
  execute/          ← SQL実行用スクリプト
  docs/             ← ドキュメント類（本資料含む）
```

---
## 4. テーブル構成（概要）
※詳細は `schema/001_create_tables.sql` を参照

### 4.1 asset_cutoff（断面情報）
| カラム | 内容 |
|--------|------|
| cutoff_id (PK) | 断面ID |
| cutoff_date | 受領日・断面日 |
| description | 補足説明 |

### 4.2 cobol_asset（受領COBOL資産）
| カラム | 内容 |
|--------|------|
| asset_id (PK) | 一意ID |
| path | ファイルパス（相対） |
| hash_sha256 | ファイルハッシュ |
| cutoff_id (FK) | 所属断面 |
| received_date | 受領日 |

### 4.3 java_asset（変換後Java資産）
構造は cobol_asset に準ずる。

---
## 5. スクリプト基盤の仕組み
### 5.1 基本思想
- スクリプトにハードコーディングしない
- 入力形式（Directory, Excel, CSV）は **定義ファイルで吸収**
- PowerShellスクリプトは **1本の汎用処理**

### 5.2 主スクリプト一覧
| スクリプト | 役割 |
|------------|------|
| Generate.ps1 | 定義ファイルに従い SQL を生成 |
| RunSql.ps1 | 生成したSQLをMySQLへ投入 |
| Helpers.ps1 | ハッシュ生成、Excel読取など補助関数 |

---
## 6. 運用フロー
### 6.1 新断面受領時
1. `configs/xxxx.json` に定義追加または新規作成
2. データ（COBOL/Javaファイル）を `data/` 配下へ配置
3. PowerShellで SQL生成：
   ```powershell
   ./generate-sql/Generate.ps1 -Config "configs/cobol.json"
   ```
4. 生成SQLを確認し `insert-sql/` に保存
5. MySQLへ投入：
   ```powershell
   ./execute/RunSql.ps1 -File "insert-sql/20250215_new_cutoff.sql"
   ```

### 6.2 スキーマ変更時
1. `schema/00X_alter_xxxx.sql` を作成
2. SQLを実行
3. docs/ に変更理由と経緯を記載

### 6.3 バックアップ
- 週1回、`mysqldump` にて全体バックアップ取得

---
## 7. 注意事項
- **スキーマ変更は必ずSQLファイル化すること（履歴管理）**
- **insert-sql は必ず残す（証跡のため）**
- **定義ファイルとスクリプトのハードコードは禁止**
- **外部への持出禁止・閉塞環境内で完結すること**

---
## 8. 今後の拡張予定（任意）
- 不要資産判定の自動化
- リリース単位の差分出力
- Gitのdevelopとの差異比較支援

---
以上。

