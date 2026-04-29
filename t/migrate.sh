#!/bin/bash

export S4FLAIR_MYSQLDB_MIGRATION="../etc/flair.mysql.sql"
export S4FLAIR_MYSQL_URI="mysql://flair:flairrox!123@localhost/flair"
export S4FLAIR_DB_FILE="/var/flair/flair.db"
export S4FLAIR_LOG_DIR="."
export S4FLAIR_LOG_FILE="test.log"

../bin/migrate.pl
