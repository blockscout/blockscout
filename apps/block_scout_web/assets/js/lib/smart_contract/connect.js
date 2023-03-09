import Web3 from 'web3'
import Web3Modal from 'web3modal'
import WalletConnectProvider from '@walletconnect/web3-provider'
import { compareChainIDs, formatError, showConnectElements, showConnectedToElements } from './common_helpers'
import { openWarningModal } from '../modals'
import * as Sentry from '@sentry/browser'

// @ts-ignore
const instanceChainIdStr = document.getElementById('js-chain-id').value
const instanceChainId = parseInt(instanceChainIdStr, 10)
const walletConnectOptions = { rpc: {}, chainId: instanceChainId }
// @ts-ignore
const jsonRPC = document.getElementById('js-json-rpc').value
walletConnectOptions.rpc[instanceChainId] = jsonRPC

// Chosen wallet provider given by the dialog window
let provider

// Web3modal instance
let web3Modal

/**
 * Setup the orchestra
 */
export async function web3ModalInit (connectToWallet, ...args) {
  return new Promise((resolve) => {
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
      cacheProvider: true,
      providerOptions,
      disableInjectedProvider: false
    })

    if (web3Modal.cachedProvider) {
      connectToWallet(...args)
    }

    resolve(web3Modal)
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

export async function disconnect () {
  if (provider && provider.close) {
    await provider.close()
  }

  provider = null

  window.web3 = null

  // If the cached provider is not cleared,
  // WalletConnect will default to the existing session
  // and does not allow to re-scan the QR code with a new wallet.
  // Depending on your use case you may want or want not his behavior.
  await web3Modal.clearCachedProvider()
}

/**
 * Disconnect wallet button pressed.
 */
export async function disconnectWallet () {
  await disconnect()

  showConnectElements()
}

export const connectToProvider = () => {
  return new Promise((resolve, reject) => {
    try {
      web3Modal
        .connect()
        .then((connectedProvider) => {
          provider = connectedProvider
          window.web3 = new Web3(provider)
          resolve(provider)
        })
    } catch (e) {
      reject(e)
    }
  })
}

export const connectToWallet = async () => {
  await connectToProvider()

  // Subscribe to accounts change
  provider.on('accountsChanged', async (accs) => {
    const newAccount = accs && accs.length > 0 ? accs[0].toLowerCase() : null

    if (!newAccount) {
      await disconnectWallet()
    }

    fetchAccountData(showConnectedToElements, [])
  })

  // Subscribe to chainId change
  provider.on('chainChanged', (chainId) => {
    compareChainIDs(instanceChainId, chainId)
      .then(() => fetchAccountData(showConnectedToElements, []))
      .catch(error => {
        openWarningModal('Unauthorized', formatError(error))
      })
  })

  provider.on('disconnect', async () => {
    await disconnectWallet()
  })

  await fetchAccountData(showConnectedToElements, [])
}

export const shouldHideConnectButton = () => {
  return new Promise((resolve) => {
    if (window.ethereum) {
      window.web3 = new Web3(window.ethereum)
      if (window.ethereum.isNiftyWallet) {
        resolve({ shouldHide: true, account: window.ethereum.selectedAddress })
      } else if (window.ethereum.isMetaMask) {
        window.ethereum.request({ method: 'eth_accounts' })
          .then(accounts => {
            accounts.length > 0 ? resolve({ shouldHide: true, account: accounts[0] }) : resolve({ shouldHide: false })
          })
          .catch(error => {
            Sentry.captureException(error)
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

export async function fetchAccountData (setAccount, args) {
  // Get a Web3 instance for the wallet
  if (provider) {
    window.web3 = new Web3(provider)
  }

  // Get list of accounts of the connected wallet
  const accounts = window.web3 && await window.web3.eth.getAccounts()

  // MetaMask does not give you all accounts, only the selected account
  if (accounts && accounts.length > 0) {
    const selectedAccount = accounts[0]

    setAccount(selectedAccount, ...args)
  }
}
