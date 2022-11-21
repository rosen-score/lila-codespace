FROM ubuntu:focal-20220415

SHELL ["/bin/bash", "-c"]

RUN apt-get update \
    && apt update \
    && apt-get install -y build-essential ca-certificates curl gnupg locales sudo wget

ENV TZ=Etc/GMT
RUN sudo ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && sudo echo $TZ > /etc/timezone
RUN locale-gen "en_US.UTF-8"

# Install coursier (dependency of bloop)
RUN curl -fL https://github.com/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz | gzip -d > cs \
    && chmod +x cs \
    && sudo mv cs /usr/local/bin/cs \
    && cs setup --yes

# Add mongodb apt source
RUN wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
RUN echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list

RUN sudo apt-get update && sudo apt update \
  && sudo apt-get install -y git-all golang-go mongodb-org nginx parallel psmisc python3.9 python3-pip redis-server unzip vim zip

# Cleanup
RUN sudo apt-get autoremove -y \
  && sudo apt-get clean

# Add nginx site config
COPY nginx/lichess.conf /etc/nginx/sites-enabled/
RUN rm /etc/nginx/sites-enabled/default
COPY nginx/errors /var/www/errors

# Create "lichess" user with sudo access
RUN useradd --create-home --shell /bin/bash --password lichess lichess
RUN echo "lichess ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
USER lichess

# Install pymongo needed for lila-db-seed
RUN python3.9 -m pip install pymongo

# Install nvm, npm, and yarn
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
  && export NVM_DIR="$HOME/.nvm" \
  && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
  && echo ". \"$HOME/.nvm/nvm.sh\"" >> ~/.bashrc \
  && nvm install 16 \
  && npm install -g yarn

# Install Java
RUN curl -s "https://get.sdkman.io" | bash \
  && source "$HOME/.sdkman/bin/sdkman-init.sh" \
  && sdk version \
  && sdk install java 17.0.3-tem \
  && sdk install sbt

# Install Rust and Cargo, needed for fishnet and lila-engine
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Install bloop + scala formatter
RUN cs install bloop --only-prebuilt=true \
  && cs install scalafmt \
  && echo 'export PATH="$PATH:$HOME/.local/share/coursier/bin"' >> ~/.bashrc

# Silence the parallel citation warning
RUN mkdir -p ~/.parallel && touch ~/.parallel/will-cite
