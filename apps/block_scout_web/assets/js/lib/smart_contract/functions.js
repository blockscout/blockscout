import $ from 'jquery'
import { props } from 'eth-net-props'
import { walletEnabled, connectToWallet, getCurrentAccount, shouldHideConnectButton } from './write.js'
import { openErrorModal, openWarningModal, openSuccessModal, openModalWithMessage } from '../modals.js'
import '../../pages/address'

const loadFunctions = (element) => {
  const $element = $(element)
  const url = $element.data('url')
  const hash = $element.data('hash')
  const type = $element.data('type')
  const action = $element.data('action')

  $.get(
    url,
    { hash: hash, type: type, action: action },
    response => $element.html(response)
  )
    .done(function () {
      const $connect = $('[connect-metamask]')
      const $connectTo = $('[connect-to]')
      const $connectedTo = $('[connected-to]')
      const $reconnect = $('[re-connect-metamask]')

      window.ethereum && window.ethereum.on('accountsChanged', function (accounts) {
        if (accounts.length === 0) {
          showConnectElements($connect, $connectTo, $connectedTo)
        } else {
          showConnectedToElements($connect, $connectTo, $connectedTo, accounts[0])
        }
      })

      shouldHideConnectButton()
        .then(({ shouldHide, account }) => {
          if (shouldHide && account) {
            showConnectedToElements($connect, $connectTo, $connectedTo, account)
          } else if (shouldHide) {
            hideConnectButton($connect, $connectTo, $connectedTo)
          } else {
            showConnectElements($connect, $connectTo, $connectedTo)
          }
        })

      $connect.on('click', () => {
        connectToWallet()
      })

      $reconnect.on('click', () => {
        connectToWallet()
      })

      $('[data-function]').each((_, element) => {
        readWriteFunction(element)
      })
    })
    .fail(function (response) {
      $element.html(response.statusText)
    })
}

function showConnectedToElements ($connect, $connectTo, $connectedTo, account) {
  $connectTo.addClass('hidden')
  $connect.removeClass('hidden')
  $connectedTo.removeClass('hidden')
  setConnectToAddress(account)
}

function setConnectToAddress (account) {
  const $connectedToAddress = $('[connected-to-address]')
  $connectedToAddress.html(`<a href='/address/${account}'>${account}</a>`)
}

function showConnectElements ($connect, $connectTo, $connectedTo) {
  $connectTo.removeClass('hidden')
  $connect.removeClass('hidden')
  $connectedTo.addClass('hidden')
}

function hideConnectButton ($connect, $connectTo, $connectedTo) {
  $connectTo.removeClass('hidden')
  $connect.addClass('hidden')
  $connectedTo.addClass('hidden')
}

const readWriteFunction = (element) => {
  const $element = $(element)
  const $form = $element.find('[data-function-form]')

  const $responseContainer = $element.find('[data-function-response]')

  $form.on('submit', (event) => {
    const action = $form.data('action')
    event.preventDefault()

    const $functionInputs = $form.find('input[name=function_input]')
    const $functionName = $form.find('input[name=function_name]')
    const functionName = $functionName && $functionName.val()

    if (action === 'read') {
      const url = $form.data('url')

      const $methodId = $form.find('input[name=method_id]')
      const args = $.map($functionInputs, element => $(element).val())

      const data = {
        function_name: functionName,
        method_id: $methodId.val(),
        args
      }

      $.get(url, data, response => $responseContainer.html(response))
    } else if (action === 'write') {
      const explorerChainId = $form.data('chainId')
      walletEnabled()
        .then((isWalletEnabled) => callMethod(isWalletEnabled, $functionInputs, explorerChainId, $form, functionName, $element))
    }
  })
}

