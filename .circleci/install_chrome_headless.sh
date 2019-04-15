export DISPLAY=:99.0
sh -e /etc/init.d/xvfb start
export CHROMEDRIVER_VERSION=`curl -s http://chromedriver.storage.googleapis.com/LATEST_RELEASE`
curl -L -O "http://chromedriver.storage.googleapis.com/${CHROMEDRIVER_VERSION}/chromedriver_linux64.zip"
unzip chromedriver_linux64.zip
sudo chmod +x chromedriver
sudo mv chromedriver /usr/local/bin
sudo add-apt-repository ppa:ubuntu-toolchain-r/test --yes
sudo apt-get update
sudo apt-get --only-upgrade install google-chrome-stable
sudo apt-get install libstdc++6-4.7-dev
