sudo apt-get update
sudo apt-get -y install xvfb
export DISPLAY=:99.0
Xvfb $DISPLAY -screen 0 1024x768x16 -nolisten tcp &
# sh -e /etc/init.d/xvfb start
# export CHROMEDRIVER_VERSION=`curl -s http://chromedriver.storage.googleapis.com/LATEST_RELEASE`
export CHROMEDRIVER_VERSION="99.0.4844.51"
curl -L -O "http://chromedriver.storage.googleapis.com/${CHROMEDRIVER_VERSION}/chromedriver_linux64.zip"
unzip chromedriver_linux64.zip
sudo chmod +x chromedriver
sudo mv chromedriver /usr/local/bin
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt -y install ./google-chrome-stable_current_amd64.deb
sudo apt-get -y install libstdc++6