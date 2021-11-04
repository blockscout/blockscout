import Web3 from 'web3'
import $ from 'jquery'
import { openErrorModal, openWarningModal, openSuccessModal, openModalWithMessage } from '../modals'
import { compareChainIDs, formatError, formatTitleAndError, getContractABI, getCurrentAccount, getMethodInputs, prepareMethodArgs } from './common_helpers'

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

export function callMethod (isWalletEnabled, $functionInputs, explorerChainId, $form, functionName, $element) {
  if (!isWalletEnabled) {
    const warningMsg = 'You haven\'t approved the reading of account list from your MetaMask or MetaMask/Nifty wallet is locked or is not installed.'
    return openWarningModal('Unauthorized', warningMsg)
  }
  const contractAbi = getContractABI($form)
  const inputs = getMethodInputs(contractAbi, functionName)

  const $functionInputsExceptTxValue = $functionInputs.filter(':not([tx-value])')
  const args = prepareMethodArgs($functionInputsExceptTxValue, inputs)

  const txValue = getTxValue($functionInputs)
  const contractAddress = $form.data('contract-address')

  const { chainId: walletChainIdHex } = window.ethereum
  compareChainIDs(explorerChainId, walletChainIdHex)
    .then(() => getCurrentAccount())
    .then(currentAccount => {
      if (functionName) {
        const TargetContract = new window.web3.eth.Contract(contractAbi, contractAddress)
        const sendParams = { from: currentAccount, value: txValue || 0 }
        const methodToCall = TargetContract.methods[functionName](...args).send(sendParams)
        methodToCall
          .on('error', function (error) {
            var titleAndError = formatTitleAndError(error)
            var message = titleAndError.message + (titleAndError.txHash ? `<br><a href="/tx/${titleAndError.txHash}">More info</a>` : '')
            openErrorModal(titleAndError.title.length ? titleAndError.title : `Error in sending transaction for method "${functionName}"`, message, false)
          })
          .on('transactionHash', function (txHash) {
            onTransactionHash(txHash, $element, functionName)
          })
      } else {
        const txParams = {
          from: currentAccount,
          to: contractAddress,
          value: txValue || 0
        }
        window.ethereum.request({
          method: 'eth_sendTransaction',
          params: [txParams]
        })
          .then(function (txHash) {
            onTransactionHash(txHash, $element, functionName)
          })
          .catch(function (error) {
            openErrorModal('Error in sending transaction for fallback method', formatError(error), false)
          })
      }
    })
    .catch(error => {
      openWarningModal('Unauthorized', formatError(error))
    })
}

export function queryMethod (isWalletEnabled, url, $methodId, args, type, functionName, $responseContainer) {
  var data = {
    function_name: functionName,
    method_id: $methodId.val(),
    type: type,
    args
  }
  if (isWalletEnabled) {
    getCurrentAccount()
      .then((currentAccount) => {
        data = {
          function_name: functionName,
          method_id: $methodId.val(),
          type: type,
          from: currentAccount,
          args
        }
        $.get(url, data, response => $responseContainer.html(response))
      }
      )
  } else {
    $.get(url, data, response => $responseContainer.html(response))
  }
}

function onTransactionHash (txHash, $element, functionName) {
  openModalWithMessage($element.find('#pending-contract-write'), true, txHash)
  const getTxReceipt = (txHash) => {
    window.ethereum.request({
      method: 'eth_getTransactionReceipt',
      params: [txHash]
    })
      .then(txReceipt => {
        if (txReceipt) {
          const successMsg = `Successfully sent <a href="/tx/${txHash}">transaction</a> for method "${functionName}"`
          openSuccessModal('Success', successMsg)
          clearInterval(txReceiptPollingIntervalId)
        }
      })
  }
  const txReceiptPollingIntervalId = setInterval(() => { getTxReceipt(txHash) }, 5 * 1000)
}

function getTxValue ($functionInputs) {
  const WEI_MULTIPLIER = 10 ** 18
  const $txValue = $functionInputs.filter('[tx-value]:first')
  const txValue = $txValue && $txValue.val() && parseFloat($txValue.val()) * WEI_MULTIPLIER
  var txValueStr = txValue && txValue.toString(16)
  if (!txValueStr) {
    txValueStr = '0'
  }
  return '0x' + txValueStr
}
