-- 1 up

CREATE TABLE IF NOT EXISTS metrics (
    metric_id   INT AUTO_INCREMENT PRIMARY KEY,
    year        INT,
    month       INT,
    day         INT,
    hour        INT,
    metric      TINYTEXT NOT NULL,
    value       DOUBLE (12,2)
);

--
-- regex stores the regular expresion used by flair engine
--

CREATE TABLE IF NOT EXISTS regex (
    regex_id    INT AUTO_INCREMENT PRIMARY KEY,
    created     TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    updated     TIMESTAMP  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    active      BOOLEAN default true,
    name        TEXT NOT NULL,
    description TEXT NOT NULL,
    `match`     TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    regex_type  TEXT CHECK(regex_type in ('core', 'udef')) NOT NULL,
    re_order    INT,
    multiword   BOOLEAN
);

--
-- The Files table keeps track of the files created by imgmunger
--

CREATE TABLE IF NOT EXISTS files (
    file_id     INT AUTO_INCREMENT PRIMARY KEY,
    updated     TIMESTAMP  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    filename    TEXT NOT NULL,
    dir         TEXT NOT NULL
);

--
-- keep track of apikeys, how to access the api
--
CREATE TABLE IF NOT EXISTS apikeys (
    apikey_id   INT AUTO_INCREMENT PRIMARY KEY, 
    updated     TIMESTAMP  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    username    TEXT NOT NULL,
    apikey      TEXT NOT NULL,
    lastaccess  TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    flairjob    BOOLEAN,        -- create a flair job and query and read results
    regex_ro    BOOLEAN,        -- read only regexes
    regex_crud  BOOLEAN,        -- full control regexes
    metrics     BOOLEAN         -- read metrics
);

--
-- admins can access the web interface and api
-- 
CREATE TABLE IF NOT EXISTS admins (
    admin_id    INT AUTO_INCREMENT PRIMARY KEY,
    updated     TIMESTAMP  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    username    TEXT NOT NULL,
    who         TEXT NOT NULL,
    lastlogin   TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    lastaccess  TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    pwhash      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS jobs (
    job_id      INT AUTO_INCREMENT PRIMARY KEY,
    updated     TIMESTAMP  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    duration    DECIMAL(16,4) DEFAULT 0,
    imgduration DECIMAL(16,4) DEFAULT 0,
    sourcelen   INT DEFAULT 0,
    images      INT DEFAULT 0,
    entities    INT DEFAULT 0
);

-- 1 down

DROP TABLE IF EXISTS regex;
DROP TABLE IF EXISTS status;
DROP TABLE IF EXISTS metrics;
DROP TABLE IF EXISTS files;
DROP TABLE IF EXISTS apikeys;
DROP TABLE IF EXISTS admins;
DROP TABLE IF EXISTS jobs;

-- 2 up

DROP TABLE IF EXISTS regex_v1;
RENAME TABLE regex TO regex_v1;
CREATE TABLE IF NOT EXISTS regex (
    regex_id    INT AUTO_INCREMENT PRIMARY KEY,
    created     TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    updated     TIMESTAMP  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    active      BOOLEAN default true,
    name        TEXT NOT NULL,
    description TEXT NOT NULL,
    `match`     TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    re_type     TEXT NOT NULL,
    re_group    TEXT NOT NULL,
    re_order    INT,
    multiword   BOOLEAN
) AUTO_INCREMENT = 1000;


-- 2 down

DROP TABLE IF EXISTS regex;
RENAME TABLE regex_v1 TO regex;

