export DISPLAY=:99.0
sh -e /etc/init.d/xvfb start
export CHROMEDRIVER_VERSION=$(curl -s http://chromedriver.storage.googleapis.com/LATEST_RELEASE)
# export CHROMEDRIVER_VERSION='104.0.5112.79'
sudo apt update
curl -L -O "http://chromedriver.storage.googleapis.com/${CHROMEDRIVER_VERSION}/chromedriver_linux64.zip"
unzip chromedriver_linux64.zip
sudo chmod +x chromedriver
sudo mv chromedriver /usr/local/bin
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y ./google-chrome-stable_current_amd64.deb
sudo apt-get install libstdc++6 libnss3-dev
