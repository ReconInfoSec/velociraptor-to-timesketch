#!/bin/bash
# Custom bootstrap script for Ubuntu Linux

set -e
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "[+] Start bootstrap script for Linux ${linux_os}"
echo "[+] Installing initial packages"
sudo apt-get update -y
sudo apt-get install net-tools -y
sudo apt-get install unzip -y

# Golang 1.22 install
echo "Installing Golang 1.22"
sudo wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
sudo tar -C /usr/local/ -xvf go1.22.0.linux-amd64.tar.gz  
echo "export GOROOT=/usr/local/go" >> /home/ubuntu/.profile
echo "export GOPATH=$HOME/go" >> /home/ubuntu/.profile 
echo "export PATH=$PATH:/usr/local/go/bin" >> /home/ubuntu/.profile
echo "export GOCACHE=/home/ubuntu/go/cache" >> /home/ubuntu/.profile
echo "export HOME=/home/ubuntu" >> /home/ubuntu/.profile
echo "export HOME=/home/ubuntu" >> /home/ubuntu/.bashrc
source /home/ubuntu/.profile
source /home/ubuntu/.bashrc

# Breaches be Crazy
# Reference:  https://github.com/ReconInfoSec/velociraptor-to-timesketch/
apt install python3 python3-pip unzip -y
pip3 install --upgrade awscli

# Install Docker
echo "[+] Installing Docker"
sudo apt-get install -y ca-certificates curl gnupg unzip lsb-release -y
sudo mkdir -p /etc/apt/keyrings
# Installing docker needed by Timesketch 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install Timesketch 
echo "[+] Download timesketch helper script"
cd /opt
file="deploy_timesketch.sh"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /opt/deploy_timesketch.sh

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Run the deploy_timesketch.sh script
echo "Start running deploy_timesketch.sh"
chmod 755 deploy_timesketch.sh
/opt/deploy_timesketch.sh
cd /opt/timesketch
echo "Docker compose up for timesketch"
sudo docker compose up -d

# Create the first user
echo "Creating timesketch user"
docker compose exec timesketch-web tsctl create-user ${timesketch_user} --password ${timesketch_pass} 

# End of deploying timesketch
echo "Finished deploying timesketch"

# Setup for custom scripts from Breaches Be Crazy
# Huge HT to @shortstack, @ecapuano
# Reference:  https://github.com/ReconInfoSec/velociraptor-to-timesketch

# Download watch-s3-to-timesketch.py
file="${python_watch_s3}"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /opt/$file

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Download watch-plaso-to-s3.sh
file="${sh_watch_plaso}"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /opt/$file

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Download watch-to-timesketch.sh
file="${sh_watch_to_time}"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /opt/$file
    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Download data-to-timesketch.service 
file="${svc_data_to_time}"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /opt/$file
    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Download watch-plaso-to-s3.service
file="${svc_watch_plaso}"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /opt/$file
    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Download watch-s3-to-timesketch.service
file="${svc_watch_s3}"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /opt/$file
    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Copied from deploy.sh script
# Reference:  https://github.com/ReconInfoSec/velociraptor-to-timesketch
# Install system requirements
echo "[+] Running deploy.sh script steps"
apt install inotify-tools -y 

# Install pip requirements
pip3 install boto3 pytz 
#apt-get install docker-compose -y
curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
cd /opt/timesketch
docker-compose exec timesketch-worker bash -c "pip3 install timesketch-import-client"

# Fix permissions
sudo chmod +x /opt/watch-plaso-to-s3.sh
sudo chmod +x /opt/watch-to-timesketch.sh

# Make sure Plaso dirs exist
sudo mkdir -p /opt/timesketch/upload/plaso
sudo mkdir -p /opt/timesketch/upload/plaso_complete

# Configure services
sudo cp /opt/data-to-timesketch.service /etc/systemd/system/data-to-timesketch.service
sudo systemctl enable data-to-timesketch.service
sudo systemctl start data-to-timesketch.service

sudo cp /opt/watch-plaso-to-s3.service /etc/systemd/system/watch-plaso-to-s3.service
sudo systemctl enable watch-plaso-to-s3.service
sudo systemctl start watch-plaso-to-s3.service

sudo cp /opt/watch-s3-to-timesketch.service /etc/systemd/system/watch-s3-to-timesketch.service
sudo systemctl enable watch-s3-to-timesketch.service
sudo systemctl start watch-s3-to-timesketch.service

# End of script 
echo "[+] End of bootstrap script"
