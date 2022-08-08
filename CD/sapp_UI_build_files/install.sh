#!/bin/bash

sudo yum update -y

#Install git
yum install -y git 

#Install jq
yum install -y jq

#Install ruby
sudo yum install -y ruby

#Install wget
sudo yum install -y wget

#Install code deploy agent
wget https://aws-codedeploy-us-east-1.s3.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto