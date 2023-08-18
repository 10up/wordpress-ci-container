# base image should be a PHP Debian container, such as php:7.4-buster
ARG PHP_IMG
FROM $PHP_IMG

RUN apt-get update && \
    apt-get install -y \
      apt-transport-https \
      build-essential \
      ca-certificates \
      clamav \
      clamav-freshclam \
      curl \
      fonts-liberation \
      g++ \
      gconf-service \
      gettext \
      git \
      gnupg2 \
      jq \
      lftp \
      libappindicator1 \
      libasound2 \
      libatk1.0-0 \
      libc6 \
      libcairo2 \
      libcups2 \
      libdbus-1-3 \
      libexpat1 \
      libffi-dev \
      libfontconfig1 \
      libgcc1 \
      libgconf-2-4 \
      libgdk-pixbuf2.0-0 \
      libglib2.0-0 \
      libgtk-3-0 \
      libicu-dev \
      libnspr4 \
      libnss3 \
      libpango-1.0-0 \
      libpangocairo-1.0-0 \
      libpng-dev \
      libsass-dev \
      libstdc++6 \
      libx11-6 \
      libx11-xcb1 \
      libxcb1 \
      libxcomposite1 \
      libxcursor1 \
      libxdamage1 \
      libxext6 \
      libxfixes3 \
      libxi6 \
      libxml2-dev \
      libxrandr2 \
      libxrender1 \
      libxss1 \
      libxtst6 \
      libzip-dev \
      lsb-release \
      mercurial \
      default-mysql-client \
      openssh-client \
      openssl \
      python3-pip \
      rsync \
      ruby \
      ruby-dev \
      shellcheck \
      software-properties-common \
      sshpass \
      subversion \
      vim \
      wget \
      xdg-utils \
      yamllint \
      zlib1g-dev && \
    apt-get autoremove -y && \
    apt-get clean

## Update clamav definitions ##
# Run here to avoid bugs when run lower in the Dockerfile

RUN /usr/bin/freshclam

## set locale properly to en_US.UTF-8
RUN apt-get update && \
    apt-get install -y locales && \
    rm -rf /var/lib/apt/lists/* && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG en_US.utf8

RUN echo "memory_limit=-1" > "$PHP_INI_DIR/conf.d/memory-limit.ini" && \
    echo "date.timezone=${PHP_TIMEZONE:-UTC}" > "$PHP_INI_DIR/conf.d/date_timezone.ini"

## PHP extensions ##
RUN docker-php-ext-install zip pdo pdo_mysql gd bcmath intl sockets mysqli exif soap

#### Specific to building / deploying ####

## set up NVM and install node ##

ENV NVM_DIR /tmp/.nvm
RUN mkdir ${NVM_DIR}
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash

COPY build/install-node.sh /tmp/install-node.sh
RUN chmod +x /tmp/install-node.sh && /tmp/install-node.sh
COPY .bowerrc /root/.bowerrc

## Compass ##

RUN gem install compass

## Ansible, awscli, other Python tools ##

COPY requirements.txt /tmp/requirements.txt 
RUN python3 -m pip -V && \
    python3 -m pip install -r /tmp/requirements.txt
#RUN pip3 install --upgrade pip && pip3 --no-cache-dir install -r /tmp/requirements.txt

## Composer ##
ARG COMPOSER_VERSION 1

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_HOME /tmp

COPY build/install-composer.sh /tmp/install-composer.sh
RUN /tmp/install-composer.sh && \
    composer --ansi --version --no-interaction

## Docker ##

RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    apt-get autoremove -y && \
    apt-get clean

## Kubectl ##

# Install latest version for Kubernetes management
# this could also be a specific version
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

## Terminus CLI for Pantheon managed hosting ##

# Install Terminus (note - standalone PHAR method works and Terminus Installer PHAR does not)
RUN mkdir ~/terminus && \
    cd ~/terminus && \
    curl -L https://github.com/pantheon-systems/terminus/releases/download/`curl --silent "https://api.github.com/repos/pantheon-systems/terminus/releases/latest" | perl -nle'print $& while m#"tag_name": "\K[^"]*#g'`/terminus.phar --output terminus && chmod +x terminus && \
    ln -s ~/terminus/terminus /usr/local/bin/terminus

#### end of tool installation ####

## CI pipeline scripts and auth ##

COPY scripts/* /custom-scripts/
RUN chmod +x /custom-scripts/*
ENV PATH="/custom-scripts:${PATH}"

# Create SSH directory
# SSH keys for deploys or auth are set in entrypoint.sh

RUN mkdir /root/.ssh && \
    chmod 700 /root/.ssh

# force CI jobs to source root's .bashrc, which will enable NVM
ENV BASH_ENV "/root/.bashrc"

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
