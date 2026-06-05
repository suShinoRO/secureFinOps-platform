FROM jenkins/jenkins:lts-jdk21
USER root
RUN apt-get update && \
    apt-get install -y docker.io && \
    usermod -aG docker jenkins && \
    rm -rf /var/lib/apt/lists/*
RUN groupmod -g 999 docker && \
    usermod -aG docker jenkins
USER jenkins