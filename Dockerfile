FROM ubuntu:16.04
MAINTAINER 17kong.dev@geneegroup.com

# Use faster APT mirror
ADD sources.list /etc/apt/sources.list
RUN rm -rf /etc/apt/sources.list.d/*

# Install packages
RUN apt-get update && \
    apt-get -y install software-properties-common && \
    apt-get -y install wget language-pack-en bash-completion supervisor vim tzdata && \
    apt-get -y remove --purge vim-tiny && \
    apt-get -y install php7.0-fpm php7.0-cli php7.0-gd php7.0-mcrypt php7.0-mbstring php7.0-mysql php7.0-sqlite3 php7.0-curl php7.0-ldap php7.0-zip && \
    apt-get -y install build-essential php-pear php-msgpack php-zmq php-redis php7.0-dev && \
    sed -i 's/^listen\s*=.*$/listen = 0.0.0.0:9000/' /etc/php/7.0/fpm/pool.d/www.conf && \
    echo "error_log = /var/log/php7/cgi.log" >> /etc/php/7.0/fpm/php.ini && \
    echo "cgi.fix_pathinfo = 1" >> /etc/php/7.0/fpm/php.ini && \
    echo "post_max_size = 50M" >> /etc/php/7.0/fpm/php.ini && \
    echo "upload_max_filesize = 50M" >> /etc/php/7.0/fpm/php.ini && \
    echo "session.save_handler = redis" >> /etc/php/7.0/fpm/php.ini && \
    echo "session.save_path = \"tcp://172.17.42.1:6379\"" >> /etc/php/7.0/fpm/php.ini && \
    echo "error_log = /var/log/php7/cli.log" >> /etc/php/7.0/cli/php.ini && \
    echo "session.save_handler = redis" >> /etc/php/7.0/cli/php.ini && \
    echo "session.save_path = \"tcp://172.17.42.1:6379\"" >> /etc/php/7.0/cli/php.ini
ADD www.conf /etc/php/7.0/fpm/pool.d/www.conf

# Basc PHP Ext
RUN apt-get -y install libyaml-dev && \
    printf '\n' | pecl install yaml-2.0.0 && \
    echo "extension=yaml.so" > /etc/php/7.0/mods-available/yaml.ini && \
    phpenmod yaml && \
    rm -rf /tmp/yaml-2.0.0.tgz && \
    apt-get -y install liblua5.2-dev && \
    ln -s /usr/include/lua5.2 /usr/include/lua && \
    cp /usr/lib/x86_64-linux-gnu/liblua5.2.a /usr/lib/liblua.a && \
    cp /usr/lib/x86_64-linux-gnu/liblua5.2.so /usr/lib/liblua.so && \
    printf '\n' | pecl install lua && \
    echo "extension=lua.so" > /etc/php/7.0/mods-available/lua.ini && \
    phpenmod lua

# Swoole
RUN pecl install swoole && \
    echo "extension=swoole.so" > /etc/php/7.0/mods-available/swoole.ini && \
    phpenmod swoole

#Composer
ADD composer.phar /tmp/composer.phar
RUN mkdir -p /usr/local/bin && mv /tmp/composer.phar /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer && \
    echo 'export COMPOSER_HOME="/usr/local/share/composer"' > /etc/profile.d/composer.sh && \
    echo 'export PATH="/usr/local/share/composer/vendor/bin:$PATH"' >> /etc/profile.d/composer.sh && \
    apt-get -y install clamav clamav-freshclam && \
    apt-get -y install msmtp-mta mailutils && \
    apt-get -y install expect && \
    rm -rf /var/lib/apt/lists/*

ENV TZ Asia/Shanghai
ENV TERM linux
ENV LANG en_US.utf8

# Install freshclam.conf
ADD freshclam.conf /etc/clamav/freshclam.conf
ADD bytecode.cvd /var/lib/clamav/bytecode.cvd
ADD daily.cvd /var/lib/clamav/daily.cvd
ADD main.cvd /var/lib/clamav/main.cvd
RUN freshclam

# Install Composer
ENV COMPOSER_PROCESS_TIMEOUT 40000
ENV COMPOSER_HOME /usr/local/share/composer
ADD config.json $COMPOSER_HOME/config.json

# Install PHP 7.0
RUN mkdir -p /var/log/php7 && \
    mkdir -p /run/php && \
    touch /var/log/php7/cgi.log && \
    touch /var/log/php7/cli.log && \
    chown -R www-data:www-data /var/log/php7
ADD supervisor.php7-fpm.conf /etc/supervisor/conf.d/php7-fpm.conf

# Something extra
RUN mkdir -p /tmp/lims2 && \
    mkdir -p /home/disk && \
    chown -R www-data:www-data /home/disk && \
    chown -R www-data:www-data /tmp/lims2
VOLUME ["/var/lib/lims2", "/tmp/lims2", "/volumes"]

EXPOSE 80

RUN chown -R www-data:www-data /var/lib/lims2 /tmp/lims2
CMD ["/usr/bin/supervisord", "--nodaemon", "-c", "/etc/supervisor/supervisord.conf"]
