#!/bin/bash
sudo chmod go-w filebeat/filebeat.yml && sudo chown root filebeat/filebeat.yml && docker-compose down && docker-compose up --build -d