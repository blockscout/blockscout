import Web3 from 'web3'
import Web3Modal from 'web3modal'
import WalletConnectProvider from '@walletconnect/web3-provider'
import { showConnectElements, showConnectedToElements } from './common_helpers'

const instanceChainId = process.env.CHAIN_ID ? parseInt(`${process.env.CHAIN_ID}`, 10) : 77
const walletConnectOptions = { rpc: {}, chainId: instanceChainId }
walletConnectOptions.rpc[instanceChainId] = 'https://sokol.poa.network'

let selectedAccount

// Chosen wallet provider given by the dialog window
let provider

// Web3modal instance
let web3Modal

/**
 * Setup the orchestra
 */
export function init () {
  // Tell Web3modal what providers we have available.
  // Built-in web browser provider (only one can exist as a time)
  // like MetaMask, Brave or Opera is added automatically by Web3modal
  const providerOptions = {
    walletconnect: {
      package: WalletConnectProvider,
      options: walletConnectOptions
    }
  }

  web3Modal = new Web3Modal({
    cacheProvider: false, // optional
    providerOptions, // required
    disableInjectedProvider: false // optional. For MetaMask / Brave / Opera.
  })

}

export const walletEnabled = () => {
  return new Promise((resolve) => {
    if (window.web3 && window.web3.currentProvider && window.web3.currentProvider.wc) {
      resolve(true)
    } else {
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
                  .catch(_error => {
                    resolve(false)
                  })
              }
            }
          })
          .catch(_error => {
            resolve(false)
          })
      } else if (window.web3) {
        window.web3 = new Web3(window.web3.currentProvider)
        resolve(true)
      } else {
        resolve(false)
      }
    }
  })
}

export const shouldHideConnectButton = (provider) => {
  return new Promise((resolve) => {
    if (window.ethereum) {
      window.web3 = new Web3(provider)
      if (window.ethereum.isNiftyWallet) {
        resolve({ shouldHide: true, account: window.ethereum.selectedAddress })
      } else if (window.ethereum.isMetaMask) {
        window.ethereum.request({ method: 'eth_accounts' })
          .then(accounts => {
            accounts.length > 0 ? resolve({ shouldHide: true, account: accounts[0] }) : resolve({ shouldHide: false })
          })
          .catch(_error => {
            resolve({ shouldHide: false })
          })
      } else {
        resolve({ shouldHide: true, account: window.ethereum.selectedAddress })
      }
    } else {
      resolve({ shouldHide: false })
    }
  })
}

export const connectToWallet = async () => {
  try {
    provider = await web3Modal.connect()
    window.web3 = new Web3(provider)
  } catch (e) {
    return
  }

  // Subscribe to accounts change
  provider.on('accountsChanged', (accounts) => {
    fetchAccountData()
  })

  // Subscribe to chainId change
  provider.on('chainChanged', (chainId) => {
    compareChainIDs(instanceChainId, chainId)
      .then(() => fetchAccountData())
      .catch(error => {
        openWarningModal('Unauthorized', formatError(error))
      })
    fetchAccountData()
  })

  await refreshAccountData()
}

/**
 * Disconnect wallet button pressed.
 */
export const disconnectWallet = async () => {
  if (provider && provider.close) {
    await provider.close()

    // If the cached provider is not cleared,
    // WalletConnect will default to the existing session
    // and does not allow to re-scan the QR code with a new wallet.
    // Depending on your use case you may want or want not his behavir.
    await web3Modal.clearCachedProvider()
    provider = null
    window.web3 = null

    showConnectElements()
  }

  selectedAccount = null
}

async function fetchAccountData () {
  // Get a Web3 instance for the wallet
  window.web3 = new Web3(provider)

  // Get list of accounts of the connected wallet
  const accounts = await window.web3.eth.getAccounts()

  // MetaMask does not give you all accounts, only the selected account
  if (accounts.length > 0) {
    selectedAccount = accounts[0]

    showConnectedToElements(selectedAccount, provider)
  }
}

async function refreshAccountData () {
  await fetchAccountData(provider)
}
