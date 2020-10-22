import Web3 from 'web3'

export const walletEnabled = () => {
  if (window.ethereum) {
    window.web3 = new Web3(window.ethereum)
    if (window.ethereum.isUnlocked && window.ethereum.isNiftyWallet) { // Nifty Wallet
      window.web3 = new Web3(window.web3.currentProvider)
      return Promise.resolve(true)
    } else if (window.ethereum.isUnlocked === false && window.ethereum.isNiftyWallet) { // Nifty Wallet
      return Promise.resolve(false)
    } else {
      if (window.ethereum.request) {
        return window.ethereum.request({ method: 'eth_requestAccounts' })
          .then((_res) => {
            window.web3 = new Web3(window.web3.currentProvider)
            return Promise.resolve(true)
          })
      } else {
        window.ethereum.enable()
        window.web3 = new Web3(window.web3.currentProvider)
        return Promise.resolve(true)
      }
    }
  } else if (window.web3) {
    window.web3 = new Web3(window.web3.currentProvider)
    return Promise.resolve(true)
  } else {
    return Promise.resolve(false)
  }
}

export const connectToWallet = () => {
  if (window.ethereum) {
    if (window.ethereum.request) {
      window.ethereum.request({ method: 'eth_requestAccounts' })
    } else {
      window.ethereum.enable()
    }
  }
}

export const getCurrentAccount = async () => {
  const accounts = await window.web3.eth.getAccounts()
  const account = accounts[0] ? accounts[0].toLowerCase() : null

  return account
}

export const hideConnectButton = () => {
  return new Promise((resolve) => {
    if (window.ethereum) {
      window.web3 = new Web3(window.ethereum)
      if (window.ethereum.isNiftyWallet) {
        resolve({ shouldHide: true, account: window.ethereum.selectedAddress })
      } else if (window.ethereum.isMetaMask) {
        window.ethereum.sendAsync({ method: 'eth_accounts' }, function (error, resp) {
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
