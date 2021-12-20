import $ from 'jquery'
import omit from 'lodash/omit'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { connectElements } from '../lib/redux_helpers'
import { createAsyncLoadStore } from '../lib/random_access_pagination'
import { batchChannel } from '../lib/utils'
import '../app'

const BATCH_THRESHOLD = 10

export const initialState = {
  channelDisconnected: false,
  transactionCount: null,
  transactionsBatch: []
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, {
        channelDisconnected: true,
        transactionsBatch: []
      })
    }
    case 'RECEIVED_NEW_TRANSACTION_BATCH': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      const transactionCount = state.transactionCount + action.msgs.length

      if (!state.transactionsBatch.length && action.msgs.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          items: [
            ...action.msgs.map(msg => msg.transactionHtml).reverse(),
            ...state.items
          ],
          transactionCount
        })
      } else {
        return Object.assign({}, state, {
          transactionsBatch: [
            ...action.msgs.reverse(),
            ...state.transactionsBatch
          ],
          transactionCount
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
      if (state.channelDisconnected && !window.loading) $el.show()
    }
  },
  '[data-selector="channel-batching-count"]': {
    render ($el, state, _oldState) {
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      if (!state.transactionsBatch.length) return $channelBatching.hide()
      $channelBatching.show()
      $el[0].innerHTML = numeral(state.transactionsBatch.length).format()
    }
  },
  '[data-selector="transaction-count"]': {
    load ($el) {
      return { transactionCount: numeral($el.text()).value() }
    },
    render ($el, state, oldState) {
      if (oldState.transactionCount === state.transactionCount) return
      $el.empty().append(numeral(state.transactionCount).format())
    }
  }
}

const $transactionListPage = $('[data-page="transaction-list"]')
if ($transactionListPage.length) {
  window.onbeforeunload = () => {
    window.loading = true
  }

  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierHash')

  connectElements({ store, elements })

  const transactionsChannel = socket.channel('transactions:new_transaction')
  transactionsChannel.join()
  transactionsChannel.onError(() => store.dispatch({
    type: 'CHANNEL_DISCONNECTED'
  }))
  transactionsChannel.on('transaction', batchChannel((msgs) => {
    if (!store.getState().beyondPageOne) {
      store.dispatch({
        type: 'RECEIVED_NEW_TRANSACTION_BATCH',
        msgs: humps.camelizeKeys(msgs)
      })
    }
  }))
}
