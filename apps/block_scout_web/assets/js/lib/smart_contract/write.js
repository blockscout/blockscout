import Web3 from 'web3'

export const walletEnabled = () => {
  if (window.ethereum) {
    window.web3 = new Web3(window.ethereum)
    if (window.ethereum._state && window.ethereum._state.isUnlocked) { // Nifty Wallet
      window.web3 = new Web3(window.web3.currentProvider)
      return Promise.resolve(true)
    } else if (window.ethereum._state && window.ethereum._state.isUnlocked === false) { // Nifty Wallet
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

export const getCurrentAccount = async () => {
  const accounts = await window.web3.eth.getAccounts()
  const account = accounts[0] ? accounts[0].toLowerCase() : null

  return account
}
