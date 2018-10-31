import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { updateAllAges } from '../lib/from_now'
import { createStore, connectElements, batchChannel, slideDownPrepend } from '../utils'

const BATCH_THRESHOLD = 10

export const initialState = {
  batchCountAccumulator: 0,
  beyondPageOne: null,
  channelDisconnected: false,
  newTransactions: [],
  transactionCount: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, _.omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, {
        channelDisconnected: true,
        batchCountAccumulator: 0
      })
    }
    case 'RECEIVED_NEW_TRANSACTION_BATCH': {
      if (state.channelDisconnected) return state

      const transactionCount = state.transactionCount + action.msgs.length

      if (state.beyondPageOne) return Object.assign({}, state, { transactionCount })

      if (!state.batchCountAccumulator && action.msgs.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          newTransactions: [
            ...state.newTransactions,
            ..._.map(action.msgs, 'transactionHtml')
          ],
          transactionCount
        })
      } else {
        return Object.assign({}, state, {
          batchCountAccumulator: state.batchCountAccumulator + action.msgs.length,
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
      if (state.channelDisconnected) $el.show()
    }
  },
  '[data-selector="channel-batching-count"]': {
    render ($el, state, oldState) {
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      if (state.batchCountAccumulator) {
        $channelBatching.show()
        $el[0].innerHTML = numeral(state.batchCountAccumulator).format()
      } else {
        $channelBatching.hide()
      }
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
  },
  '[data-selector="transactions-list"]': {
    render ($el, state, oldState) {
      if (oldState.newTransactions === state.newTransactions) return
      const newTransactionsToInsert = state.newTransactions.slice(oldState.newTransactions.length)
      slideDownPrepend($el, newTransactionsToInsert.reverse().join(''))

      updateAllAges()
    }
  }
}

const $transactionListPage = $('[data-page="transaction-list"]')
if ($transactionListPage.length) {
  const store = createStore(reducer)
  store.dispatch({
    type: 'PAGE_LOAD',
    beyondPageOne: !!humps.camelizeKeys(URI(window.location).query(true)).index
  })
  connectElements({ store, elements })

  const transactionsChannel = socket.channel(`transactions:new_transaction`)
  transactionsChannel.join()
  transactionsChannel.onError(() => store.dispatch({
    type: 'CHANNEL_DISCONNECTED'
  }))
  transactionsChannel.on('transaction', batchChannel((msgs) => store.dispatch({
    type: 'RECEIVED_NEW_TRANSACTION_BATCH',
    msgs: humps.camelizeKeys(msgs)
  })))
}
