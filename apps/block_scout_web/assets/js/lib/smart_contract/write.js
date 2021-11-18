import { openErrorModal, openWarningModal, openSuccessModal, openModalWithMessage } from '../modals'
import { compareChainIDs, formatError, formatTitleAndError, getContractABI, getCurrentAccountPromise, getMethodInputs, prepareMethodArgs } from './common_helpers'
import { connectToWallet, disconnectWallet, init } from './connect.js'

export const callMethod = (isWalletEnabled, $functionInputs, explorerChainId, $form, functionName, $element) => {
  if (!isWalletEnabled) {
    const warningMsg = 'Wallet is not connected.'
    return openWarningModal('Unauthorized', warningMsg)
  }
  const contractAbi = getContractABI($form)
  const inputs = getMethodInputs(contractAbi, functionName)

  const $functionInputsExceptTxValue = $functionInputs.filter(':not([tx-value])')
  const args = prepareMethodArgs($functionInputsExceptTxValue, inputs)

  const txValue = getTxValue($functionInputs)
  const contractAddress = $form.data('contract-address')

  window.web3.eth.getChainId()
    .then((walletChainId) => {
      compareChainIDs(explorerChainId, walletChainId)
        .then(() => getCurrentAccountPromise(window.web3.currentProvider))
        .catch(error => {
          openWarningModal('Unauthorized', formatError(error))
        })
        .then((currentAccount) => {
          if (functionName) {
            const TargetContract = new window.web3.eth.Contract(contractAbi, contractAddress)
            const sendParams = { from: currentAccount, value: txValue || 0 }
            const methodToCall = TargetContract.methods[functionName](...args).send(sendParams)
            methodToCall
              .on('error', function (error) {
                const titleAndError = formatTitleAndError(error)
                const message = titleAndError.message + (titleAndError.txHash ? `<br><a href="/tx/${titleAndError.txHash}">More info</a>` : '')
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
    })
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
  let txValueStr = txValue && txValue.toString(16)
  if (!txValueStr) {
    txValueStr = '0'
  }
  return '0x' + txValueStr
}

window.addEventListener('load', async () => {
  init()
  document.querySelector('[connect-wallet]') && document.querySelector('[connect-wallet]').addEventListener('click', connectToWallet)
  document.querySelector('[disconnect-wallet]') && document.querySelector('[disconnect-wallet]').addEventListener('click', disconnectWallet)
})