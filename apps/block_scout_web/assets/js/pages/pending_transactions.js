import $ from 'jquery'
import omit from 'lodash/omit'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { connectElements } from '../lib/redux_helpers.js'
import { batchChannel } from '../lib/utils'
import { createAsyncLoadStore } from '../lib/async_listing_load'
import '../app'

const BATCH_THRESHOLD = 10

export const initialState = {
  channelDisconnected: false,

  pendingTransactionCount: null,

  pendingTransactionsBatch: []
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, {
        channelDisconnected: true
      })
    }
    case 'RECEIVED_NEW_TRANSACTION': {
      if (state.channelDisconnected) return state
      return Object.assign({}, state, {
        items: state.items.map((item) => item.includes(action.msg.transactionHash) ? action.msg.transactionHtml : item),
        pendingTransactionsBatch: state.pendingTransactionsBatch.filter(transactionHtml => !transactionHtml.includes(action.msg.transactionHash)),
        pendingTransactionCount: state.pendingTransactionCount - 1
      })
    }
    case 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH': {
      if (state.channelDisconnected) return state

      const pendingTransactionCount = state.pendingTransactionCount + action.msgs.length
      const pendingTransactionHtml = action.msgs.map(message => message.transactionHtml)

      if (!state.pendingTransactionsBatch.length && action.msgs.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          items: [
            ...pendingTransactionHtml.reverse(),
            ...state.items
          ],
          pendingTransactionCount
        })
      } else {
        return Object.assign({}, state, {
          pendingTransactionsBatch: [
            ...pendingTransactionHtml.reverse(),
            ...state.pendingTransactionsBatch
          ],
          pendingTransactionCount
        })
      }
    }
    case 'REMOVE_PENDING_TRANSACTION': {
      return Object.assign({}, state, {
        items: state.items.filter(transactionHtml => !transactionHtml.includes(action.msg.transactionHash))
      })
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
    render ($el, state, oldState) {
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      if (state.pendingTransactionsBatch.length) {
        $channelBatching.show()
        $el[0].innerHTML = numeral(state.pendingTransactionsBatch.length).format()
      } else {
        $channelBatching.hide()
      }
    }
  },
  '[data-selector="transaction-pending-count"]': {
    load ($el) {
      return { pendingTransactionCount: numeral($el.text()).value() }
    },
    render ($el, state, oldState) {
      if (oldState.transactionCount === state.transactionCount) return
      $el.empty().append(numeral(state.transactionCount).format())
    }
  }
}

const $transactionPendingListPage = $('[data-page="transaction-pending-list"]')
if ($transactionPendingListPage.length) {
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
  transactionsChannel.on('transaction', (msg) => {
    store.dispatch({
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: humps.camelizeKeys(msg)
    })
    setTimeout(() => store.dispatch({
      type: 'REMOVE_PENDING_TRANSACTION',
      msg: humps.camelizeKeys(msg)
    }), 1000)
  })

  const pendingTransactionsChannel = socket.channel('transactions:new_pending_transaction')
  pendingTransactionsChannel.join()
  pendingTransactionsChannel.onError(() => store.dispatch({
    type: 'CHANNEL_DISCONNECTED'
  }))
  pendingTransactionsChannel.on('pending_transaction', batchChannel((msgs) => store.dispatch({
    type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH',
    msgs: humps.camelizeKeys(msgs)
  })))
}
