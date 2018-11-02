import $ from 'jquery'
import _ from 'lodash'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { exchangeRateChannel, formatUsdValue } from '../lib/currency'
import { createStore, connectElements, listMorph } from '../utils'
import { createMarketHistoryChart } from '../lib/market_history_chart'

export const initialState = {
  addressCount: null,
  availableSupply: null,
  averageBlockTime: null,
  marketHistoryData: null,
  blocks: null,
  transactions: null,
  transactionCount: null,
  usdMarketCap: null
}

export const reducer = withMissingBlocks(baseReducer)

function baseReducer (state = initialState, action) {
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
        blocks: [
          action.msg,
          ...state.blocks.slice(0, -1)
        ]
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
        transactionCount: state.transactionCount + 1,
        transactions: [
          action.msg,
          ...state.transactions.slice(0, -1)
        ]
      })
    }
    default:
      return state
  }
}

function withMissingBlocks (reducer) {
  return (...args) => {
    const result = reducer(...args)

    if (!result.blocks || result.blocks.length < 2) return result

    const maxBlock = _.first(result.blocks).blockNumber
    const minBlock = maxBlock - (result.blocks.length - 1)

    return Object.assign({}, result, {
      blocks: _.rangeRight(minBlock, maxBlock + 1)
        .map((blockNumber) => _.find(result.blocks, ['blockNumber', blockNumber]) || {
          blockNumber,
          chainBlockHtml: placeHolderBlock(blockNumber)
        })
    })
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
    load ($el) {
      return {
        blocks: $el.children().map((index, el) => ({
          blockNumber: parseInt(el.dataset.blockNumber),
          chainBlockHtml: el.outerHTML
        })).toArray()
      }
    },
    render ($el, state, oldState) {
      if (oldState.blocks === state.blocks) return
      const container = $el[0]
      const newElements = _.map(state.blocks, ({ chainBlockHtml }) => $(chainBlockHtml)[0])
      listMorph(container, newElements, { key: 'dataset.blockNumber', horizontal: true })
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
      listMorph(container, newElements, { key: 'dataset.transactionHash' })
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

function placeHolderBlock (blockNumber) {
  return `
    <div
      class="col-lg-3 fade-up-blocks-chain"
      style="min-height: 100px;"
      data-selector="place-holder"
      data-block-number="${blockNumber}"
    >
      <div
        class="tile tile-type-block d-flex align-items-center fade-up"
        style="height: 100px;"
      >
        <span class="loading-spinner-small ml-1 mr-4">
          <span class="loading-spinner-block-1"></span>
          <span class="loading-spinner-block-2"></span>
        </span>
        <div>
          <div class="tile-title">${blockNumber}</div>
          <div>${window.localized['Block Processing']}</div>
        </div>
      </div>
    </div>
  `
}
