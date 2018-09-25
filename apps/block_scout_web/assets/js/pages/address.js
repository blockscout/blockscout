import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { batchChannel, initRedux, prependWithClingBottom } from '../utils'
import { updateAllAges } from '../lib/from_now'
import { updateAllCalculatedUsdValues } from '../lib/currency.js'
import { loadTokenBalanceDropdown } from '../lib/token_balance_dropdown'

const BATCH_THRESHOLD = 10

export const initialState = {
  addressHash: null,
  balance: null,
  batchCountAccumulator: 0,
  batchPendingCountAccumulator: 0,
  beyondPageOne: null,
  channelDisconnected: false,
  filter: null,
  newInternalTransactions: [],
  newPendingTransactions: [],
  newTransactions: [],
  newTransactionHashes: [],
  pendingTransactionHashes: [],
  transactionCount: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      return Object.assign({}, state, {
        addressHash: action.addressHash,
        beyondPageOne: action.beyondPageOne,
        filter: action.filter,
        pendingTransactionHashes: action.pendingTransactionHashes,
        transactionCount: numeral(action.transactionCount).value()
      })
    }
    case 'CHANNEL_DISCONNECTED': {
      if (state.beyondPageOne) return state

      return Object.assign({}, state, {
        channelDisconnected: true,
        batchCountAccumulator: 0
      })
    }
    case 'RECEIVED_UPDATED_BALANCE': {
      return Object.assign({}, state, {
        balance: action.msg.balance
      })
    }
    case 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      const incomingInternalTransactions = humps.camelizeKeys(action.msgs)
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
    case 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      const incomingPendingTransactions = humps.camelizeKeys(action.msgs)
        .filter(({toAddressHash, fromAddressHash}) => (
          !state.filter ||
          (state.filter === 'to' && toAddressHash === state.addressHash) ||
          (state.filter === 'from' && fromAddressHash === state.addressHash)
        ))
      if (!state.batchPendingCountAccumulator && incomingPendingTransactions.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          newPendingTransactions: [
            ...state.newPendingTransactions,
            ..._.map(incomingPendingTransactions, 'transactionHtml')
          ],
          pendingTransactionHashes: [
            ...state.pendingTransactionHashes,
            ..._.map(incomingPendingTransactions, 'transactionHash')
          ]
        })
      } else {
        return Object.assign({}, state, {
          batchPendingCountAccumulator: state.batchPendingCountAccumulator + incomingPendingTransactions.length,
          pendingTransactionHashes: [
            ...state.pendingTransactionHashes,
            ..._.map(incomingPendingTransactions, 'transactionHash')
          ]
        })
      }
    }
    case 'RECEIVED_NEW_TRANSACTION_BATCH': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      const incomingTransactions = humps.camelizeKeys(action.msgs)
        .filter(({toAddressHash, fromAddressHash}) => (
          !state.filter ||
          (state.filter === 'to' && toAddressHash === state.addressHash) ||
          (state.filter === 'from' && fromAddressHash === state.addressHash)
        ))

      const updatePendingTransactionHashes =
        _.difference(state.pendingTransactionHashes, _.map(incomingTransactions, 'transactionHash'))

      if (!state.batchCountAccumulator && incomingTransactions.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          batchPendingCountAccumulator: state.batchPendingCountAccumulator - incomingTransactions.length,
          newTransactions: [
            ...state.newTransactions,
            ..._.map(incomingTransactions, 'transactionHtml')
          ],
          newTransactionHashes: _.map(incomingTransactions, 'transactionHash'),
          pendingTransactionHashes: updatePendingTransactionHashes,
          transactionCount: state.transactionCount + action.msgs.length
        })
      } else {
        return Object.assign({}, state, {
          batchCountAccumulator: state.batchCountAccumulator + incomingTransactions.length,
          batchPendingCountAccumulator: state.batchPendingCountAccumulator - incomingTransactions.length,
          newTransactionHashes: _.map(incomingTransactions, 'transactionHash'),
          pendingTransactionHashes: updatePendingTransactionHashes,
          transactionCount: state.transactionCount + action.msgs.length
        })
      }
    }
    case 'RECEIVED_NEW_BLOCK': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      return Object.assign({}, state, {
        newBlock: action.msg.blockHtml,
        minerHash: action.msg.blockMinerHash
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
      const state = store.dispatch({
        type: 'PAGE_LOAD',
        addressHash,
        beyondPageOne: !!blockNumber,
        filter,
        pendingTransactionHashes:
          $('[data-selector="pending-transactions-list"] [data-transaction-hash]').map((index, el) =>
            el.attributes['data-transaction-hash'].nodeValue
          ).toArray(),
        transactionCount: $('[data-selector="transaction-count"]').text()
      })
      addressChannel.join()
      addressChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
      addressChannel.on('balance', (msg) => store.dispatch({ type: 'RECEIVED_UPDATED_BALANCE', msg }))
      if (!state.beyondPageOne) {
        const blocksChannel = socket.channel(`blocks:new_block`, {})
        blocksChannel.join()
        blocksChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
        blocksChannel.on('new_block', (msg) => {
          store.dispatch({ type: 'RECEIVED_NEW_BLOCK', msg: humps.camelizeKeys(msg) })
        })
        addressChannel.on('transaction', batchChannel((msgs) =>
          store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION_BATCH', msgs })
        ))

        addressChannel.on('internal_transaction', batchChannel((msgs) =>
          store.dispatch({ type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH', msgs })
        ))
        addressChannel.on('pending_transaction', batchChannel((msgs) =>
          store.dispatch({ type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH', msgs })
        ))
        addressChannel.on('transaction', batchChannel((msgs) =>
          store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION_BATCH', msgs })
        ))
      }
    },
    render (state, oldState) {
      const $balance = $('[data-selector="balance-card"]')
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      const $channelBatchingCount = $('[data-selector="channel-batching-count"]')
      const $channelPendingBatching = $('[data-selector="channel-pending-batching-message"]')
      const $channelPendingBatchingCount = $('[data-selector="channel-pending-batching-count"]')
      const $channelDisconnected = $('[data-selector="channel-disconnected-message"]')
      const $emptyInternalTransactionsList = $('[data-selector="empty-internal-transactions-list"]')
      const $emptyTransactionsList = $('[data-selector="empty-transactions-list"]')
      const $internalTransactionsList = $('[data-selector="internal-transactions-list"]')
      const $pendingTransactionsList = $('[data-selector="pending-transactions-list"]')
      const $transactionCount = $('[data-selector="transaction-count"]')
      const $transactionsList = $('[data-selector="transactions-list"]')
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
      if (state.batchCountAccumulator) {
        $channelBatching.show()
        $channelBatchingCount[0].innerHTML = numeral(state.batchCountAccumulator).format()
      } else {
        $channelBatching.hide()
      }
      if (state.batchPendingCountAccumulator > 0) {
        $channelPendingBatching.show()
        $channelPendingBatchingCount[0].innerHTML = numeral(state.batchPendingCountAccumulator).format()
      } else {
        $channelPendingBatching.hide()
      }
      if (oldState.pendingTransactionHashes !== state.pendingTransactionHashes && state.newTransactionHashes.length > 0) {
        let $transaction
        _.each(state.newTransactionHashes, (hash) => {
          $transaction = $(`[data-selector="pending-transactions-list"] [data-transaction-hash="${hash}"]`)
          $transaction.addClass('shrink-out')
          setTimeout(() => $transaction.slideUp({ complete: () => $transaction.remove() }), 400)
        })
      }
      if (oldState.newInternalTransactions !== state.newInternalTransactions && $internalTransactionsList.length) {
        prependWithClingBottom($internalTransactionsList, state.newInternalTransactions.slice(oldState.newInternalTransactions.length).reverse().join(''))
        updateAllAges()
      }
      if (oldState.newPendingTransactions !== state.newPendingTransactions && $pendingTransactionsList.length) {
        prependWithClingBottom($pendingTransactionsList, state.newPendingTransactions.slice(oldState.newPendingTransactions.length).reverse().join(''))
        updateAllAges()
      }
      if (oldState.newTransactions !== state.newTransactions && $transactionsList.length) {
        prependWithClingBottom($transactionsList, state.newTransactions.slice(oldState.newTransactions.length).reverse().join(''))
        updateAllAges()
      }
      if (oldState.newBlock !== state.newBlock && state.minerHash === state.addressHash) {
        const len = $validationsList.children().length
        $validationsList
          .children()
          .slice(len - 1, len)
          .remove()

        $validationsList.prepend(state.newBlock)
      }
    }
  })
}
