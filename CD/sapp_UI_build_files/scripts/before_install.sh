#!/bin/bash

# navigate to sapp folder
cd /home/ec2-user/sapp-ui

# install node and npm
curl -sL https://rpm.nodesource.com/setup_16.x | sudo -E bash -
yum -y install nodejs npm