function callMethod (isWalletEnabled, $functionInputs, explorerChainId, $form, functionName, $element) {
  if (!isWalletEnabled) {
    const warningMsg = 'You haven\'t approved the reading of account list from your MetaMask or MetaMask/Nifty wallet is locked or is not installed.'
    return openWarningModal('Unauthorized', warningMsg)
  }
  const contractAbi = getContractABI($form)
  const functionAbi = contractAbi.find(abi =>
    abi.name === functionName
  )
  const inputs = functionAbi && functionAbi.inputs

  const $functionInputsExceptTxValue = $functionInputs.filter(':not([tx-value])')
  const args = $.map($functionInputsExceptTxValue, (element, ind) => {
    const val = $(element).val()
    const inputType = inputs[ind] && inputs[ind].type
    let preparedVal
    if (isNonSpaceInputType(inputType)) { preparedVal = val.replace(/\s/g, '') } else { preparedVal = val }
    if (isArrayInputType(inputType)) {
      return preparedVal.split(',')
    } else { return preparedVal }
  })

  const txValue = getTxValue($functionInputs)
  const contractAddress = $form.data('contract-address')

  const { chainId: walletChainIdHex } = window.ethereum
  compareChainIDs(explorerChainId, walletChainIdHex)
    .then(currentAccount => {
      if (functionName) {
        const TargetContract = new window.web3.eth.Contract(contractAbi, contractAddress)
        const inputsCount = inputs && inputs.length
        let methodToCall
        const sendParams = { from: currentAccount, value: txValue || 0 }
        if (inputsCount > 1 || inputsCount === 0) {
          methodToCall = TargetContract.methods[functionName](...args).send(sendParams)
        } else {
          const inputType = inputs[0] && inputs[0].type
          if (Array.isArray(args) && args[0] === '') {
            if (isArrayInputType(inputType)) {
              methodToCall = TargetContract.methods[functionName]([]).send(sendParams)
            } else {
              methodToCall = TargetContract.methods[functionName]().send(sendParams)
            }
          } else {
            if (isArrayInputType(inputType)) {
              methodToCall = TargetContract.methods[functionName](args).send(sendParams)
            } else {
              methodToCall = TargetContract.methods[functionName](args[0]).send(sendParams)
            }
          }
        }
        methodToCall
          .on('error', function (error) {
            openErrorModal(`Error in sending transaction for method "${functionName}"`, formatError(error), false)
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

function isArrayInputType (inputType) {
  return inputType && inputType.includes('[]')
}

function isNonSpaceInputType (inputType) {
  return inputType.includes('address') || inputType.includes('int') || inputType.includes('bool')
}

function getTxValue ($functionInputs) {
  const WEI_MULTIPLIER = 10 ** 18
  const $txValue = $functionInputs.filter('[tx-value]:first')
  const txValue = $txValue && $txValue.val() && parseFloat($txValue.val()) * WEI_MULTIPLIER
  const txValueStr = txValue && txValue.toString(16)
  return txValueStr
}

function getContractABI ($form) {
  const implementationAbi = $form.data('implementation-abi')
  const parentAbi = $form.data('contract-abi')
  const $parent = $('[data-smart-contract-functions]')
  const contractType = $parent.data('type')
  const contractAbi = contractType === 'proxy' ? implementationAbi : parentAbi
  return contractAbi
}

function compareChainIDs (explorerChainId, walletChainIdHex) {
  if (explorerChainId !== parseInt(walletChainIdHex)) {
    const networkDisplayNameFromWallet = props.getNetworkDisplayName(walletChainIdHex)
    const networkDisplayName = props.getNetworkDisplayName(explorerChainId)
    const errorMsg = `You connected to ${networkDisplayNameFromWallet} chain in the wallet, but the current instance of Blockscout is for ${networkDisplayName} chain`
    return Promise.reject(new Error(errorMsg))
  } else {
    return getCurrentAccount()
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

const formatError = (error) => {
  let { message } = error
  message = message && message.split('Error: ').length > 1 ? message.split('Error: ')[1] : message
  return message
}

const container = $('[data-smart-contract-functions]')

if (container.length) {
  loadFunctions(container)
}
