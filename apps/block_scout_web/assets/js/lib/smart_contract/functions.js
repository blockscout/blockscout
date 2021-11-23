import $ from 'jquery'
import { getContractABI, getMethodInputs, prepareMethodArgs, showConnectElements, showConnectedToElements, hideConnectButton } from './common_helpers'
import { queryMethod, callMethod } from './interact'
import { walletEnabled, shouldHideConnectButton } from './connect.js'
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
      window.ethereum && window.ethereum.on('accountsChanged', function (accounts) {
        if (accounts.length === 0) {
          showConnectElements()
        } else {
          showConnectedToElements(accounts[0])
        }
      })

      const provider = window.web3 && window.web3.currentProvider
      shouldHideConnectButton(provider)
        .then(({ shouldHide, account }) => {
          if (shouldHide && account) {
            showConnectedToElements(account, provider)
          } else if (shouldHide) {
            hideConnectButton()
          } else {
            showConnectElements()
          }
        })

      $('[data-function]').each((_, element) => {
        readWriteFunction(element)
      })

      $('.contract-exponentiation-btn').on('click', (event) => {
        const $customPower = $(event.currentTarget).find('[name=custom_power]')
        let power
        if ($customPower.length > 0) {
          power = parseInt($customPower.val(), 10)
        } else {
          power = parseInt($(event.currentTarget).data('power'), 10)
        }
        const $input = $(event.currentTarget).parent().parent().parent().find('[name=function_input]')
        const currentInputVal = parseInt($input.val(), 10) || 1
        const newInputVal = (currentInputVal * Math.pow(10, power)).toString()
        $input.val(newInputVal.toString())
      })

      $('[name=custom_power]').on('click', (event) => {
        $(event.currentTarget).parent().parent().toggleClass('show')
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

    const $functionInputs = $form.find('input[name=function_input]')
    const $functionName = $form.find('input[name=function_name]')
    const functionName = $functionName && $functionName.val()

    if (action === 'read') {
      const url = $form.data('url')

      const contractAbi = getContractABI($form)
      const inputs = getMethodInputs(contractAbi, functionName)
      const $methodId = $form.find('input[name=method_id]')
      const args = prepareMethodArgs($functionInputs, inputs)
      const type = $('[data-smart-contract-functions]').data('type')

      walletEnabled()
        .then((isWalletEnabled) => queryMethod(isWalletEnabled, url, $methodId, args, type, functionName, $responseContainer))
    } else if (action === 'write') {
      const explorerChainId = $form.data('chainId')
      walletEnabled()
        .then((isWalletEnabled) => callMethod(isWalletEnabled, $functionInputs, explorerChainId, $form, functionName, $element))
    }
  })
}

const container = $('[data-smart-contract-functions]')

if (container.length) {
  loadFunctions(container)
}
