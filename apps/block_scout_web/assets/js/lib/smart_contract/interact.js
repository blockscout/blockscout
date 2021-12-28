import $ from 'jquery'
import { openErrorModal, openWarningModal, openSuccessModal, openModalWithMessage } from '../modals'
import { compareChainIDs, formatError, formatTitleAndError, getContractABI, getCurrentAccountPromise, getMethodInputs, prepareMethodArgs } from './common_helpers'
import BigNumber from 'bignumber.js'

export const queryMethod = (isWalletEnabled, url, $methodId, args, type, functionName, $responseContainer) => {
  let data = {
    function_name: functionName,
    method_id: $methodId.val(),
    type: type,
    args
  }
  if (isWalletEnabled) {
    getCurrentAccountPromise(window.web3 && window.web3.currentProvider)
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
          const successMsg = `Successfully sent <a href="/xdai/mainnet/tx/${txHash}">transaction</a> for method "${functionName}"`
          openSuccessModal('Success', successMsg)
          clearInterval(txReceiptPollingIntervalId)
        }
      })
  }
  const txReceiptPollingIntervalId = setInterval(() => { getTxReceipt(txHash) }, 5 * 1000)
}

const ethStrToWeiBn = ethStr => BigNumber(ethStr).multipliedBy(10 ** 18)

function getTxValue ($functionInputs) {
  const txValueEth = $functionInputs.filter('[tx-value]:first')?.val() || '0'
  return `0x${ethStrToWeiBn(txValueEth).toString(16)}`
}
