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
      window.ethereum.enable()
      window.web3 = new Web3(window.web3.currentProvider)
      return Promise.resolve(true)
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
    window.ethereum.enable()
  }
}

export const getCurrentAccount = async () => {
  const accounts = await window.web3.eth.getAccounts()
  const account = accounts[0] ? accounts[0].toLowerCase() : null

  return account
}

export const hideConnectButton = () => {
  if (window.ethereum) {
    window.web3 = new Web3(window.ethereum)
    if (window.ethereum.isNiftyWallet) {
      return true
    } else if (window.ethereum.isMetaMask) {
      if (window.ethereum.selectedAddress) {
        return true
      } else {
        return false
      }
    } else {
      return true
    }
  } else {
    return false
  }
}
