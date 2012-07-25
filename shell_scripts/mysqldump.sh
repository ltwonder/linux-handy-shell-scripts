#!/bin/sh

cd /home/webmaster/sql

rm -f *.sql
rm -f *.gz

mysqldump -u USERNAME -pPASSWORD eccube > $(date '+%Y%m%d')FILENAME.sql
tar cvzf $(date '+%Y%m%d')FILENAME.tar.gz *.sql

rm -f *.sql
