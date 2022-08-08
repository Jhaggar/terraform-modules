#! /bin/bash

sleep 180
yum update -y
yum install -y mysql git jq

yum install -y gcc-c++ make ruby
curl -sL https://rpm.nodesource.com/setup_14.x | sudo -E bash -
yum install -y nodejs

#Install code deploy agent
curl -O https://aws-codedeploy-us-east-1.s3.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
