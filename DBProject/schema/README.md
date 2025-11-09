
# DB Schema 管理 (MySQL 5.7)

このディレクトリは、DB スキーマの定義および変更履歴を管理するための場所です。
ファイルは **番号順** に実行される想定です。

---

## ディレクトリ構成

```

schema/
├─ 001_create_tables.sql        初期テーブル作成
├─ 002_alter_tables_20251106_add_last_update.sql
└─ README.md                    ← このファイル

```

---

# 運用ルール

## 1. ファイル命名規則

```

NNN_description_yyyyMMdd_optional.sql

```

例：

- 001_create_tables.sql  
- 002_alter_tables_20251106_add_last_update.sql  
- 003_alter_tables_20251201_add_index.sql  

番号は **衝突しないように単調増加** とする。

---

## 2. 変更ポリシー

### 1 ファイル = 1 変更  
複数の ALTER をまとめない。

### ALTER の前に必ずコメントを書く  
変更理由・背景・影響範囲を明確にする。

---

# 変更履歴

| No  | ファイル名 | 日付 | 内容 |
|-----|------------|------|------|
| 001 | 001_create_tables.sql | 初回 | テーブル定義 |
| 002 | 002_alter_tables_20251106_add_last_update.sql | 2025-11-06 | program_cobol に last_update を追加 |

---

# 実行方法

```

powershell .\execute\RunSql.ps1 -ConfigPath .\execute\Config.json

```

---

# 注意事項

- 本 DB は開発サポート目的のため、本番反映は必ず別途レビューを行う。
- 外部キーを追加する際は既存データ整合性に注意する。
- カラム削除は要バックアップ。

---

以上。
