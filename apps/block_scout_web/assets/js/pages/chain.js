import $ from 'jquery'
import _ from 'lodash'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { updateAllAges } from '../lib/from_now'
import { exchangeRateChannel, formatUsdValue } from '../lib/currency'
import { createStore, connectElements, slideDownPrepend } from '../utils'
import { createMarketHistoryChart } from '../lib/market_history_chart'

export const initialState = {
  addressCount: null,
  availableSupply: null,
  averageBlockTime: null,
  marketHistoryData: null,
  newBlock: null,
  newTransaction: null,
  transactionCount: null,
  usdMarketCap: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, _.omit(action, 'type'))
    }
    case 'RECEIVED_NEW_ADDRESS_COUNT': {
      return Object.assign({}, state, {
        addressCount: action.msg.count
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      return Object.assign({}, state, {
        averageBlockTime: action.msg.averageBlockTime,
        newBlock: action.msg.chainBlockHtml
      })
    }
    case 'RECEIVED_NEW_EXCHANGE_RATE': {
      return Object.assign({}, state, {
        availableSupply: action.msg.exchangeRate.availableSupply,
        marketHistoryData: action.msg.marketHistoryData,
        usdMarketCap: action.msg.exchangeRate.marketCapUsd
      })
    }
    case 'RECEIVED_NEW_TRANSACTION': {
      return Object.assign({}, state, {
        newTransaction: action.msg.transactionHtml,
        transactionCount: state.transactionCount + 1
      })
    }
    default:
      return state
  }
}

let chart
const elements = {
  '[data-chart="marketHistoryChart"]': {
    load ($el) {
      chart = createMarketHistoryChart($el[0])
    },
    render ($el, state, oldState) {
      if (oldState.availableSupply === state.availableSupply && oldState.marketHistoryData === state.marketHistoryData) return
      chart.update(state.availableSupply, state.marketHistoryData)
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
  '[data-selector="address-count"]': {
    render ($el, state, oldState) {
      if (oldState.addressCount === state.addressCount) return
      $el.empty().append(state.addressCount)
    }
  },
  '[data-selector="average-block-time"]': {
    render ($el, state, oldState) {
      if (oldState.averageBlockTime === state.averageBlockTime) return
      $el.empty().append(state.averageBlockTime)
    }
  },
  '[data-selector="market-cap"]': {
    render ($el, state, oldState) {
      if (oldState.usdMarketCap === state.usdMarketCap) return
      $el.empty().append(formatUsdValue(state.usdMarketCap))
    }
  },
  '[data-selector="chain-block-list"]': {
    render ($el, state, oldState) {
      if (oldState.newBlock === state.newBlock) return
      $el.children().last().remove()
      $el.prepend(newBlockHtml(state.newBlock))
      updateAllAges()
    }
  },
  '[data-selector="transactions-list"]': {
    render ($el, state, oldState) {
      if (oldState.newTransaction === state.newTransaction) return
      $el.children().last().remove()
      slideDownPrepend($el, state.newTransaction)
      updateAllAges()
    }
  }
}

const $chainDetailsPage = $('[data-page="chain-details"]')
if ($chainDetailsPage.length) {
  const store = createStore(reducer)
  connectElements({ store, elements })

  exchangeRateChannel.on('new_rate', (msg) => store.dispatch({
    type: 'RECEIVED_NEW_EXCHANGE_RATE',
    msg: humps.camelizeKeys(msg)
  }))

  const addressesChannel = socket.channel(`addresses:new_address`)
  addressesChannel.join()
  addressesChannel.on('count', msg => store.dispatch({
    type: 'RECEIVED_NEW_ADDRESS_COUNT',
    msg: humps.camelizeKeys(msg)
  }))

  const blocksChannel = socket.channel(`blocks:new_block`)
  blocksChannel.join()
  blocksChannel.on('new_block', msg => store.dispatch({
    type: 'RECEIVED_NEW_BLOCK',
    msg: humps.camelizeKeys(msg)
  }))

  const transactionsChannel = socket.channel(`transactions:new_transaction`)
  transactionsChannel.join()
  transactionsChannel.on('transaction', (msg) => store.dispatch({
    type: 'RECEIVED_NEW_TRANSACTION',
    msg: humps.camelizeKeys(msg)
  }))
}

function newBlockHtml (blockHtml) {
  return `
    <div class="col-lg-3 fade-up-blocks-chain">
      ${blockHtml}
    </div>
  `
}
