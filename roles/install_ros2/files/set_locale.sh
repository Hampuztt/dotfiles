#!/bin/bash
if ! locale | grep -q "LANG=en_US.UTF-8"; then
  sudo locale-gen en_US en_US.UTF-8
  sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
  export LANG=en_US.UTF-8
fi
