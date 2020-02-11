import $ from 'jquery'
import omit from 'lodash/omit'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../../socket'
import { batchChannel } from '../../lib/utils'
import { connectElements } from '../../lib/redux_helpers.js'
import { createAsyncLoadStore } from '../../lib/async_listing_load'
import '../address'

const BATCH_THRESHOLD = 10

export const initialState = {
  channelDisconnected: false,
  addressHash: null,
  filter: null,
  internalTransactionsBatch: []
}

export function reducer (state, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      if (state.beyondPageOne) return state

      return Object.assign({}, state, {
        channelDisconnected: true,
        internalTransactionsBatch: []
      })
    }
    case 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      const incomingInternalTransactions = action.msgs
        .filter(({ toAddressHash, fromAddressHash }) => (
          !state.filter ||
          (state.filter === 'to' && toAddressHash === state.addressHash) ||
          (state.filter === 'from' && fromAddressHash === state.addressHash)
        )).map(msg => msg.internalTransactionHtml)

      if (!state.internalTransactionsBatch.length && incomingInternalTransactions.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          items: [
            ...incomingInternalTransactions.reverse(),
            ...state.items
          ]
        })
      } else {
        return Object.assign({}, state, {
          internalTransactionsBatch: [
            ...incomingInternalTransactions.reverse(),
            ...state.internalTransactionsBatch
          ]
        })
      }
    }
    default:
      return state
  }
}

const elements = {
  '[data-selector="channel-disconnected-message"]': {
    render ($el, state) {
      if (state.channelDisconnected) $el.show()
    }
  },
  '[data-selector="channel-batching-count"]': {
    render ($el, state, oldState) {
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      if (!state.internalTransactionsBatch.length) return $channelBatching.hide()
      $channelBatching.show()
      $el[0].innerHTML = numeral(state.internalTransactionsBatch.length).format()
    }
  }
}

if ($('[data-page="address-internal-transactions"]').length) {
  const store = createAsyncLoadStore(reducer, initialState, 'dataset.key')
  const addressHash = $('[data-page="address-details"]')[0].dataset.pageAddressHash

  store.dispatch({ type: 'PAGE_LOAD', addressHash })
  connectElements({ store, elements })

  const addressChannel = socket.channel(`addresses:${addressHash}`, {})
  addressChannel.join()
  addressChannel.onError(() => store.dispatch({
    type: 'CHANNEL_DISCONNECTED'
  }))
  addressChannel.on('internal_transaction', batchChannel((msgs) => store.dispatch({
    type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
    msgs: humps.camelizeKeys(msgs)
  })))
}
