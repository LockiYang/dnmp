#!/bin/sh

backup_dir=./
log_file=$backup_dir/db.log

echo "---------------------------------------------------" >> $log_file
echo $(date +"%Y-%m-%d %H:%M:%S") "Database backup start"  >> $log_file

#mysqldump -uroot -ppwd test >> $backup_dir/db_$(date +"%Y-%m-%d").sql

ls

if [ 0 -eq $? ];then
    if [ -f "$backup_dir/db_$(date +"%Y-%m-%d").sql" ];then
        echo $(date +"%Y-%m-%d %H:%M:%S") "Database backup success" >> $log_file
    else
        echo $(date +"%Y-%m-%d %H:%M:%S") "Database backup failed" >> $log_file
    fi
else
    echo $(date +"%Y-%m-%d %H:%M:%S") "Database backup error" >> $log_file
fi

echo "---------------------------------------------------" >> $log_file
find $backup_dir -mtime +7 -name "db_*.sql" -exec rm -rf {} \;
