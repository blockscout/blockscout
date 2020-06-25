import $ from 'jquery'
import ethNetProps from 'eth-net-props'
import { walletEnabled, getCurrentAccount } from './write.js'
import { openErrorModal, openWarningModal, openSuccessModal, openModalWithMessage } from '../modals.js'

const WEI_MULTIPLIER = 10 ** 18

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
      $('[data-function]').each((_, element) => {
        readWriteFunction(element)
      })
    })
    .fail(function (response) {
      $element.html(response.statusText)
    })
}

const readWriteFunction = (element) => {
  const $element = $(element)
  const $form = $element.find('[data-function-form]')

  const $responseContainer = $element.find('[data-function-response]')

  $form.on('submit', (event) => {
    const action = $form.data('action')
    const contractType = $form.data('contract-type')
    event.preventDefault()

    if (action === 'read') {
      const url = $form.data('url')
      const $functionName = $form.find('input[name=function_name]')
      const $functionInputs = $form.find('input[name=function_input]')

      const args = $.map($functionInputs, element => {
        return $(element).val()
      })

      const data = {
        function_name: $functionName.val(),
        args
      }

      $.get(url, data, response => $responseContainer.html(response))
    } else if (action === 'write') {
      const chainId = $form.data('chainId')
      walletEnabled()
        .then((isWalletEnabled) => {
          if (isWalletEnabled) {
            const functionName = $form.find('input[name=function_name]').val()

            const $functionInputs = $form.find('input[name=function_input]')
            const $functionInputsExceptTxValue = $functionInputs.filter(':not([tx-value])')
            const args = $.map($functionInputsExceptTxValue, element => $(element).val())

            const $txValue = $functionInputs.filter('[tx-value]:first')

            const txValue = $txValue && $txValue.val() && parseFloat($txValue.val()) * WEI_MULTIPLIER

            const contractAddress = $form.data('contract-address')
            const implementationAbi = $form.data('implementation-abi')
            const parentAbi = $form.data('contract-abi')
            const contractAbi = contractType === 'proxy' ? implementationAbi : parentAbi

            window.web3.eth.getChainId()
              .then(chainIdFromWallet => {
                if (chainId !== chainIdFromWallet) {
                  const networkDisplayNameFromWallet = ethNetProps.props.getNetworkDisplayName(chainIdFromWallet)
                  const networkDisplayName = ethNetProps.props.getNetworkDisplayName(chainId)
                  return Promise.reject(new Error(`You connected to ${networkDisplayNameFromWallet} chain in the wallet, but the current instance of Blockscout is for ${networkDisplayName} chain`))
                } else {
                  return getCurrentAccount()
                }
              })
              .then(currentAccount => {
                let methodToCall

                if (functionName) {
                  const TargetContract = new window.web3.eth.Contract(contractAbi, contractAddress)
                  methodToCall = TargetContract.methods[functionName](...args).send({ from: currentAccount, value: txValue || 0 })
                } else {
                  const txParams = {
                    from: currentAccount,
                    to: contractAddress,
                    value: txValue || 0
                  }
                  methodToCall = window.web3.eth.sendTransaction(txParams)
                }

                methodToCall
                  .on('error', function (error) {
                    openErrorModal(`Error in sending transaction for method "${functionName}"`, formatError(error), false)
                  })
                  .on('transactionHash', function (txHash) {
                    openModalWithMessage($element.find('#pending-contract-write'), true, txHash)
                    const getTxReceipt = (txHash) => {
                      window.web3.eth.getTransactionReceipt(txHash)
                        .then(txReceipt => {
                          if (txReceipt) {
                            openSuccessModal('Success', `Successfully sent <a href="/tx/${txHash}">transaction</a> for method "${functionName}"`)
                            clearInterval(txReceiptPollingIntervalId)
                          }
                        })
                    }
                    const txReceiptPollingIntervalId = setInterval(() => { getTxReceipt(txHash) }, 5 * 1000)
                  })
              })
              .catch(error => {
                openWarningModal('Unauthorized', formatError(error))
              })
          } else {
            openWarningModal('Unauthorized', 'You haven\'t approved the reading of account list from your MetaMask or MetaMask/Nifty wallet is locked or is not installed.')
          }
        })
    }
  })
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
