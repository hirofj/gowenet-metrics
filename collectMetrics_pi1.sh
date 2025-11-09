#!/bin/bash

echo "gowenet_blockchain.sh 10 3600"
nohup ./scripts/gowenet_blockchain.sh 10 3600 > /dev/null 2>&1 &

echo "gowenet_resources.sh 10 3600"
nohup ./scripts/gowenet_resources.sh 10 3600 > /dev/null 2>&1 &
