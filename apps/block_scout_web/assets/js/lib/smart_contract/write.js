import Web3 from 'web3'

export const walletEnabled = () => {
  return new Promise((resolve) => {
    if (window.ethereum) {
      window.web3 = new Web3(window.ethereum)
      window.ethereum._metamask.isUnlocked()
        .then(isUnlocked => {
          if (isUnlocked && window.ethereum.isNiftyWallet) { // Nifty Wallet
            window.web3 = new Web3(window.web3.currentProvider)
            resolve(true)
          } else if (isUnlocked === false && window.ethereum.isNiftyWallet) { // Nifty Wallet
            window.ethereum.enable()
            resolve(false)
          } else {
            if (window.ethereum.isNiftyWallet) {
              window.ethereum.enable()
              window.web3 = new Web3(window.web3.currentProvider)
              resolve(true)
            } else {
              return window.ethereum.request({ method: 'eth_requestAccounts' })
                .then((_res) => {
                  window.web3 = new Web3(window.web3.currentProvider)
                  resolve(true)
                })
            }
          }
        })
    } else if (window.web3) {
      window.web3 = new Web3(window.web3.currentProvider)
      resolve(true)
    } else {
      resolve(false)
    }
  })
}

export const connectToWallet = () => {
  if (window.ethereum) {
    if (window.ethereum.isNiftyWallet) {
      window.ethereum.enable()
    } else {
      window.ethereum.request({ method: 'eth_requestAccounts' })
    }
  }
}

export const getCurrentAccount = async () => {
  const accounts = await window.ethereum.request({ method: 'eth_accounts' })
  const account = accounts[0] ? accounts[0].toLowerCase() : null

  return account
}

export const shouldHideConnectButton = () => {
  return new Promise((resolve) => {
    if (window.ethereum) {
      window.web3 = new Web3(window.ethereum)
      if (window.ethereum.isNiftyWallet) {
        resolve({ shouldHide: true, account: window.ethereum.selectedAddress })
      } else if (window.ethereum.isMetaMask) {
        window.ethereum.request({ method: 'eth_accounts' }, function (error, resp) {
          if (error) {
            resolve({ shouldHide: false })
          }

          if (resp) {
            const { result: accounts } = resp
            accounts.length > 0 ? resolve({ shouldHide: true, account: accounts[0] }) : resolve({ shouldHide: false })
          }
        })
      } else {
        resolve({ shouldHide: true, account: window.ethereum.selectedAddress })
      }
    } else {
      resolve({ shouldHide: false })
    }
  })
}
