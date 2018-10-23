import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { batchChannel, initRedux, slideDownPrepend, slideUpRemove } from '../utils'
import { updateAllAges } from '../lib/from_now'
import { updateAllCalculatedUsdValues } from '../lib/currency.js'
import { loadTokenBalanceDropdown } from '../lib/token_balance_dropdown'

const BATCH_THRESHOLD = 10

export const initialState = {
  addressHash: null,
  balance: null,
  batchCountAccumulator: 0,
  beyondPageOne: null,
  channelDisconnected: false,
  filter: null,
  newBlock: null,
  newInternalTransactions: [],
  newPendingTransactions: [],
  newTransactions: [],
  pendingTransactionHashes: [],
  transactionCount: null,
  validationCount: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      return Object.assign({}, state, {
        addressHash: action.addressHash,
        beyondPageOne: action.beyondPageOne,
        filter: action.filter,
        pendingTransactionHashes: action.pendingTransactionHashes,
        transactionCount: numeral(action.transactionCount).value(),
        validationCount: action.validationCount ? numeral(action.validationCount).value() : null
      })
    }
    case 'CHANNEL_DISCONNECTED': {
      if (state.beyondPageOne) return state

      return Object.assign({}, state, {
        channelDisconnected: true,
        batchCountAccumulator: 0
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      if (state.channelDisconnected) return state

      const validationCount = state.validationCount + 1

      if (state.beyondPageOne) return Object.assign({}, state, { validationCount })
      return Object.assign({}, state, {
        newBlock: action.msg.blockHtml,
        validationCount
      })
    }
    case 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      const incomingInternalTransactions = action.msgs
        .filter(({toAddressHash, fromAddressHash}) => (
          !state.filter ||
          (state.filter === 'to' && toAddressHash === state.addressHash) ||
          (state.filter === 'from' && fromAddressHash === state.addressHash)
        ))

      if (!state.batchCountAccumulator && incomingInternalTransactions.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          newInternalTransactions: [
            ...state.newInternalTransactions,
            ..._.map(incomingInternalTransactions, 'internalTransactionHtml')
          ]
        })
      } else {
        return Object.assign({}, state, {
          batchCountAccumulator: state.batchCountAccumulator + incomingInternalTransactions.length
        })
      }
    }
    case 'RECEIVED_NEW_PENDING_TRANSACTION': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      if ((state.filter === 'to' && action.msg.toAddressHash !== state.addressHash) ||
        (state.filter === 'from' && action.msg.fromAddressHash !== state.addressHash)) {
        return state
      }

      return Object.assign({}, state, {
        newPendingTransactions: [
          ...state.newPendingTransactions,
          action.msg.transactionHtml
        ],
        pendingTransactionHashes: [
          ...state.pendingTransactionHashes,
          action.msg.transactionHash
        ]
      })
    }
    case 'RECEIVED_NEW_TRANSACTION': {
      if (state.channelDisconnected) return state

      const transactionCount = (action.msg.fromAddressHash === state.addressHash) ? state.transactionCount + 1 : state.transactionCount

      if (state.beyondPageOne ||
        (state.filter === 'to' && action.msg.toAddressHash !== state.addressHash) ||
        (state.filter === 'from' && action.msg.fromAddressHash !== state.addressHash)) {
        return Object.assign({}, state, { transactionCount })
      }

      const updatedPendingTransactionHashes =
        _.without(state.pendingTransactionHashes, action.msg.transactionHash)

      return Object.assign({}, state, {
        newTransactions: [
          ...state.newTransactions,
          action.msg
        ],
        pendingTransactionHashes: updatedPendingTransactionHashes,
        transactionCount: transactionCount
      })
    }
    case 'RECEIVED_UPDATED_BALANCE': {
      return Object.assign({}, state, {
        balance: action.msg.balance
      })
    }
    default:
      return state
  }
}

