FROM ubuntu:focal-20220415

SHELL ["/bin/bash", "-c"]

RUN useradd -ms /bin/bash lichess \
    && apt-get update \
    && apt update \
    && apt-get install -y sudo gnupg ca-certificates\
    && apt-get install -y build-essential curl wget \
    # Disable sudo login for the new lichess user.
    && echo "lichess ALL = NOPASSWD : ALL" >> /etc/sudoers

ENV TZ=Etc/GMT
RUN sudo ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && sudo echo $TZ > /etc/timezone

# Install coursier (dependency of bloop)
RUN curl -fL https://github.com/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz | gzip -d > cs \
    && chmod +x cs \
    && sudo mv cs /usr/local/bin/cs \
    && cs setup --yes

# Run as a non-privileged user.
USER lichess

# mongodb
RUN wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
RUN echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list

RUN sudo apt-get update && sudo apt update \
  && sudo apt-get install -y \
  git-all \
  mongodb-org \ 
  parallel \ 
  python3.9 \
  redis-server \
  unzip \
  vim \
  zip

## pymongo needed for lila-db-seed
RUN python3.9 -m pip install pymongo

# nvm => node => yarn
RUN wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
    && export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")" \
    && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
    && nvm install 16 \
    && npm install -g yarn

# Java
RUN curl -s "https://get.sdkman.io" | bash \
    && source "$HOME/.sdkman/bin/sdkman-init.sh" \
    && sdk version \
    && sdk install java 17.0.3-tem \
    && sdk install sbt

# Install bloop
RUN cs install bloop --only-prebuilt=true \
    && echo 'export PATH="$PATH:/home/lichess/.local/share/coursier/bin"' >> ~/.bashrc

# Silence the parallel citation warning.
RUN sudo mkdir -p ~/.parallel && sudo touch ~/.parallel/will-cite

# Make directories for mongodb
RUN sudo mkdir -p /data/db && sudo chmod 666 /data/db

# Cleanup
RUN sudo apt-get autoremove -y \
  && sudo apt-get clean

# Use UTF-8 encoding
ENV LANG "en_US.UTF-8"
ENV LC_CTYPE "en_US.UTF-8"
