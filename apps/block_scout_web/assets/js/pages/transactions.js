import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { updateAllAges } from '../lib/from_now'
import { batchChannel, initRedux, slideDownPrepend } from '../utils'

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
    case 'PAGE_LOAD': {
      return Object.assign({}, state, {
        beyondPageOne: action.beyondPageOne,
        transactionCount: numeral(action.transactionCount).value()
      })
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

const $transactionListPage = $('[data-page="transaction-list"]')
if ($transactionListPage.length) {
  initRedux(reducer, {
    main (store) {
      store.dispatch({
        type: 'PAGE_LOAD',
        transactionCount: $('[data-selector="transaction-count"]').text(),
        beyondPageOne: !!humps.camelizeKeys(URI(window.location).query(true)).index
      })
      const transactionsChannel = socket.channel(`transactions:new_transaction`)
      transactionsChannel.join()
      transactionsChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
      transactionsChannel.on('transaction', batchChannel((msgs) =>
        store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION_BATCH', msgs: humps.camelizeKeys(msgs) }))
      )
    },
    render (state, oldState) {
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      const $channelBatchingCount = $('[data-selector="channel-batching-count"]')
      const $channelDisconnected = $('[data-selector="channel-disconnected-message"]')
      const $transactionsList = $('[data-selector="transactions-list"]')
      const $transactionCount = $('[data-selector="transaction-count"]')

      if (state.channelDisconnected) $channelDisconnected.show()
      if (oldState.transactionCount !== state.transactionCount) $transactionCount.empty().append(numeral(state.transactionCount).format())
      if (state.batchCountAccumulator) {
        $channelBatching.show()
        $channelBatchingCount[0].innerHTML = numeral(state.batchCountAccumulator).format()
      } else {
        $channelBatching.hide()
      }
      if (oldState.newTransactions !== state.newTransactions) {
        const newTransactionsToInsert = state.newTransactions.slice(oldState.newTransactions.length)
        slideDownPrepend($transactionsList, newTransactionsToInsert.reverse().join(''))

        updateAllAges()
      }
    }
  })
}