const $addressDetailsPage = $('[data-page="address-details"]')
if ($addressDetailsPage.length) {
  initRedux(reducer, {
    main (store) {
      const addressHash = $addressDetailsPage[0].dataset.pageAddressHash
      const addressChannel = socket.channel(`addresses:${addressHash}`, {})
      const { filter, blockNumber } = humps.camelizeKeys(URI(window.location).query(true))
      store.dispatch({
        type: 'PAGE_LOAD',
        addressHash,
        beyondPageOne: !!blockNumber,
        filter,
        pendingTransactionHashes: $('[data-selector="pending-transactions-list"]').children()
          .map((index, el) => el.dataset.transactionHash).toArray(),
        transactionCount: $('[data-selector="transaction-count"]').text(),
        validationCount: $('[data-selector="validation-count"]') ? $('[data-selector="validation-count"]').text() : null
      })
      addressChannel.join()
      addressChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
      addressChannel.on('balance', (msg) => {
        store.dispatch({ type: 'RECEIVED_UPDATED_BALANCE', msg: humps.camelizeKeys(msg) })
      })
      addressChannel.on('internal_transaction', batchChannel((msgs) =>
        store.dispatch({ type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH', msgs: humps.camelizeKeys(msgs) })
      ))
      addressChannel.on('pending_transaction', (msg) => store.dispatch({ type: 'RECEIVED_NEW_PENDING_TRANSACTION', msg: humps.camelizeKeys(msg) }))
      addressChannel.on('transaction', (msg) => store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION', msg: humps.camelizeKeys(msg) }))
      const blocksChannel = socket.channel(`blocks:${addressHash}`, {})
      blocksChannel.join()
      blocksChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
      blocksChannel.on('new_block', (msg) => store.dispatch({ type: 'RECEIVED_NEW_BLOCK', msg: humps.camelizeKeys(msg) }))
    },
    render (state, oldState) {
      const $balance = $('[data-selector="balance-card"]')
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      const $channelBatchingCount = $('[data-selector="channel-batching-count"]')
      const $channelDisconnected = $('[data-selector="channel-disconnected-message"]')
      const $emptyInternalTransactionsList = $('[data-selector="empty-internal-transactions-list"]')
      const $emptyTransactionsList = $('[data-selector="empty-transactions-list"]')
      const $internalTransactionsList = $('[data-selector="internal-transactions-list"]')
      const $pendingTransactionsCount = $('[data-selector="pending-transactions-count"]')
      const $pendingTransactionsList = $('[data-selector="pending-transactions-list"]')
      const $transactionCount = $('[data-selector="transaction-count"]')
      const $transactionsList = $('[data-selector="transactions-list"]')
      const $validationCount = $('[data-selector="validation-count"]')
      const $validationsList = $('[data-selector="validations-list"]')

      if ($emptyInternalTransactionsList.length && state.newInternalTransactions.length) window.location.reload()
      if ($emptyTransactionsList.length && state.newTransactions.length) window.location.reload()
      if (state.channelDisconnected) $channelDisconnected.show()
      if (oldState.balance !== state.balance) {
        $balance.empty().append(state.balance)
        loadTokenBalanceDropdown()
        updateAllCalculatedUsdValues()
      }
      if (oldState.transactionCount !== state.transactionCount) $transactionCount.empty().append(numeral(state.transactionCount).format())
      if (oldState.validationCount !== state.validationCount) $validationCount.empty().append(numeral(state.validationCount).format())
      if (state.batchCountAccumulator) {
        $channelBatching.show()
        $channelBatchingCount[0].innerHTML = numeral(state.batchCountAccumulator).format()
      } else {
        $channelBatching.hide()
      }
      if (oldState.newInternalTransactions !== state.newInternalTransactions && $internalTransactionsList.length) {
        slideDownPrepend($internalTransactionsList, state.newInternalTransactions.slice(oldState.newInternalTransactions.length).reverse().join(''))
        updateAllAges()
      }
      if (oldState.pendingTransactionHashes.length !== state.pendingTransactionHashes.length && $pendingTransactionsCount.length) {
        $pendingTransactionsCount[0].innerHTML = numeral(state.pendingTransactionHashes.length).format()
      }
      if (oldState.newPendingTransactions !== state.newPendingTransactions && $pendingTransactionsList.length) {
        slideDownPrepend($pendingTransactionsList, state.newPendingTransactions.slice(oldState.newPendingTransactions.length).reverse().join(''))
        updateAllAges()
      }
      if (oldState.newTransactions !== state.newTransactions && $transactionsList.length) {
        const newlyValidatedTransactions = state.newTransactions.slice(oldState.newTransactions.length).reverse()
        newlyValidatedTransactions.forEach(({ transactionHash, transactionHtml }) => {
          let $transaction = $(`[data-selector="pending-transactions-list"] [data-transaction-hash="${transactionHash}"]`)
          $transaction.html($(transactionHtml).html())
          if ($transaction.is(':visible')) {
            setTimeout(() => {
              $transaction.addClass('shrink-out')
              setTimeout(() => {
                slideUpRemove($transaction)
                slideDownPrepend($transactionsList, transactionHtml)
              }, 400)
            }, 1000)
          } else {
            $transaction.remove()
            slideDownPrepend($transactionsList, transactionHtml)
          }
        })
        updateAllAges()
      }
      if (oldState.newBlock !== state.newBlock) {
        slideDownPrepend($validationsList, state.newBlock)
        updateAllAges()
      }
    }
  })
}
