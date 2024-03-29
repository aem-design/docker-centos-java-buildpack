FROM    aemdesign/oracle-jdk:jdk8

LABEL   os="centos" \
        container.description="centos with java build pack" \
        version="1.0.0" \
        imagename="centos-java-buildpack" \
        maintainer="devops@aem.design" \
        test.command="source ~/.nvm/nvm.sh; node --version" \
        test.command.verify="v12.19.0"

#https://chromedriver.storage.googleapis.com/
ARG CHROME_DRIVER_VERSION="88.0.4324.96"
ARG CHROME_DRIVER_FILE="chromedriver_linux64.zip"
ARG CHROME_DRIVER_URL="https://chromedriver.storage.googleapis.com/${CHROME_DRIVER_VERSION}/${CHROME_DRIVER_FILE}"
ARG CHROME_FILE="google-chrome-stable_current_x86_64.rpm"
ARG CHROME_URL="https://dl.google.com/linux/direct/${CHROME_FILE}"
ARG NODE_VERSION="12.19.0"
ARG NVM_URL="https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh"
ARG MAVEN_VERSION="3.6.3"
ARG MAVEN_FILE="apache-maven-${MAVEN_VERSION}-bin.zip"
ARG MAVEN_URL="http://mirrors.sonic.net/apache/maven/maven-3/${MAVEN_VERSION}/binaries/${MAVEN_FILE}"
ARG RVM_VERSION=stable
ARG RVM_USER=rvm
ARG GROOVY_VERSION="3.0.7"

ENV RVM_USER=${RVM_USER}
ENV RVM_VERSION=${RVM_VERSION}
ENV HOME="/build"

RUN mkdir -p $HOME

WORKDIR $HOME

ENV REQUIRED_PACKAGES \
    curl \
    tar \
    zip \
    unzip \
    ruby \
    apache-ivy \
    junit \
    rsync \
    python3-devel \
    python3-setuptools \
    python3-pip \
    autoconf \
    gcc-c++ \
    make \
    gcc \
    openssl-devel \
    openssh-server \
    vim \
    git \
    git-lfs \
    wget \
    bzip2 \
    ca-certificates \
    chrpath \
    fontconfig \
    freetype \
    libfreetype.so.6 \
    libfontconfig.so.1 \
    libstdc++.so.6 \
    ImageMagick \
    ImageMagick-devel \
    libcurl-devel \
    libffi \
    libffi-devel \
    libtool-ltdl \
    libtool-ltdl-devel \
    libpng-devel \
    pngquant \
    sudo \
    gnupg2 \
    libwebp \
    yarn \
    ansible

RUN \
    echo "==> Make dirs..." && \
    mkdir -p /apps/

RUN \
    echo "==> Setup packages..." && \
    dnf update -y && \
    dnf repolist && \
    dnf --enablerepo=extras install -y epel-release dnf-plugins-core && \
    dnf config-manager --set-enabled powertools && \
    dnf repolist && \
    dnf groupinfo "Development Tools" && \
    curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo

RUN dnf check-update -y || { rc=$?; [ "$rc" -eq 100 ] && exit 0; exit "$rc"; }

RUN \
    echo "==> Add Docker Client" && \
    dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo && \
    dnf install -y docker-ce-cli && \
    pip3 install --upgrade pip && \
    pip install docker-compose

RUN \
    echo "==> Enable Java packages & tools..." && \
    dnf module enable -y javapackages-tools

RUN \
    echo "==> Install packages..." && \
    dnf install -y epel-release && \
    dnf group install -y "Development Tools" && \
    dnf --enablerepo=powertools install -y ${REQUIRED_PACKAGES}

RUN \
    echo "==> Install SDKMAN..." && \
    export SDKMAN_DIR=$HOME

RUN curl -s https://get.sdkman.io | bash

RUN \
    source "$HOME/.sdkman/bin/sdkman-init.sh" && \
    sdk version && \
    sdk install groovy $GROOVY_VERSION

RUN \
    echo "==> Install nvm..." && \
    export NVM_DIR="/build/.nvm" && \
    mkdir -p ${NVM_DIR} && touch .bashrc && \
    curl -o- ${NVM_URL} | bash && source $HOME/.bashrc && \
    nvm install $NODE_VERSION && nvm use --delete-prefix ${NODE_VERSION} && \
    echo "==> Install npm packages..." && \
    npm install -g npm

RUN \
    echo "==> Install chrome..." && \
    wget ${CHROME_DRIVER_URL} && unzip ${CHROME_DRIVER_FILE} && mv chromedriver /usr/bin && rm -f ${CHROME_DRIVER_FILE} && \
    wget ${CHROME_URL} && yum install -y Xvfb ${CHROME_FILE} && rm -f ${CHROME_FILE}

RUN \
    echo "==> Install maven..." && \
    wget ${MAVEN_URL} && unzip ${MAVEN_FILE} && mv apache-maven-${MAVEN_VERSION} /apps/maven && rm -f ${MAVEN_FILE} && \
    echo "export PATH=/apps/maven/bin:${PATH}">/etc/profile.d/maven.sh && \
    echo "export PATH=/apps/maven/bin:${PATH}">>$HOME/.bashrc && \
    echo "export PATH=/apps/maven/bin:${PATH}">>/etc/profile.d/sh.local && \
    ln -s /apps/maven/bin/mvn /usr/bin/mvn

RUN \
    echo "==> Disable requiretty..." && \
    sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/'  /etc/sudoers && \
    echo "ALL  ALL=(ALL) NOPASSWD: ALL">>/etc/sudoers

RUN \
    echo "==> Set Oracle JDK as Alternative..." && \
    rm -rf /var/lib/alternatives/java && \
    rm -rf /var/lib/alternatives/jar && \
    rm -rf /var/lib/alternatives/javac && \
    alternatives --install "/usr/bin/java" "java" "/usr/java/default/bin/java" 2 && \
    alternatives --install "/usr/bin/jar" "jar" "/usr/java/default/bin/jar" 2 && \
    alternatives --install "/usr/bin/javac" "javac" "/usr/java/default/bin/javac" 2 && \
    alternatives --set java "/usr/java/default/bin/java" && \
    alternatives --set jar "/usr/java/default/bin/jar" && \
    alternatives --set javac "/usr/java/default/bin/javac"

RUN \
    echo "==> Install RVM..." && \
    curl -sSL https://rvm.io/mpapis.asc | gpg2 --import - && \
    curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import - && \
    curl -L get.rvm.io | bash -s $RVM_VERSION && \
    echo "==> Source RVM..." && \
    echo "export PATH=\$PATH:/usr/local/rvm/bin">>/build/.bashrc && \
    export PATH=$PATH:/usr/local/rvm/bin && \
    source /usr/local/rvm/scripts/rvm && \
    echo "==> Reload RVM..." && \
    touch /etc/rvmrc && \
    echo "rvm_silence_path_mismatch_check_flag=1" >> /etc/rvmrc && \
    touch /usr/local/rvm/gemsets/global.gems && \
    echo "bundler" >> /usr/local/rvm/gemsets/global.gems && \
    rvm reload && \
    rvm requirements run && \
    rvm install 2.6

RUN \
    echo "==> Update scripts" && \
    touch $HOME/.bash_profile && echo "if [ -f ~/.bashrc ]; then . ~/.bashrc; fi" >> $HOME/.bash_profile

RUN useradd -m --no-log-init -r -g rvm ${RVM_USER}
