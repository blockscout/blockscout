import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { updateAllAges } from '../lib/from_now'
import { batchChannel, initRedux, slideDownPrepend, slideUpRemove } from '../utils'

const BATCH_THRESHOLD = 10

export const initialState = {
  newPendingTransactionHashesBatch: [],
  beyondPageOne: null,
  channelDisconnected: false,
  newPendingTransactions: [],
  newTransactionHashes: [],
  pendingTransactionCount: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      return Object.assign({}, state, {
        beyondPageOne: action.beyondPageOne,
        pendingTransactionCount: numeral(action.pendingTransactionCount).value()
      })
    }
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, {
        channelDisconnected: true
      })
    }
    case 'RECEIVED_NEW_TRANSACTION': {
      if (state.channelDisconnected) return state

      return Object.assign({}, state, {
        newPendingTransactionHashesBatch: _.without(state.newPendingTransactionHashesBatch, action.msg.transactionHash),
        pendingTransactionCount: state.pendingTransactionCount - 1,
        newTransactionHashes: [action.msg.transactionHash]
      })
    }
    case 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH': {
      if (state.channelDisconnected) return state

      const pendingTransactionCount = state.pendingTransactionCount + action.msgs.length

      if (state.beyondPageOne) return Object.assign({}, state, { pendingTransactionCount })

      if (!state.newPendingTransactionHashesBatch.length && action.msgs.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          newPendingTransactions: [
            ...state.newPendingTransactions,
            ..._.map(action.msgs, 'transactionHtml')
          ],
          pendingTransactionCount
        })
      } else {
        return Object.assign({}, state, {
          newPendingTransactionHashesBatch: [
            ...state.newPendingTransactionHashesBatch,
            ..._.map(action.msgs, 'transactionHash')
          ],
          pendingTransactionCount
        })
      }
    }
    default:
      return state
  }
}

const $transactionPendingListPage = $('[data-page="transaction-pending-list"]')
if ($transactionPendingListPage.length) {
  initRedux(reducer, {
    main (store) {
      store.dispatch({
        type: 'PAGE_LOAD',
        pendingTransactionCount: $('[data-selector="transaction-pending-count"]').text(),
        beyondPageOne: !!humps.camelizeKeys(URI(window.location).query(true)).insertedAt
      })
      const transactionsChannel = socket.channel(`transactions:new_transaction`)
      transactionsChannel.join()
      transactionsChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
      transactionsChannel.on('transaction', (msg) =>
        store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION', msg: humps.camelizeKeys(msg) })
      )
      const pendingTransactionsChannel = socket.channel(`transactions:new_pending_transaction`)
      pendingTransactionsChannel.join()
      pendingTransactionsChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
      pendingTransactionsChannel.on('pending_transaction', batchChannel((msgs) =>
        store.dispatch({ type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH', msgs: humps.camelizeKeys(msgs) }))
      )
    },
    render (state, oldState) {
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      const $channelBatchingCount = $('[data-selector="channel-batching-count"]')
      const $channelDisconnected = $('[data-selector="channel-disconnected-message"]')
      const $pendingTransactionsList = $('[data-selector="transactions-pending-list"]')
      const $pendingTransactionsCount = $('[data-selector="transaction-pending-count"]')

      if (state.channelDisconnected) $channelDisconnected.show()
      if (oldState.pendingTransactionCount !== state.pendingTransactionCount) {
        $pendingTransactionsCount.empty().append(numeral(state.pendingTransactionCount).format())
      }
      if (oldState.newTransactionHashes !== state.newTransactionHashes && state.newTransactionHashes.length > 0) {
        const $transaction = $(`[data-transaction-hash="${state.newTransactionHashes[0]}"]`)
        $transaction.addClass('shrink-out')
        setTimeout(() => {
          if ($transaction.length === 1 && $transaction.siblings().length === 0 && state.pendingTransactionCount > 0) {
            window.location.href = URI(window.location).removeQuery('inserted_at').removeQuery('hash').toString()
          } else {
            slideUpRemove($transaction)
          }
        }, 400)
      }
      if (state.newPendingTransactionHashesBatch.length) {
        $channelBatching.show()
        $channelBatchingCount[0].innerHTML = numeral(state.newPendingTransactionHashesBatch.length).format()
      } else {
        $channelBatching.hide()
      }
      if (oldState.newPendingTransactions !== state.newPendingTransactions) {
        const newTransactionsToInsert = state.newPendingTransactions.slice(oldState.newPendingTransactions.length)
        slideDownPrepend($pendingTransactionsList, newTransactionsToInsert.reverse().join(''))

        updateAllAges()
      }
    }
  })
}
