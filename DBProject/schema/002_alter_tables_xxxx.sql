-- =========================================================
-- 002_alter_tables_XXXX.sql
-- スキーマ変更管理ファイル（テンプレート）
-- MySQL 5.7 対応
--
-- このファイルは「単一の論理変更」を記録するために作成する。
-- 例:
--   ・新しいカラムの追加
--   ・インデックスの追加
--   ・外部キー制約の追加
--   ・既存カラムの型変更
--   ・不要カラムの削除 など
--
-- 命名規則:
--   002_alter_tables_yyyyMMdd_description.sql
--
-- 実行時は RunSql.ps1 または mysql.exe を想定。
-- =========================================================


-- =========================================================
-- 変更内容の説明
-- =========================================================
-- 【変更日】2025-xx-xx
-- 【担当者】（あなたの名前）
-- 【目的】例）program_cobol に last_update カラムを追加する
-- 【背景】例）外部連携で更新日時が必要となったため
-- 【影響範囲】既存データへの影響なし
-- =========================================================


-- =========================================================
-- 変更SQL（ここに ALTER TABLE を記述）
-- =========================================================

--  例：カラム追加
-- ALTER TABLE program_cobol
--     ADD COLUMN last_update DATETIME AFTER hash;

--  例：インデックス追加
-- ALTER TABLE program_cobol
--     ADD INDEX idx_program_name (program_name);

--  例：外部キー追加（後付け）
-- ALTER TABLE program_java
--     ADD CONSTRAINT fk_program_java_program
--         FOREIGN KEY (program_id) REFERENCES program_cobol(id);

--  例：カラム型変更
-- ALTER TABLE copy_resource
--     MODIFY server_type VARCHAR(16);

--  例：カラム削除（注意！バックアップ必須）
-- ALTER TABLE program_java
--     DROP COLUMN temp_flag;

-- =========================================================
-- END OF FILE
-- =========================================================
