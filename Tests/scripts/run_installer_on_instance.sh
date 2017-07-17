#!/usr/bin/env bash
set -e

INSTANCE_ID=$(cat instance_ids)

echo "Making sure instance started"
aws ec2 wait instance-exists --instance-ids ${INSTANCE_ID}
aws ec2 wait instance-running --instance-ids ${INSTANCE_ID}
echo "Instance started. fetching IP"

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} \
    --query 'Reservations[0].Instances[0].PublicIpAddress' | tr -d '"')
echo "Instance public IP is: $PUBLIC_IP"

echo ${PUBLIC_IP} > public_ip

#copy installer files to instance
INSTALLER=$(ls demistoserver*.sh)

USER="centos"

echo "wait 1 minute to ensure server is ready for ssh"
sleep 1m

echo "create installer files folder"
ssh ${USER}@${PUBLIC_IP} 'mkdir -p ~/installer_files'

scp ${INSTALLER} ${USER}@${PUBLIC_IP}:~/installer_files/installer.sh

echo "get installer and run installation script"
INSTALL_COMMAND_Y="cd ~/installer_files \
    && chmod +x installer.sh \
    && sudo ./installer.sh -- -y -do-not-start-server"

ssh -t ${USER}@${PUBLIC_IP} ${INSTALL_COMMAND_Y}

echo "server is ready to start!"

echo "update server with branch content"

ssh ${USER}@${PUBLIC_IP} 'mkdir ~/content'
ssh ${USER}@${PUBLIC_IP} 'mkdir ~/TestPlaybooks'

scp content.zip ${USER}@${PUBLIC_IP}:~/content
scp -r ./TestPlaybooks/* ${USER}@${PUBLIC_IP}:~/TestPlaybooks

# override exiting content with current
COPY_CONTENT_COMMAND="sudo unzip -o ~/content/content.zip -d /usr/local/demisto/res \
    && sudo cp ~/TestPlaybooks/* /usr/local/demisto/res"
ssh -t ${USER}@${PUBLIC_IP} ${COPY_CONTENT_COMMAND}

echo "start server"

START_SERVER_COMMAND="sudo systemctl start demisto"
ssh -t ${USER}@${PUBLIC_IP} ${START_SERVER_COMMAND}

echo "wait for server to start on ip $PUBLIC_IP"

wget --retry-connrefused --no-check-certificate -T 60 "https://${PUBLIC_IP}:443"

echo "server started!"