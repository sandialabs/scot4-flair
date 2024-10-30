#!/bin/bash

FLAIRPATH=/opt/flair
SCRIPT=$FLAIRPATH/script/Flair

# process 10 minion tasks in parallel
$SCRIPT minion worker -j 10
