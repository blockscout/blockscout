import $ from 'jquery'
import { walletEnabled, getCurrentAccount } from './write.js'
import { openErrorModal, openWarningModal, openSuccessModal } from '../modals.js'

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
    } else {
      walletEnabled()
        .then((isWalletEnabled) => {
          if (isWalletEnabled) {
            const functionName = $form.find('input[name=function_name]').val()

            const $functionInputs = $form.find('input[name=function_input]')
            const args = $.map($functionInputs, element => {
              return $(element).val()
            })

            const contractAddress = $form.data('contract-address')
            const contractAbi = $form.data('contract-abi')

            getCurrentAccount()
              .then(currentAccount => {
                const TargetContract = new window.web3.eth.Contract(contractAbi, contractAddress)

                TargetContract.methods[functionName](...args).send({ from: currentAccount })
                  .on('error', function (error) {
                    openErrorModal(`Error in sending transaction for method "${functionName}"`, error, false)
                  })
                  .on('transactionHash', function (txHash) {
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
          } else {
            openWarningModal('Unauthorized', 'You haven\'t approved the reading of account list from your MetaMask/Nifty wallet or MetaMask/Nifty wallet is not installed.')
          }
        })
    }
  })
}

const container = $('[data-smart-contract-functions]')

if (container.length) {
  loadFunctions(container)
}
