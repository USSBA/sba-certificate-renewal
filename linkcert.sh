#!/bin/bash
mkdir -p /etc/letsencrypt/live/$1
if [ -z "$(ls /etc/letsencrypt/live/$1/)" ]; then
  echo "Linking files from /etc/letsencrypt/archive/$1/ to /etc/letsencrypt/live/$1/"
  ln -s /etc/letsencrypt/archive/$1/* /etc/letsencrypt/live/$1/
else
  echo "WARN: Files already exist in /etc/letsencrypt/live/$1; cowardly not linking any files"
fi
