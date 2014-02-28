#!/bin/bash
#base mysql's parameter
MysqlVersion="Percona-Server-5.6.15-rel63.0"
MysqlLine="http://www.percona.com/downloads/Percona-Server-5.6/LATEST/source"
MysqlPath="/usr/local/mysql"
MysqlDataPath="$MysqlPath/data"
MysqlLogPath="/var/log/mysql"
MysqlConfigPath="$MysqlPath"
MysqlPass=""
MYSQL_BASE_PACKAGES_INSTALL(){
	[[ "$MysqlPass" == '' ]] && echo "Please input MYSQL's password:";read MysqlPass
	if [ "$SysName" == 'centos' ] ;then
		yum -y remove mysql-server mysql;
		BasePackages="gcc gcc-c++ openssl-devel ncurses-devel bison cmake make";
	else
		apt-get -y remove mysql-client mysql-server mysql-common;
		BasePackages="gcc g++ cmake make bison libncurses5-dev libncurses5 libssl-dev";
	INSTALL_BASE_PACKAGES $BasePackages
}
#install mysql
INSTALL_MYSQL(){
	cd /tmp/
	echo "[${MysqlVersion} Installing] ************************************************** >>";
	[ ! -f ${MysqlVersion}.tar.gz ] && wget -c ${MysqlLine}/${MysqlVersion}.tar.gz
	tar -zxf /tmp/$MysqlVersion.tar.gz;
	cd /tmp/$MysqlVersion;
	groupadd mysql;
	useradd -s /sbin/nologin -g mysql mysql;
	cmake -DCMAKE_INSTALL_PREFIX=$MysqlPath  -DDEFAULT_CHARSET=utf8 -DDEFAULT_COLLATION=utf8_general_ci -DWITH_EXTRA_CHARSETS=complex -DWITH_READLINE=ON -DENABLED_LOCAL_INFILE=ON -DWITH_INNODB_MEMCACHED=ON -DWITH_UNIT_TESTS=OFF;
	make &&	make install;
	for path in $MysqlLogPath $MysqlPath $MysqlConfigPath/conf.d $MysqlDataPath;do
		[ ! -d $path ] && mkdir -p $path
		chmod 775 $path;
		chown -R mysql:mysql $path;
	done
# EOF **********************************
cat > $MysqlConfigPath/my.cnf<<EOF;
[mysqld]
user		= mysql
server-id	= 1
pid-file	= /tmp/mysqld.pid
socket		= /tmp/mysqld.sock
port		= 3306
basedir		= $MysqlPath
datadir		= $MysqlDataPath
bind-address	= 0.0.0.0
skip-name-resolve
skip-external-locking
thread_concurrency	= `expr $CpuNum \* 2`
max_connections	= `expr $FileMax \* $CpuNum \* 2 / $RamTotal`
max_connect_errors	= 30
table_open_cache	= `expr $RamTotal + $RamSwap`
max_allowed_packet	= `expr $RamTotal \* 2 / 1000`M
binlog_cache_size	= 4M
max_heap_table_size	= `expr $RamTotal / 100`M
sort_buffer_size	= `expr $RamTotal \* 2 / 1000`M
join_buffer_size	= `expr $RamTotal \* 2 / 1000`M
query_cache_size	= `expr $RamTotal / 100`M
thread_cache_size	= 30
thread_concurrency	= `expr $CpuNum \* 4`
connect_timeout		= 1200
wait_timeout		= 1200
general_log	= 1
general_log_file	= $MysqlLogPath/mysql.log
log_error	= $MysqlLogPath/mysql-err.log
slow_query_log	= 1
slow_query_log_file	= $MysqlLogPath/mysql-slow.log
long_query_time	= 3
log_bin	= $MysqlLogPath/mysql-bin
log_bin_index	= $MysqlLogPath/mysql-bin.index
expire_logs_days	= 7
max_binlog_size	= `expr $(df -m $MysqlLogPath |awk 'NR==2{printf "%s\n",$4}') / 10000`M
default_storage_engine	= InnoDB
innodb_buffer_pool_size	= `expr $RamTotal / 100`M
innodb_log_buffer_size	= 8M
innodb_file_per_table	= 1
innodb_open_files	= `expr $FileMax \* $CpuNum / $RamTotal`
innodb_io_capacity	= `expr $FileMax \* $CpuNum / $RamTotal`
innodb_flush_method	= O_DIRECT

!includedir $MysqlConfigPath/conf.d
[mysqld_safe]
open_files_limit	= `expr $FileMax / $CpuNum / 100`
[isamchk]
key_buffer		= 16M
[mysqldump]
quick
quote-names
max_allowed_packet	= 16M
EOF
# **************************************
	$MysqlPath/scripts/mysql_install_db --user=mysql --defaults-file=$MysqlConfigPath/my.cnf --basedir=$MysqlPath --datadir=$MysqlDataPath;
# EOF **********************************
cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib/mysql
/usr/local/lib
EOF
# **************************************
	ldconfig;
	if [ "$SysBit" == '64' ] ; then
		ln -s $MysqlPath/lib/mysql /usr/lib64/mysql;
	else
		ln -s $MysqlPath/lib/mysql /usr/lib/mysql;
	fi;
	cp $MysqlPath/support-files/mysql.server /etc/init.d/mysqld;
	chmod 775 /etc/init.d/mysqld;
	/etc/init.d/mysqld start;
	ln -s $MysqlPath/bin/mysql /usr/bin/mysql;
	ln -s $MysqlPath/bin/mysqladmin /usr/bin/mysqladmin;
	$MysqlPath/bin/mysqladmin password $MysqlPass;
	rm -rf $MysqlDataPath/test;
# EOF **********************************
mysql -hlocalhost -uroot -p$MysqlPass <<EOF
USE mysql;
DELETE FROM user WHERE user='';
UPDATE user set password=password('$MysqlPass') WHERE user='root';
DELETE FROM user WHERE not (user='root');
DROP USER ''@'%';
FLUSH PRIVILEGES;
EOF
# **************************************
	echo "[OK] ${MysqlVersion} install completed.";
}
MYSQL_BASE_PACKAGES_INSTALL && INSTALL_MYSQL