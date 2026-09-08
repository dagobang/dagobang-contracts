#!/bin/bash
export PATH=/home/catgroup/.nvm/versions/node/v22.16.0/bin:/usr/bin:/bin
export HTTPS_PROXY=http://192.168.2.119:7890
export HTTP_PROXY=http://192.168.2.119:7890
export GLOBAL_AGENT_HTTPS_PROXY=http://192.168.2.119:7890
export NODE_OPTIONS="-r global-agent/bootstrap"
cd /home/catgroup/projects/remote/meme/dagobang/dagobang-contracts
npx hardhat ignition track-tx 0xefb800695b7d7015e070d9df2f8375640b64dbd5f3a1704a8079a19850c3a3a4 chain-56 --network bsc
echo "EXIT:$?"
