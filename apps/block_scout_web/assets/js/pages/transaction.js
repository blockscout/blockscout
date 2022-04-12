import $ from 'jquery'
import omit from 'lodash/omit'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import '../lib/transaction_input_dropdown'
import '../lib/async_listing_load'
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
    case 'RECEIVED_NEW_BLOCK': {
      if ((action.msg.blockNumber - state.blockNumber) > state.confirmations) {
        return Object.assign({}, state, {
          confirmations: action.msg.blockNumber - state.blockNumber
        })
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
  }
}

const $transactionDetailsPage = $('[data-page="transaction-details"]')
if ($transactionDetailsPage.length) {
  const store = createStore(reducer)
  connectElements({ store, elements })

  const blocksChannel = socket.channel('blocks:new_block', {})
  blocksChannel.join()
  blocksChannel.on('new_block', (msg) => store.dispatch({
    type: 'RECEIVED_NEW_BLOCK',
    msg: humps.camelizeKeys(msg)
  }))

  const transactionHash = $transactionDetailsPage[0].dataset.pageTransactionHash
  const transactionChannel = socket.channel(`transactions:${transactionHash}`, {})
  transactionChannel.join()
  transactionChannel.on('collated', () => window.location.reload())

  $('.js-cancel-transaction').on('click', (event) => {
    const btn = $(event.target)
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
    const { chainId: walletChainIdHex } = window.ethereum
    compareChainIDs(btn.data('chainId'), walletChainIdHex)
      .then(() => {
        const txParams = {
          from: btn.data('from'),
          to: btn.data('from'),
          value: 0,
          nonce: btn.data('nonce').toString()
        }
        window.ethereum.request({
          method: 'eth_sendTransaction',
          params: [txParams]
        })
          .then(function (txHash) {
            const successMsg = `<a href="/tx/${txHash}">Canceling transaction</a> successfully sent to the network. The current one will change the status once canceling transaction will be confirmed.`
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
    const $collapseButton = $parent.querySelector('[button-collapse-input]')
    const $expandButton = $parent.querySelector('[button-expand-input]')
    const $hiddenText = $parent.querySelector('[data-hidden-text]')
    const $placeHolder = $parent.querySelector('[data-placeholder-dots]')
    $collapseButton.classList.add('d-none')
    $expandButton.classList.remove('d-none')
    $hiddenText.classList.add('d-none')
    $placeHolder.classList.remove('d-none')
  })

  $expandButton.on('click', event => {
    const $button = event.target
    const $parent = $button.parentElement
    const $collapseButton = $parent.querySelector('[button-collapse-input]')
    const $expandButton = $parent.querySelector('[button-expand-input]')
    const $hiddenText = $parent.querySelector('[data-hidden-text]')
    const $placeHolder = $parent.querySelector('[data-placeholder-dots]')
    $expandButton.classList.add('d-none')
    $collapseButton.classList.remove('d-none')
    $hiddenText.classList.remove('d-none')
    $placeHolder.classList.add('d-none')
  })
})
