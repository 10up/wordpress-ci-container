FROM php:7-buster

RUN apt-get update && apt-get install -y curl git subversion openssh-client openssl zlib1g-dev mysql-client rsync build-essential gnupg2 shellcheck vim sshpass libsass-dev python3-pip libpng-dev ruby ruby-dev clamav clamav-freshclam apt-transport-https ca-certificates software-properties-common zlib1g-dev libicu-dev g++

RUN echo "memory_limit=-1" > "$PHP_INI_DIR/conf.d/memory-limit.ini" \
 && echo "date.timezone=${PHP_TIMEZONE:-UTC}" > "$PHP_INI_DIR/conf.d/date_timezone.ini"

RUN docker-php-ext-install zip pdo pdo_mysql gd bcmath intl

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_HOME /tmp
ENV COMPOSER_VERSION 1.5.2

RUN curl -s -f -L -o /tmp/installer.php https://raw.githubusercontent.com/composer/getcomposer.org/da290238de6d63faace0343efbdd5aa9354332c5/web/installer \
 && php -r " \
    \$signature = '669656bab3166a7aff8a7506b8cb2d1c292f042046c5a994c43155c0be6190fa0355160742ab2e1c88d40d5be660b410'; \
    \$hash = hash('SHA384', file_get_contents('/tmp/installer.php')); \
    if (!hash_equals(\$signature, \$hash)) { \
        unlink('/tmp/installer.php'); \
        echo 'Integrity check failed, installer is either corrupt or worse.' . PHP_EOL; \
        exit(1); \
    }" \
 && php /tmp/installer.php --no-ansi --install-dir=/usr/bin --filename=composer --version=${COMPOSER_VERSION} \
 && composer --ansi --version --no-interaction \
 && rm -rf /tmp/* /tmp/.htaccess

RUN docker-php-ext-install mysqli

####### install python tools like awscli #########
##### use pip3 to ensure you install into python3
RUN pip3 install awscli ansible

######## Specific to building / deploying

RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - && \
	apt-get -y install nodejs

RUN npm install -g grunt-cli gulp-cli bower yarn lighthouse serverless

######## Compass
RUN gem update --system && \
	gem install compass
######## End Compass

RUN mkdir /root/.ssh && \
    chmod 700 /root/.ssh

####### Update clamav definitions
RUN /usr/bin/freshclam

####### Pantheon

# Install Terminus
RUN mkdir ~/terminus && \
	cd ~/terminus && \
	curl -O https://raw.githubusercontent.com/pantheon-systems/terminus-installer/master/builds/installer.phar && php installer.phar install

####### End Pantheon


# Docker
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - && \
   add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/debian \
       $(lsb_release -cs) \
       stable" && \
   apt-get update && \
   apt-get install -y docker-ce && \
   apt-get autoremove -y && \
   apt-get clean

# Cleanup
RUN apt-get autoremove -y && apt-get clean

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

