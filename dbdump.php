<?php
$dbHost = 'SERVER HOST';
$dbUser = 'USERNAME';
$dbPass = 'PASSWORD';
$dbName = 'DATABASE NAME';

$fileName = date('ymd').'_'.date('His').'.txt';
$command = "/usr/bin/mysqldump --default-character-set=binary ".$dbName." --host=".$dbHost." --user=".$dbUser." --password=".$dbPass." > ".$fileName;
system($command);
