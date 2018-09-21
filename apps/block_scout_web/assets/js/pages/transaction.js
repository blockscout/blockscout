import $ from 'jquery'
import URI from 'urijs'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { updateAllAges } from '../lib/from_now'
import { batchChannel, initRedux, prependWithClingBottom } from '../utils'

const BATCH_THRESHOLD = 10

export const initialState = {
  batchCountAccumulator: 0,
  beyondPageOne: null,
  blockNumber: null,
  channelDisconnected: false,
  confirmations: null,
  newPendingTransactions: [],
  newTransactions: [],
  pendingTransactionHashes: [],
  transactionCount: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      return Object.assign({}, state, {
        beyondPageOne: action.beyondPageOne,
        blockNumber: parseInt(action.blockNumber, 10),
        pendingTransactionHashes: action.pendingTransactionHashes || [],
        transactionCount: numeral(action.transactionCount).value()
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
      if (state.pendingTransactionHashes.includes(action.msg.transactionHash)) {
        const index = state.pendingTransactionHashes.indexOf(action.msg.transactionHash)
        state.pendingTransactionHashes.splice(index, 1)
        return Object.assign({}, state, {
          pendingTransactionHashes: state.pendingTransactionHashes,
          transactionCount: state.transactionCount - 1,
          newTransactions: [action.msg.transactionHash]
        })
      } else return state
    }
    case 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      if (!state.batchCountAccumulator && action.msgs.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          newPendingTransactions: [
            ...state.newPendingTransactions,
            ...action.msgs.map(({transactionHtml}) => transactionHtml)
          ],
          pendingTransactionHashes: [
            ...state.pendingTransactionHashes,
            ...action.msgs.map(({transactionHash}) => transactionHash)
          ],
          transactionCount: state.transactionCount + action.msgs.length
        })
      } else {
        return Object.assign({}, state, {
          batchCountAccumulator: state.batchCountAccumulator + action.msgs.length,
          transactionCount: state.transactionCount + action.msgs.length
        })
      }
    }
    case 'RECEIVED_NEW_TRANSACTION_BATCH': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      if (!state.batchCountAccumulator && action.msgs.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          newTransactions: [
            ...state.newTransactions,
            ...action.msgs.map(({transactionHtml}) => transactionHtml)
          ],
          transactionCount: state.transactionCount + action.msgs.length
        })
      } else {
        return Object.assign({}, state, {
          batchCountAccumulator: state.batchCountAccumulator + action.msgs.length,
          transactionCount: state.transactionCount + action.msgs.length
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
      const pendingState = store.dispatch({
        type: 'PAGE_LOAD',
        transactionCount: $('[data-selector="transaction-pending-count"]').text(),
        pendingTransactionHashes: $('[data-transaction-hash]').map((index, el) =>
          el.attributes['data-transaction-hash'].nodeValue
        ).toArray(),
        beyondPageOne: !!humps.camelizeKeys(URI(window.location).query(true)).index
      })
      const transactionsChannel = socket.channel(`transactions:new_transaction`)
      transactionsChannel.join()
      transactionsChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
      transactionsChannel.on('new_transaction', (msg) =>
        store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION', msg: humps.camelizeKeys(msg) })
      )
      if (!pendingState.beyondPageOne) {
        const pendingTransactionsChannel = socket.channel(`transactions:new_pending_transaction`)
        pendingTransactionsChannel.join()
        pendingTransactionsChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
        pendingTransactionsChannel.on('new_pending_transaction', batchChannel((msgs) =>
          store.dispatch({ type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH', msgs: humps.camelizeKeys(msgs) }))
        )
      }
    },
    render (state, oldState) {
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      const $channelBatchingCount = $('[data-selector="channel-batching-count"]')
      const $channelDisconnected = $('[data-selector="channel-disconnected-message"]')
      const $pendingTransactionsList = $('[data-selector="transactions-pending-list"]')
      const $pendingTransactionsCount = $('[data-selector="transaction-pending-count"]')

      if (state.channelDisconnected) $channelDisconnected.show()
      if (oldState.transactionCount !== state.transactionCount) {
        $pendingTransactionsCount.empty().append(numeral(state.transactionCount).format())
      }
      if (oldState.pendingTransactionHashes !== state.pendingTransactionHashes && state.newTransactions.length > 0) {
        $('[data-transaction-hash="' + state.newTransactions[0] + '"]').remove()
      }
      if (state.batchCountAccumulator) {
        $channelBatching.show()
        $channelBatchingCount[0].innerHTML = numeral(state.batchCountAccumulator).format()
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
      const state = store.dispatch({
        type: 'PAGE_LOAD',
        transactionCount: $('[data-selector="transaction-count"]').text(),
        beyondPageOne: !!humps.camelizeKeys(URI(window.location).query(true)).index
      })
      if (!state.beyondPageOne) {
        const transactionsChannel = socket.channel(`transactions:new_transaction`)
        transactionsChannel.join()
        transactionsChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
        transactionsChannel.on('new_transaction', batchChannel((msgs) =>
          store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION_BATCH', msgs: humps.camelizeKeys(msgs) }))
        )
      }
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
