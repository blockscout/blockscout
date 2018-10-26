import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { batchChannel, initRedux, listMorph, atBottom } from '../utils'
import { updateAllCalculatedUsdValues } from '../lib/currency.js'
import { loadTokenBalanceDropdown } from '../lib/token_balance_dropdown'

const BATCH_THRESHOLD = 10
const TRANSACTION_VALIDATED_MOVE_DELAY = 1000

export const initialState = {
  channelDisconnected: false,

  addressHash: null,
  filter: null,

  balance: null,
  transactionCount: null,
  validationCount: null,

  pendingTransactions: [],
  transactions: [],
  internalTransactions: [],
  internalTransactionsBatch: [],
  validatedBlocks: [],

  nextPage: null,

  beyondPageOne: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      return Object.assign({}, state, {
        addressHash: action.addressHash,
        filter: action.filter,

        balance: action.balance,
        transactionCount: numeral(action.transactionCount).value(),
        validationCount: action.validationCount ? numeral(action.validationCount).value() : null,

        pendingTransactions: action.pendingTransactions,
        transactions: action.transactions,
        internalTransactions: action.internalTransactions,
        validatedBlocks: action.validatedBlocks,

        nextPage: action.nextPage,

        beyondPageOne: action.beyondPageOne
      })
    }
    case 'CHANNEL_DISCONNECTED': {
      if (state.beyondPageOne) return state

      return Object.assign({}, state, {
        channelDisconnected: true,
        internalTransactionsBatch: []
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      if (state.channelDisconnected) return state

      const validationCount = state.validationCount + 1

      if (state.beyondPageOne) return Object.assign({}, state, { validationCount })
      return Object.assign({}, state, {
        validatedBlocks: [
          action.msg,
          ...state.validatedBlocks
        ],
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

      if (!state.internalTransactionsBatch.length && incomingInternalTransactions.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          internalTransactions: [
            ...incomingInternalTransactions.reverse(),
            ...state.internalTransactions
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
    case 'RECEIVED_NEW_PENDING_TRANSACTION': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      if ((state.filter === 'to' && action.msg.toAddressHash !== state.addressHash) ||
        (state.filter === 'from' && action.msg.fromAddressHash !== state.addressHash)) {
        return state
      }

      return Object.assign({}, state, {
        pendingTransactions: [
          action.msg,
          ...state.pendingTransactions
        ]
      })
    }
    case 'REMOVE_PENDING_TRANSACTION': {
      if (state.channelDisconnected) return state

      return Object.assign({}, state, {
        pendingTransactions: state.pendingTransactions.filter((transaction) => action.msg.transactionHash !== transaction.transactionHash)
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

      return Object.assign({}, state, {
        pendingTransactions: state.pendingTransactions.map((transaction) => action.msg.transactionHash === transaction.transactionHash ? Object.assign({}, action.msg, { validated: true }) : transaction),
        transactions: [
          action.msg,
          ...state.transactions
        ],
        transactionCount: transactionCount
      })
    }
    case 'RECEIVED_UPDATED_BALANCE': {
      return Object.assign({}, state, {
        balance: action.msg.balance
      })
    }
    case 'NEXT_TRANSACTIONS_PAGE': {
      return Object.assign({}, state, {
        nextPage: action.msg.nextPage,
        transactions: [
          ...state.transactions,
          ...action.msg.transactions
        ]
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
        filter,

        balance: $('[data-selector="balance-card"]').html(),
        transactionCount: $('[data-selector="transaction-count"]').text(),
        validationCount: $('[data-selector="validation-count"]') ? $('[data-selector="validation-count"]').text() : null,

        pendingTransactions: $('[data-selector="pending-transactions-list"]').children().map((index, el) => ({
          transactionHash: el.dataset.transactionHash,
          transactionHtml: el.outerHTML
        })).toArray(),
        transactions: $('[data-selector="transactions-list"]').children().map((index, el) => ({
          transactionHash: el.dataset.transactionHash,
          transactionHtml: el.outerHTML
        })).toArray(),
        internalTransactions: $('[data-selector="internal-transactions-list"]').children().map((index, el) => ({
          internalTransactionId: el.dataset.internalTransactionId,
          internalTransactionHtml: el.outerHTML
        })).toArray(),
        validatedBlocks: $('[data-selector="validations-list"]').children().map((index, el) => ({
          blockNumber: parseInt(el.dataset.blockNumber),
          blockHtml: el.outerHTML
        })).toArray(),

        nextPage: $('[data-selector="next-page-button"]').length ? `${$('[data-selector="next-page-button"]').hide().attr("href")}&type=JSON` : null,

        beyondPageOne: !!blockNumber
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
      addressChannel.on('transaction', (msg) => {
        store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION', msg: humps.camelizeKeys(msg) })
        setTimeout(() => store.dispatch({ type: 'REMOVE_PENDING_TRANSACTION', msg: humps.camelizeKeys(msg) }), TRANSACTION_VALIDATED_MOVE_DELAY)
      })
      const blocksChannel = socket.channel(`blocks:${addressHash}`, {})
      blocksChannel.join()
      blocksChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
      blocksChannel.on('new_block', (msg) => store.dispatch({ type: 'RECEIVED_NEW_BLOCK', msg: humps.camelizeKeys(msg) }))

      $('[data-selector="transactions-list"]').length && atBottom(function loadMoreTransactions() {
        $.get(store.getState().nextPage).done(msg => {
          store.dispatch({ type: 'NEXT_TRANSACTIONS_PAGE', msg: humps.camelizeKeys(msg) })
          setTimeout(() => atBottom(loadMoreTransactions), 1000)
        })
      })
    },
    render (state, oldState) {
      if (state.channelDisconnected) $('[data-selector="channel-disconnected-message"]').show()

      if (oldState.balance !== state.balance) {
        $('[data-selector="balance-card"]').empty().append(state.balance)
        loadTokenBalanceDropdown()
        updateAllCalculatedUsdValues()
      }
      if (oldState.transactionCount !== state.transactionCount) $('[data-selector="transaction-count"]').empty().append(numeral(state.transactionCount).format())
      if (oldState.validationCount !== state.validationCount) $('[data-selector="validation-count"]').empty().append(numeral(state.validationCount).format())

      if (oldState.pendingTransactions !== state.pendingTransactions) {
        const container = $('[data-selector="pending-transactions-list"]')[0]
        const newElements = _.map(state.pendingTransactions, ({ transactionHtml }) => $(transactionHtml)[0])
        listMorph(container, newElements, { key: 'dataset.transactionHash' })
        if($('[data-selector="pending-transactions-count"]').length) $('[data-selector="pending-transactions-count"]')[0].innerHTML = numeral(state.pendingTransactions.filter(({ validated }) => !validated).length).format()
      }
      function updateTransactions () {
        const container = $('[data-selector="transactions-list"]')[0]
        const newElements = _.map(state.transactions, ({ transactionHtml }) => $(transactionHtml)[0])
        listMorph(container, newElements, { key: 'dataset.transactionHash' })
      }
      if (oldState.transactions !== state.transactions) {
        if ($('[data-selector="pending-transactions-list"]').is(':visible')) {
          setTimeout(updateTransactions, TRANSACTION_VALIDATED_MOVE_DELAY + 400)
        } else {
          updateTransactions()
        }
      }
      if (oldState.internalTransactions !== state.internalTransactions) {
        const container = $('[data-selector="internal-transactions-list"]')[0]
        const newElements = _.map(state.internalTransactions, ({ internalTransactionHtml }) => $(internalTransactionHtml)[0])
        listMorph(container, newElements, { key: 'dataset.internalTransactionId' })
      }
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      if (state.internalTransactionsBatch.length) {
        $channelBatching.show()
        $('[data-selector="channel-batching-count"]')[0].innerHTML = numeral(state.internalTransactionsBatch.length).format()
      } else {
        $channelBatching.hide()
      }
      if (oldState.validatedBlocks !== state.validatedBlocks) {
        const container = $('[data-selector="validations-list"]')[0]
        const newElements = _.map(state.validatedBlocks, ({ blockHtml }) => $(blockHtml)[0])
        listMorph(container, newElements, { key: 'dataset.blockNumber' })
      }
    }
  })
}
