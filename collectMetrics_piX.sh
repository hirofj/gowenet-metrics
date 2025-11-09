#!/bin/bash

echo "gowenet_resources_mqtt.sh 10 3600"
nohup ./scripts/gowenet_resources_mqtt.sh 10 3600 > /dev/null 2>&1 &
