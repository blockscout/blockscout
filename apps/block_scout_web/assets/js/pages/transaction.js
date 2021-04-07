import $ from 'jquery'
import omit from 'lodash/omit'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import '../lib/transaction_input_dropdown'
import '../lib/async_listing_load'
import '../app'

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

  const pathParts = window.location.pathname.split('/')
  const shouldScroll = pathParts.includes('internal-transactions') ||
  pathParts.includes('token-transfers') ||
  pathParts.includes('logs') ||
  pathParts.includes('token-transfers') ||
  pathParts.includes('raw-trace')
  if (shouldScroll) {
    document.getElementById('transaction-tabs').scrollIntoView()
  }

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
}
