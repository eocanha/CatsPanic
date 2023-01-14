#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})/..
rm -rf cats-panic-linux-amd64 cats-panic-linux-amd64.tgz
mv linux-amd64 cats-panic-linux-amd64
cp -a pics stages.conf cats-panic-linux-amd64/
tar zcvf cats-panic-linux-amd64.tgz cats-panic-linux-amd64
