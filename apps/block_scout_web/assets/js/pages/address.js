import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import { batchChannel } from '../lib/utils'
import { withInfiniteScroll, connectInfiniteScroll } from '../lib/infinite_scroll_helpers'
import listMorph from '../lib/list_morph'
import { updateAllCalculatedUsdValues } from '../lib/currency.js'
import { loadTokenBalanceDropdown } from '../lib/token_balance_dropdown'

const BATCH_THRESHOLD = 10

export const initialState = {
  channelDisconnected: false,

  addressHash: null,
  filter: null,

  balance: null,
  transactionCount: null,
  validationCount: null,

  transactions: [],
  internalTransactions: [],
  internalTransactionsBatch: [],
  validatedBlocks: [],

  beyondPageOne: null,

  nextPageUrl: $('[data-selector="transactions-list"]').length ? URI(window.location).addQuery({ type: 'JSON' }).toString() : null
}

export const reducer = withInfiniteScroll(baseReducer)

function baseReducer (state = initialState, action) {
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
    case 'RECEIVED_NEW_TRANSACTION': {
      if (state.channelDisconnected) return state

      const transactionCount = (action.msg.fromAddressHash === state.addressHash) ? state.transactionCount + 1 : state.transactionCount

      if (state.beyondPageOne ||
        (state.filter === 'to' && action.msg.toAddressHash !== state.addressHash) ||
        (state.filter === 'from' && action.msg.fromAddressHash !== state.addressHash)) {
        return Object.assign({}, state, { transactionCount })
      }

      return Object.assign({}, state, {
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
    case 'RECEIVED_NEXT_PAGE': {
      return Object.assign({}, state, {
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
      return { validationCount: numeral($el.text()).value() }
    },
    render ($el, state, oldState) {
      if (oldState.validationCount === state.validationCount) return
      $el.empty().append(numeral(state.validationCount).format())
    }
  },
  '[data-selector="empty-transactions-list"]': {
    render ($el, state) {
      if (state.transactions.length || state.loadingNextPage || state.pagingError) {
        $el.hide()
      } else {
        $el.show()
      }
    }
  },
  '[data-selector="transactions-list"]': {
    load ($el) {
      return {
        transactions: $el.children().map((index, el) => ({
          transactionHash: el.dataset.transactionHash,
          transactionHtml: el.outerHTML
        })).toArray()
      }
    },
    render ($el, state, oldState) {
      if (oldState.transactions === state.transactions) return

      const container = $el[0]
      const newElements = _.map(state.transactions, ({ transactionHtml }) => $(transactionHtml)[0])
      return listMorph(container, newElements, { key: 'dataset.transactionHash' })
    }
  },
  '[data-selector="internal-transactions-list"]': {
    load ($el) {
      return {
        internalTransactions: $el.children().map((index, el) => ({
          internalTransactionHtml: el.outerHTML
        })).toArray()
      }
    },
    render ($el, state, oldState) {
      if (oldState.internalTransactions === state.internalTransactions) return
      const container = $el[0]
      const newElements = _.map(state.internalTransactions, ({ internalTransactionHtml }) => $(internalTransactionHtml)[0])
      listMorph(container, newElements, { key: 'dataset.key' })
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
  $('[data-selector="transactions-list"]').length && connectInfiniteScroll(store)

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
  addressChannel.on('transaction', (msg) => {
    store.dispatch({
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: humps.camelizeKeys(msg)
    })
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
}
