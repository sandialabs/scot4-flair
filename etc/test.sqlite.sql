-- 1 up

CREATE TABLE IF NOT EXISTS metrics (
    metric_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    year        INT,
    month       INT,
    day         INT,
    hour        INT,
    metric      TEXT NOT NULL,
    value       NUMERIC (6,2)
);

--
-- regex stores the regular expresion used by flair engine
--

CREATE TABLE IF NOT EXISTS regex (
    regex_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    updated     TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    name        TEXT NOT NULL,
    description TEXT NOT NULL,
    match       TEXT NOT NULL UNIQUE,
    entity_type TEXT NOT NULL,
    regex_type  TEXT CHECK(regex_type in ('core', 'udef')) NOT NULL,
    re_order    INT,
    multiword   BOOLEAN
);

CREATE TRIGGER [update_regex_updated] 
    AFTER UPDATE ON regex FOR EACH ROW 
    WHEN OLD.updated = NEW.updated OR OLD.updated IS NULL
BEGIN
    UPDATE regex SET updated=CURRENT_TIMESTAMP WHERE regex_id=NEW.regex_id;
END;


--
-- The Files table keeps track of the files created by imgmunger
--

CREATE TABLE IF NOT EXISTS files (
    file_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    updated     TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    filename    TEXT NOT NULL,
    dir         TEXT NOT NULL
);

CREATE TRIGGER [update_files_updated] 
    AFTER UPDATE ON files FOR EACH ROW 
    WHEN OLD.updated = NEW.updated OR OLD.updated IS NULL
BEGIN
    UPDATE files SET updated=CURRENT_TIMESTAMP WHERE file_id=NEW.file_id;
END;


--
-- keep track of apikeys, how to access the api
--
CREATE TABLE IF NOT EXISTS apikeys (
    apikey_id   INTEGER PRIMARY KEY AUTOINCREMENT, 
    updated     TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    username    TEXT NOT NULL,
    key         TEXT NOT NULL,
    lastaccess  TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    flairjob    BOOLEAN,        -- create a flair job and query and read results
    regex_ro    BOOLEAN,        -- read only regexes
    regex_crud  BOOLEAN,        -- full control regexes
    metrics     BOOLEAN         -- read metrics
);

CREATE TRIGGER [update_apikeys_updated] 
    AFTER UPDATE ON apikeys FOR EACH ROW 
    WHEN OLD.updated = NEW.updated OR OLD.updated IS NULL
BEGIN
    UPDATE apikeys SET updated=CURRENT_TIMESTAMP WHERE apikey_id=NEW.apikey_id;
END;

INSERT INTO apikeys VALUES (null, null, 'flairtest','flairtest123', null, true, true, true, true);

--
-- admins can access the web interface and api
-- 
CREATE TABLE IF NOT EXISTS admins (
    admin_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    updated     TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    username    TEXT NOT NULL,
    who         TEXT NOT NULL,
    lastlogin   TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    lastaccess  TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    pwhash      TEXT NOT NULL
);

CREATE TRIGGER [update_admins_updated] 
    AFTER UPDATE ON admins FOR EACH ROW 
    WHEN OLD.updated = NEW.updated OR OLD.updated IS NULL
BEGIN
    UPDATE admins SET updated=CURRENT_TIMESTAMP WHERE admin_id=NEW.admin_id;
END;

-- CREATE TABLE IF NOT EXISTS jobs (
--       job_id      INTEGER PRIMARY KEY AUTOINCREMENT,
--       updated     TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
--       duration    DECIMAL(6,4) DEFAULT 0, imgduration DECIMAL(6,4) DEFAULT 0,
--       sourcelen   INT DEFAULT 0,
--       images      INT DEFAULT 0,
--       entities    INT DEFAULT 0
--   );
-- 
-- CREATE TRIGGER [update_jobs_updated] 
--     AFTER UPDATE ON jobs FOR EACH ROW 
--     WHEN OLD.updated = NEW.updated OR OLD.updated IS NULL
-- BEGIN
--     UPDATE jobs SET updated=CURRENT_TIMESTAMP WHERE job_id=NEW.job_id;
-- END;

--1 down
DROP TABLE    IF EXISTS jobs;
DROP TABLE    IF EXISTS regex;
DROP TABLE    IF EXISTS status;
DROP TABLE    IF EXISTS metrics;
DROP TABLE    IF EXISTS files;
DROP TABLE    IF EXISTS apikeys;
DROP TABLE    IF EXISTS admins;
