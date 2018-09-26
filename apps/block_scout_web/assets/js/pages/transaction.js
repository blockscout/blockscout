import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { updateAllAges } from '../lib/from_now'
import { batchChannel, initRedux, prependWithClingBottom } from '../utils'

const BATCH_THRESHOLD = 10

export const initialState = {
  batchCountAccumulator: 0,
  newPendingTransactionHashesBatch: [],
  beyondPageOne: null,
  blockNumber: null,
  channelDisconnected: false,
  confirmations: null,
  newPendingTransactions: [],
  newTransactions: [],
  newTransactionHashes: [],
  transactionCount: null,
  pendingTransactionCount: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      return Object.assign({}, state, {
        beyondPageOne: action.beyondPageOne,
        blockNumber: parseInt(action.blockNumber, 10),
        transactionCount: numeral(action.transactionCount).value(),
        pendingTransactionCount: numeral(action.pendingTransactionCount).value()
      })
    }
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, {
        channelDisconnected: true,
        batchCountAccumulator: 0
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      if ((action.msg.blockNumber - state.blockNumber) > state.confirmations) {
        return Object.assign({}, state, {
          confirmations: action.msg.blockNumber - state.blockNumber
        })
      } else return state
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
    case 'RECEIVED_NEW_TRANSACTION_BATCH': {
      if (state.channelDisconnected) return state

      const transactionCount = state.transactionCount + action.msgs.length

      if (state.beyondPageOne) return Object.assign({}, state, { transactionCount })

      if (!state.batchCountAccumulator && action.msgs.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          newTransactions: [
            ...state.newTransactions,
            ...action.msgs.map(({transactionHtml}) => transactionHtml)
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

const $transactionDetailsPage = $('[data-page="transaction-details"]')
if ($transactionDetailsPage.length) {
  initRedux(reducer, {
    main (store) {
      const blocksChannel = socket.channel(`blocks:new_block`, {})
      const $transactionBlockNumber = $('[data-selector="block-number"]')
      store.dispatch({
        type: 'PAGE_LOAD',
        blockNumber: $transactionBlockNumber.text()
      })
      blocksChannel.join()
      blocksChannel.on('new_block', (msg) => store.dispatch({ type: 'RECEIVED_NEW_BLOCK', msg: humps.camelizeKeys(msg) }))

      const transactionHash = $transactionDetailsPage[0].dataset.pageTransactionHash
      const transactionChannel = socket.channel(`transactions:${transactionHash}`, {})
      transactionChannel.join()
      transactionChannel.on('collated', () => window.location.reload())
    },
    render (state, oldState) {
      const $blockConfirmations = $('[data-selector="block-confirmations"]')

      if (oldState.confirmations !== state.confirmations) {
        $blockConfirmations.empty().append(numeral(state.confirmations).format())
      }
    }
  })
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
      transactionsChannel.on('new_transaction', (msg) =>
        store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION', msg: humps.camelizeKeys(msg) })
      )
      const pendingTransactionsChannel = socket.channel(`transactions:new_pending_transaction`)
      pendingTransactionsChannel.join()
      pendingTransactionsChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
      pendingTransactionsChannel.on('new_pending_transaction', batchChannel((msgs) =>
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
        setTimeout(() => $transaction.slideUp({
          complete: () => {
            if ($pendingTransactionsList.children().length < 2 && state.pendingTransactionCount > 0) {
              window.location.href = URI(window.location).removeQuery('inserted_at').removeQuery('hash').toString()
            } else {
              $transaction.remove()
            }
          }
        }), 400)
      }
      if (state.newPendingTransactionHashesBatch.length) {
        $channelBatching.show()
        $channelBatchingCount[0].innerHTML = numeral(state.newPendingTransactionHashesBatch.length).format()
      } else {
        $channelBatching.hide()
      }
      if (oldState.newPendingTransactions !== state.newPendingTransactions) {
        const newTransactionsToInsert = state.newPendingTransactions.slice(oldState.newPendingTransactions.length)
        $pendingTransactionsList
          .children()
          .slice($pendingTransactionsList.children().length - newTransactionsToInsert.length,
            $pendingTransactionsList.children().length
          )
          .remove()
        prependWithClingBottom($pendingTransactionsList, newTransactionsToInsert.reverse().join(''))

        updateAllAges()
      }
    }
  })
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
      transactionsChannel.on('new_transaction', batchChannel((msgs) =>
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
        $transactionsList
          .children()
          .slice($transactionsList.children().length - newTransactionsToInsert.length, $transactionsList.children().length)
          .remove()
        prependWithClingBottom($transactionsList, newTransactionsToInsert.reverse().join(''))

        updateAllAges()
      }
    }
  })
}
