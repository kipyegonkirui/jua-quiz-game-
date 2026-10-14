#!/bin/bash
# usage: run.sh <supabase_dir> <db> file1 file2 ...
D=$1; DB=$2; shift 2
P="psql -h /opt/pgsock -p 5544 -U postgres"
$P -qc "drop database if exists $DB" postgres 2>/dev/null; $P -qc "create database $DB" postgres
$P -q -d $DB -f ./stub.sql 2>&1 | grep -i error
for f in "$@"; do
  out=$($P -q -d $DB -v ON_ERROR_STOP=0 -f $D/$f 2>&1 | grep -E "ERROR|FATAL" )
  if [ -n "$out" ]; then echo "== $f"; echo "$out" | head -8; else echo "ok $f"; fi
done
