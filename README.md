# README #

# Active Perl (x86)
# Модули в "perl modules.txt"
# Для виндовой консоли кодировка chcp 65001


# wget http://downloads.activestate.com/ActivePerl/releases/5.24.1.2402/ActivePerl-5.24.1.2402-x86_64-linux-glibc-2.15-401614.tar.gz
# tar zxf ActivePerl-5.24.1.2402-x86_64-linux-glibc-2.15-401614.tar.gz
# cd ActivePerl-5.24.1.2402-x86_64-linux-glibc-2.15-401614
# ./install.sh
# ln -s /opt/ActivePerl-5.24/bin/perl /usr/bin/aperl
# aperl -version

====

# cron: 
# crontab -e
# */1 * * * * aperl /root/integration/servicenow_integration/integrate.pl
# service cron start