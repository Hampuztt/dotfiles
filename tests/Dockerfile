# A "fresh machine" for testing install.sh: just a user with sudo, nothing else installed.
# Built by tests/run.sh with BASE=ubuntu:24.04 or BASE=fedora:latest.
ARG BASE=ubuntu:24.04
FROM ${BASE}

RUN if command -v apt-get >/dev/null; then \
      apt-get update && apt-get install -y sudo && rm -rf /var/lib/apt/lists/* && \
      (userdel -r ubuntu 2>/dev/null || true); \
    else \
      dnf install -y sudo shadow-utils && dnf clean all; \
    fi \
 && useradd -m -u 1000 -s /bin/bash tester \
 && echo "tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester

USER tester
WORKDIR /home/tester
