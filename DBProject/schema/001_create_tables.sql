-- =========================================================
-- 001_create_tables.sql
-- 初期テーブル作成（MySQL 5.7 対応）
-- =========================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- =========================================================
-- cutoff（断面管理）
-- =========================================================
DROP TABLE IF EXISTS cutoff;
CREATE TABLE cutoff (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    cutoff_date   DATE NOT NULL,     -- 受領日
    description   VARCHAR(255) NULL, -- 任意の説明（例：2025/11断面など）
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =========================================================
-- program_cobol（処理部 COBOL）
-- =========================================================
DROP TABLE IF EXISTS program_cobol;
CREATE TABLE program_cobol (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    cutoff_id     INT NOT NULL,
    file_path     VARCHAR(512) NOT NULL,
    hash          CHAR(64) NOT NULL,
    program_name  VARCHAR(255) NOT NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_program_cobol_cutoff (cutoff_id),
    CONSTRAINT fk_program_cobol_cutoff
        FOREIGN KEY (cutoff_id) REFERENCES cutoff(id)
) ENGINE=InnoDB;

-- =========================================================
-- program_java（処理部 Java）
-- =========================================================
DROP TABLE IF EXISTS program_java;
CREATE TABLE program_java (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    program_id    INT NOT NULL,        -- program_cobol.id
    cutoff_id     INT NOT NULL,
    file_path     VARCHAR(512) NOT NULL,
    hash          CHAR(64) NOT NULL,
    java_name     VARCHAR(255) NOT NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_program_java_program (program_id),
    INDEX idx_program_java_cutoff (cutoff_id),
    CONSTRAINT fk_program_java_program
        FOREIGN KEY (program_id) REFERENCES program_cobol(id),
    CONSTRAINT fk_program_java_cutoff
        FOREIGN KEY (cutoff_id) REFERENCES cutoff(id)
) ENGINE=InnoDB;

-- =========================================================
-- copy_cobol（コピー句 COBOL）
-- =========================================================
DROP TABLE IF EXISTS copy_cobol;
CREATE TABLE copy_cobol (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    cutoff_id     INT NOT NULL,
    file_path     VARCHAR(512) NOT NULL,
    hash          CHAR(64) NOT NULL,
    copy_name     VARCHAR(255) NOT NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_copy_cobol_cutoff (cutoff_id),
    CONSTRAINT fk_copy_cobol_cutoff
        FOREIGN KEY (cutoff_id) REFERENCES cutoff(id)
) ENGINE=InnoDB;

-- =========================================================
-- copy_java（コピー句 Java）
-- =========================================================
DROP TABLE IF EXISTS copy_java;
CREATE TABLE copy_java (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    copy_id       INT NOT NULL,      -- copy_cobol.id
    cutoff_id     INT NOT NULL,
    file_path     VARCHAR(512) NOT NULL,
    hash          CHAR(64) NOT NULL,
    java_name     VARCHAR(255) NOT NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_copy_java_copy (copy_id),
    INDEX idx_copy_java_cutoff (cutoff_id),
    CONSTRAINT fk_copy_java_copy
        FOREIGN KEY (copy_id) REFERENCES copy_cobol(id),
    CONSTRAINT fk_copy_java_cutoff
        FOREIGN KEY (cutoff_id) REFERENCES cutoff(id)
) ENGINE=InnoDB;

-- =========================================================
-- program_copy（処理部 ⇔ コピー句の N:N ）
-- =========================================================
DROP TABLE IF EXISTS program_copy;
CREATE TABLE program_copy (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    program_id    INT NOT NULL,    -- program_cobol.id
    copy_id       INT NOT NULL,    -- copy_cobol.id
    cutoff_id     INT NOT NULL,    -- 断面ごとに関係が変わる

    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_program_copy_program (program_id),
    INDEX idx_program_copy_copy (copy_id),
    INDEX idx_program_copy_cutoff (cutoff_id),

    CONSTRAINT fk_program_copy_program
        FOREIGN KEY (program_id) REFERENCES program_cobol(id),
    CONSTRAINT fk_program_copy_copy
        FOREIGN KEY (copy_id) REFERENCES copy_cobol(id),
    CONSTRAINT fk_program_copy_cutoff
        FOREIGN KEY (cutoff_id) REFERENCES cutoff(id)
) ENGINE=InnoDB;

-- =========================================================
-- program_resource（移行資源: 処理部用）
-- =========================================================
DROP TABLE IF EXISTS program_resource;
CREATE TABLE program_resource (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    program_id    INT NOT NULL,
    server_type   VARCHAR(8) NULL,  -- OPEN / HOST / OPENHOST / UNUSED / その他自由入力
    logical_name  VARCHAR(255) NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_program_resource_program (program_id),
    CONSTRAINT fk_program_resource_program
        FOREIGN KEY (program_id) REFERENCES program_cobol(id)
) ENGINE=InnoDB;

-- =========================================================
-- copy_resource（移行資源: コピー句用）
-- =========================================================
DROP TABLE IF EXISTS copy_resource;
CREATE TABLE copy_resource (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    copy_id       INT NOT NULL,
    server_type   VARCHAR(8) NULL,
    logical_name  VARCHAR(255) NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_copy_resource_copy (copy_id),
    CONSTRAINT fk_copy_resource_copy
        FOREIGN KEY (copy_id) REFERENCES copy_cobol(id)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- =========================================================
-- END OF FILE
-- =========================================================
