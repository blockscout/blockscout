import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { createStore, connectElements, batchChannel, listMorph, atBottom } from '../utils'
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

  loadingNextPage: false,
  nextPage: null,

  beyondPageOne: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, _.omit(action, 'type'))
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
    case 'LOADING_NEXT_PAGE': {
      return Object.assign({}, state, {
        loadingNextPage: true
      })
    }
    case 'RECEIVED_NEXT_TRANSACTIONS_PAGE': {
      return Object.assign({}, state, {
        loadingNextPage: false,
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

const elements = {
  '[data-selector="channel-disconnected-message"]': {
    render ($el, state) {
      if (state.channelDisconnected) $el.show()
    }
  },
  '[data-selector="balance-card"]': {
    load ($el) {
      return { balance: $el.html() }
    },
    render ($el, state, oldState) {
      if (oldState.balance === state.balance) return
      $el.empty().append(state.balance)
      loadTokenBalanceDropdown()
      updateAllCalculatedUsdValues()
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
  '[data-selector="validation-count"]': {
    load ($el) {
      return { validationCount: numeral($el.text()).value }
    },
    render ($el, state, oldState) {
      if (oldState.validationCount === state.validationCount) return
      $el.empty().append(numeral(state.validationCount).format())
    }
  },
  '[data-selector="loading-next-page"]': {
    render ($el, state) {
      if (state.loadingNextPage) {
        $el.show()
      } else {
        $el.hide()
      }
    }
  },
  '[data-selector="pending-transactions-list"]': {
    load ($el) {
      return {
        pendingTransactions: $el.children().map((index, el) => ({
          transactionHash: el.dataset.transactionHash,
          transactionHtml: el.outerHTML
        })).toArray()
      }
    },
    render ($el, state, oldState) {
      if (oldState.pendingTransactions === state.pendingTransactions) return
      const container = $el[0]
      const newElements = _.map(state.pendingTransactions, ({ transactionHtml }) => $(transactionHtml)[0])
      listMorph(container, newElements, { key: 'dataset.transactionHash' })
    }
  },
  '[data-selector="pending-transactions-count"]': {
    render ($el, state, oldState) {
      if (oldState.pendingTransactions === state.pendingTransactions) return
      $el[0].innerHTML = numeral(state.pendingTransactions.filter(({ validated }) => !validated).length).format()
    }
  },
  '[data-selector="transactions-list"]': {
    load ($el, store) {
      return {
        transactions: $el.children().map((index, el) => ({
          transactionHash: el.dataset.transactionHash,
          transactionHtml: el.outerHTML
        })).toArray()
      }
    },
    render ($el, state, oldState) {
      if (oldState.transactions === state.transactions) return
      function updateTransactions () {
        const container = $el[0]
        const newElements = _.map(state.transactions, ({ transactionHtml }) => $(transactionHtml)[0])
        listMorph(container, newElements, { key: 'dataset.transactionHash' })
      }
      if ($('[data-selector="pending-transactions-list"]').is(':visible')) {
        setTimeout(updateTransactions, TRANSACTION_VALIDATED_MOVE_DELAY + 400)
      } else {
        updateTransactions()
      }
    }
  },
  '[data-selector="internal-transactions-list"]': {
    load ($el) {
      return {
        internalTransactions: $el.children().map((index, el) => ({
          internalTransactionId: el.dataset.internalTransactionId,
          internalTransactionHtml: el.outerHTML
        })).toArray()
      }
    },
    render ($el, state, oldState) {
      if (oldState.internalTransactions === state.internalTransactions) return
      const container = $el[0]
      const newElements = _.map(state.internalTransactions, ({ internalTransactionHtml }) => $(internalTransactionHtml)[0])
      listMorph(container, newElements, { key: 'dataset.internalTransactionId' })
    }
  },
  '[data-selector="channel-batching-count"]': {
    render ($el, state, oldState) {
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      if (!state.internalTransactionsBatch.length) return $channelBatching.hide()
      $channelBatching.show()
      $el[0].innerHTML = numeral(state.internalTransactionsBatch.length).format()
    }
  },
  '[data-selector="validations-list"]': {
    load ($el) {
      return {
        validatedBlocks: $el.children().map((index, el) => ({
          blockNumber: parseInt(el.dataset.blockNumber),
          blockHtml: el.outerHTML
        })).toArray()
      }
    },
    render ($el, state, oldState) {
      if (oldState.validatedBlocks === state.validatedBlocks) return
      const container = $el[0]
      const newElements = _.map(state.validatedBlocks, ({ blockHtml }) => $(blockHtml)[0])
      listMorph(container, newElements, { key: 'dataset.blockNumber' })
    }
  },
  '[data-selector="next-page-button"]': {
    load ($el) {
      return {
        nextPage: `${$el.hide().attr('href')}&type=JSON`
      }
    }
  }
}

const $addressDetailsPage = $('[data-page="address-details"]')
if ($addressDetailsPage.length) {
  const store = createStore(reducer)
  const addressHash = $addressDetailsPage[0].dataset.pageAddressHash
  const { filter, blockNumber } = humps.camelizeKeys(URI(window.location).query(true))
  store.dispatch({
    type: 'PAGE_LOAD',
    addressHash,
    filter,
    beyondPageOne: !!blockNumber
  })
  connectElements({ store, elements })

  const addressChannel = socket.channel(`addresses:${addressHash}`, {})
  addressChannel.join()
  addressChannel.onError(() => store.dispatch({
    type: 'CHANNEL_DISCONNECTED'
  }))
  addressChannel.on('balance', (msg) => store.dispatch({
    type: 'RECEIVED_UPDATED_BALANCE',
    msg: humps.camelizeKeys(msg)
  }))
  addressChannel.on('internal_transaction', batchChannel((msgs) => store.dispatch({
    type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
    msgs: humps.camelizeKeys(msgs)
  })))
  addressChannel.on('pending_transaction', (msg) => store.dispatch({
    type: 'RECEIVED_NEW_PENDING_TRANSACTION',
    msg: humps.camelizeKeys(msg)
  }))
  addressChannel.on('transaction', (msg) => {
    store.dispatch({
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: humps.camelizeKeys(msg)
    })
    setTimeout(() => store.dispatch({
      type: 'REMOVE_PENDING_TRANSACTION',
      msg: humps.camelizeKeys(msg)
    }), TRANSACTION_VALIDATED_MOVE_DELAY)
  })

  const blocksChannel = socket.channel(`blocks:${addressHash}`, {})
  blocksChannel.join()
  blocksChannel.onError(() => store.dispatch({
    type: 'CHANNEL_DISCONNECTED'
  }))
  blocksChannel.on('new_block', (msg) => store.dispatch({
    type: 'RECEIVED_NEW_BLOCK',
    msg: humps.camelizeKeys(msg)
  }))

  $('[data-selector="transactions-list"]').length && atBottom(function loadMoreTransactions () {
    const nextPage = store.getState().nextPage
    if (nextPage) {
      store.dispatch({
        type: 'LOADING_NEXT_PAGE'
      })
      $.get(nextPage).done(msg => {
        store.dispatch({
          type: 'RECEIVED_NEXT_TRANSACTIONS_PAGE',
          msg: humps.camelizeKeys(msg)
        })
      })
    }
  })
}
