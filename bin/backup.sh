#!/bin/bash

FLAIRPATH=/opt/flair
VARDIR=$FLAIRPATH/var
DBFILE=$VARDIR/flair.db
BACKUPDIR=$VARDIR/backups
DATE=$(date "+%Y%m%d-%H%M")
NAME="flair-$DATE.db"
BACKUP=$BACKUPDIR/$NAME

/usr/bin/sqlite3 $DBFILE ".backup $BACKUP"
