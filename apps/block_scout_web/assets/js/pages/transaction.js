import $ from 'jquery'
import omit from 'lodash.omit'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import '../lib/transaction_input_dropdown'
import '../lib/async_listing_load'
import { commonPath } from '../lib/path_helper'
import '../app'
import Swal from 'sweetalert2'
import { compareChainIDs, formatError } from '../lib/smart_contract/common_helpers'

export const initialState = {
  blockNumber: null,
  confirmations: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'RECEIVED_NEW_RAW_TRACE': {
      return Object.assign({}, state, {
        rawTrace: action.msg.rawTrace
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      if (state.blockNumber) {
        // @ts-ignore
        if ((action.msg.blockNumber - state.blockNumber) > state.confirmations) {
          return Object.assign({}, state, {
            confirmations: action.msg.blockNumber - state.blockNumber
          })
        } else return state
      } else return state
    }
    default:
      return state
  }
}

const elements = {
  '[data-selector="block-number"]': {
    load ($el) {
      return { blockNumber: parseInt($el.text(), 10) }
    }
  },
  '[data-selector="block-confirmations"]': {
    render ($el, state, oldState) {
      if (oldState.confirmations !== state.confirmations) {
        $el.empty().append(numeral(state.confirmations).format())
      }
    }
  },
  '[data-selector="raw-trace"]': {
    render ($el, state) {
      if (state.rawTrace) {
        $el[0].innerHTML = state.rawTrace
        state.rawTrace = null
        return $el
      }
      return $el
    }
  }
}

const $transactionDetailsPage = $('[data-page="transaction-details"]')
if ($transactionDetailsPage.length) {
  const store = createStore(reducer)
  connectElements({ store, elements })

  const transactionHash = $transactionDetailsPage[0].dataset.pageTransactionHash
  const transactionChannel = socket.channel(`transactions:${transactionHash}`, {})
  transactionChannel.join()
  transactionChannel.on('collated', () => window.location.reload())
  transactionChannel.on('raw_trace', (msg) => store.dispatch({
    type: 'RECEIVED_NEW_RAW_TRACE',
    msg: humps.camelizeKeys(msg)
  }))

  const pathParts = window.location.pathname.split('/')
  const shouldScroll = pathParts.includes('internal-transactions') ||
  pathParts.includes('token-transfers') ||
  pathParts.includes('logs') ||
  pathParts.includes('token-transfers') ||
  pathParts.includes('raw-trace') ||
  pathParts.includes('state')
  if (shouldScroll) {
    const txTabsObj = document.getElementById('transaction-tabs')
    txTabsObj && txTabsObj.scrollIntoView()
  }

  const blocksChannel = socket.channel('blocks:new_block', {})
  blocksChannel.join()
  blocksChannel.on('new_block', (msg) => store.dispatch({
    type: 'RECEIVED_NEW_BLOCK',
    msg: humps.camelizeKeys(msg)
  }))

  $('.js-cancel-transaction').on('click', (event) => {
    const btn = $(event.target)
    // @ts-ignore
    if (!window.ethereum) {
      btn
        .attr('data-original-title', `Please unlock ${btn.data('from')} account in Metamask`)
        .tooltip('show')

      setTimeout(() => {
        btn
          .attr('data-original-title', null)
          .tooltip('dispose')
      }, 3000)
      return
    }
    // @ts-ignore
    const { chainId: walletChainIdHex } = window.ethereum
    compareChainIDs(btn.data('chainId'), walletChainIdHex)
      .then(() => {
        const txParams = {
          from: btn.data('from'),
          to: btn.data('from'),
          value: 0,
          nonce: btn.data('nonce').toString()
        }
        // @ts-ignore
        window.ethereum.request({
          method: 'eth_sendTransaction',
          params: [txParams]
        })
          .then(function (txHash) {
            const successMsg = `<a href="${commonPath}/tx/${txHash}">Canceling transaction</a> successfully sent to the network. The current one will change the status once canceling transaction will be confirmed.`
            Swal.fire({
              title: 'Success',
              html: successMsg,
              icon: 'success'
            })
              .then(() => {
                window.location.reload()
              })
          })
          .catch(_error => {
            btn
              .attr('data-original-title', `Please unlock ${btn.data('from')} account in Metamask`)
              .tooltip('show')

            setTimeout(() => {
              btn
                .attr('data-original-title', null)
                .tooltip('dispose')
            }, 3000)
          })
      })
      .catch((error) => {
        Swal.fire({
          title: 'Warning',
          html: formatError(error),
          icon: 'warning'
        })
      })
  })
}

$(function () {
  const $collapseButton = $('[button-collapse-input]')
  const $expandButton = $('[button-expand-input]')

  $collapseButton.on('click', event => {
    const $button = event.target
    const $parent = $button.parentElement
    const $collapseButton = $parent && $parent.querySelector('[button-collapse-input]')
    const $expandButton = $parent && $parent.querySelector('[button-expand-input]')
    const $hiddenText = $parent && $parent.querySelector('[data-hidden-text]')
    const $placeHolder = $parent && $parent.querySelector('[data-placeholder-dots]')
    $collapseButton && $collapseButton.classList.add('d-none')
    $expandButton && $expandButton.classList.remove('d-none')
    $hiddenText && $hiddenText.classList.add('d-none')
    $placeHolder && $placeHolder.classList.remove('d-none')
  })

  $expandButton.on('click', event => {
    const $button = event.target
    const $parent = $button.parentElement
    const $collapseButton = $parent && $parent.querySelector('[button-collapse-input]')
    const $expandButton = $parent && $parent.querySelector('[button-expand-input]')
    const $hiddenText = $parent && $parent.querySelector('[data-hidden-text]')
    const $placeHolder = $parent && $parent.querySelector('[data-placeholder-dots]')
    $expandButton && $expandButton.classList.add('d-none')
    $collapseButton && $collapseButton.classList.remove('d-none')
    $hiddenText && $hiddenText.classList.remove('d-none')
    $placeHolder && $placeHolder.classList.add('d-none')
  })
})
