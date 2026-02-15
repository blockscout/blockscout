export DISPLAY=:99.0
sh -e /etc/init.d/xvfb start

#export CHROMEDRIVER_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json" | jq -r '.channels' | jq -r '.Stable' | jq -r '.version')
export CHROMEDRIVER_VERSION=144.0.7559.133
curl -L -O "https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/${CHROMEDRIVER_VERSION}/linux64/chromedriver-linux64.zip"
unzip -j chromedriver-linux64.zip
sudo chmod +x chromedriver
sudo mv chromedriver /usr/local/bin
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt-get update
sudo apt-get install libstdc++6
sudo apt install ./google-chrome-stable_current_amd64.deb
