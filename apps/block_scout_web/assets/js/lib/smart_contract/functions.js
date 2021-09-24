import $ from 'jquery'
import { getContractABI, getMethodInputs, prepareMethodArgs } from './common_helpers'
import { walletEnabled, connectToWallet, shouldHideConnectButton, callMethod, queryMethod } from './write'
import '../../pages/address'
import * as Sentry from '@sentry/browser'

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
