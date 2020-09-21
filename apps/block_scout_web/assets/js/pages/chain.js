import $ from 'jquery'
import omit from 'lodash/omit'
import first from 'lodash/first'
import rangeRight from 'lodash/rangeRight'
import find from 'lodash/find'
import map from 'lodash/map'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { updateAllCalculatedUsdValues, formatUsdValue } from '../lib/currency'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import { batchChannel, showLoader } from '../lib/utils'
import listMorph from '../lib/list_morph'
import '../app'

const BATCH_THRESHOLD = 6
const BLOCKS_PER_PAGE = 4

export const initialState = {
  addressCount: null,
  availableSupply: null,
  averageBlockTime: null,
  marketHistoryData: null,
  blocks: [],
  blocksLoading: true,
  blocksError: false,
  transactions: [],
  transactionsBatch: [],
  transactionsError: false,
  transactionsLoading: true,
  transactionCount: null,
  usdMarketCap: null,
  blockCount: null
}

export const reducer = withMissingBlocks(baseReducer)

function baseReducer (state = initialState, action) {
  switch (action.type) {
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'RECEIVED_NEW_ADDRESS_COUNT': {
      return Object.assign({}, state, {
        addressCount: action.msg.count
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      if (!state.blocks.length || state.blocks[0].blockNumber < action.msg.blockNumber) {
        let pastBlocks
        if (state.blocks.length < BLOCKS_PER_PAGE) {
          pastBlocks = state.blocks
        } else {
          pastBlocks = state.blocks.slice(0, -1)
        }
        return Object.assign({}, state, {
          averageBlockTime: action.msg.averageBlockTime,
          blocks: [
            action.msg,
            ...pastBlocks
          ],
          blockCount: action.msg.blockNumber + 1
        })
      } else {
        return Object.assign({}, state, {
          blocks: state.blocks.map((block) => block.blockNumber === action.msg.blockNumber ? action.msg : block),
          blockCount: action.msg.blockNumber + 1
        })
      }
    }
    case 'START_BLOCKS_FETCH': {
      return Object.assign({}, state, { blocksError: false, blocksLoading: true })
    }
    case 'BLOCKS_FINISH_REQUEST': {
      return Object.assign({}, state, { blocksLoading: false })
    }
    case 'BLOCKS_FETCHED': {
      return Object.assign({}, state, { blocks: [...action.msg.blocks], blocksLoading: false })
    }
    case 'BLOCKS_REQUEST_ERROR': {
      return Object.assign({}, state, { blocksError: true, blocksLoading: false })
    }
    case 'RECEIVED_NEW_EXCHANGE_RATE': {
      return Object.assign({}, state, {
        availableSupply: action.msg.exchangeRate.availableSupply,
        marketHistoryData: action.msg.marketHistoryData,
        usdMarketCap: action.msg.exchangeRate.marketCapUsd
      })
    }
    case 'RECEIVED_NEW_TRANSACTION_BATCH': {
      if (state.channelDisconnected) return state

      const transactionCount = state.transactionCount + action.msgs.length

      if (state.transactionsLoading || state.transactionsError) {
        return Object.assign({}, state, { transactionCount })
      }

      const transactionsLength = state.transactions.length + action.msgs.length
      if (transactionsLength < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          transactions: [
            ...action.msgs.reverse(),
            ...state.transactions
          ],
          transactionCount
        })
      } else if (!state.transactionsBatch.length && action.msgs.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          transactions: [
            ...action.msgs.reverse(),
            ...state.transactions.slice(0, -1 * action.msgs.length)
          ],
          transactionCount
        })
      } else {
        return Object.assign({}, state, {
          transactionsBatch: [
            ...action.msgs.reverse(),
            ...state.transactionsBatch
          ],
          transactionCount
        })
      }
    }
    case 'RECEIVED_UPDATED_TRANSACTION_STATS': {
      return Object.assign({}, state, {
        transactionStats: action.msg.stats
      })
    }
    case 'START_TRANSACTIONS_FETCH':
      return Object.assign({}, state, { transactionsError: false, transactionsLoading: true })
    case 'TRANSACTIONS_FETCHED':
      return Object.assign({}, state, { transactions: [...action.msg.transactions] })
    case 'TRANSACTIONS_FETCH_ERROR':
      return Object.assign({}, state, { transactionsError: true })
    case 'FINISH_TRANSACTIONS_FETCH':
      return Object.assign({}, state, { transactionsLoading: false })
    default:
      return state
  }
}

function withMissingBlocks (reducer) {
  return (...args) => {
    const result = reducer(...args)

    if (!result.blocks || result.blocks.length < 2) return result

    const maxBlock = first(result.blocks).blockNumber
    const minBlock = maxBlock - (result.blocks.length - 1)

    return Object.assign({}, result, {
      blocks: rangeRight(minBlock, maxBlock + 1)
        .map((blockNumber) => find(result.blocks, ['blockNumber', blockNumber]) || {
          blockNumber,
          chainBlockHtml: placeHolderBlock(blockNumber)
        })
    })
  }
}

let chart
const elements = {
  '[data-chart="historyChart"]': {
    load () {
      chart = window.dashboardChart
    },
    render ($el, state, oldState) {
      if (!chart || (oldState.availableSupply === state.availableSupply && oldState.marketHistoryData === state.marketHistoryData) || !state.availableSupply) return

      chart.updateMarketHistory(state.availableSupply, state.marketHistoryData)

      if (!chart || (JSON.stringify(oldState.transactionStats) === JSON.stringify(state.transactionStats))) return

      chart.updateTransactionHistory(state.transactionStats)
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
  '[data-selector="block-count"]': {
    load ($el) {
      return { blockCount: numeral($el.text()).value() }
    },
    render ($el, state, oldState) {
      if (oldState.blockCount === state.blockCount) return
      $el.empty().append(numeral(state.blockCount).format())
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
  '[data-selector="tx_per_day"]': {
    render ($el, state, oldState) {
      if (!(JSON.stringify(oldState.transactionStats) === JSON.stringify(state.transactionStats))) {
        $el.empty().append(numeral(state.transactionStats[0].number_of_transactions).format('0,0'))
      }
    }
  },
  '[data-selector="chain-block-list"]': {
    load ($el) {
      return {
        blocksPath: $el[0].dataset.url
      }
    },
    render ($el, state, oldState) {
      if (oldState.blocks === state.blocks) return

      const container = $el[0]

      if (state.blocksLoading === false) {
        const blocks = map(state.blocks, ({ chainBlockHtml }) => $(chainBlockHtml)[0])
        listMorph(container, blocks, { key: 'dataset.blockNumber', horizontal: true })
      }
    }
  },
  '[data-selector="chain-block-list"] [data-selector="error-message"]': {
    render ($el, state, _oldState) {
      if (state.blocksError) {
        $el.show()
      } else {
        $el.hide()
      }
    }
  },
  '[data-selector="chain-block-list"] [data-selector="loading-message"]': {
    render ($el, state, _oldState) {
      showLoader(state.blocksLoading, $el)
    }
  },
  '[data-selector="transactions-list"] [data-selector="error-message"]': {
    render ($el, state, _oldState) {
      $el.toggle(state.transactionsError)
    }
  },
  '[data-selector="transactions-list"] [data-selector="loading-message"]': {
    render ($el, state, _oldState) {
      showLoader(state.transactionsLoading, $el)
    }
  },
  '[data-selector="transactions-list"]': {
    load ($el) {
      return { transactionsPath: $el[0].dataset.transactionsPath }
    },
    render ($el, state, oldState) {
      if (oldState.transactions === state.transactions) return
      const container = $el[0]
      const newElements = map(state.transactions, ({ transactionHtml }) => $(transactionHtml)[0])
      listMorph(container, newElements, { key: 'dataset.identifierHash' })
    }
  },
  '[data-selector="channel-batching-count"]': {
    render ($el, state, _oldState) {
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      if (!state.transactionsBatch.length) return $channelBatching.hide()
      $channelBatching.show()
      $el[0].innerHTML = numeral(state.transactionsBatch.length).format()
    }
  }
}

const $chainDetailsPage = $('[data-page="chain-details"]')
if ($chainDetailsPage.length) {
  const store = createStore(reducer)
  connectElements({ store, elements })

  loadTransactions(store)
  bindTransactionErrorMessage(store)

  loadBlocks(store)
  bindBlockErrorMessage(store)

  const exchangeRateChannel = socket.channel('exchange_rate:new_rate')
  exchangeRateChannel.join()
  exchangeRateChannel.on('new_rate', (msg) => {
    updateAllCalculatedUsdValues(humps.camelizeKeys(msg).exchangeRate.usdValue)
    store.dispatch({
      type: 'RECEIVED_NEW_EXCHANGE_RATE',
      msg: humps.camelizeKeys(msg)
    })
  })

  const addressesChannel = socket.channel('addresses:new_address')
  addressesChannel.join()
  addressesChannel.on('count', msg => store.dispatch({
    type: 'RECEIVED_NEW_ADDRESS_COUNT',
    msg: humps.camelizeKeys(msg)
  }))

  const blocksChannel = socket.channel('blocks:new_block')
  blocksChannel.join()
  blocksChannel.on('new_block', msg => store.dispatch({
    type: 'RECEIVED_NEW_BLOCK',
    msg: humps.camelizeKeys(msg)
  }))

  const transactionsChannel = socket.channel('transactions:new_transaction')
  transactionsChannel.join()
  transactionsChannel.on('transaction', batchChannel((msgs) => store.dispatch({
    type: 'RECEIVED_NEW_TRANSACTION_BATCH',
    msgs: humps.camelizeKeys(msgs)
  })))

  const transactionStatsChannel = socket.channel('transactions:stats')
  transactionStatsChannel.join()
  transactionStatsChannel.on('update', msg => store.dispatch({
    type: 'RECEIVED_UPDATED_TRANSACTION_STATS',
    msg: msg
  }))
}

function loadTransactions (store) {
  const path = store.getState().transactionsPath
  store.dispatch({ type: 'START_TRANSACTIONS_FETCH' })
  $.getJSON(path)
    .done(response => store.dispatch({ type: 'TRANSACTIONS_FETCHED', msg: humps.camelizeKeys(response) }))
    .fail(() => store.dispatch({ type: 'TRANSACTIONS_FETCH_ERROR' }))
    .always(() => store.dispatch({ type: 'FINISH_TRANSACTIONS_FETCH' }))
}

function bindTransactionErrorMessage (store) {
  $('[data-selector="transactions-list"] [data-selector="error-message"]').on('click', _event => loadTransactions(store))
}

export function placeHolderBlock (blockNumber) {
  return `
    <div
      class="col-lg-3 d-flex fade-up-blocks-chain"
      data-block-number="${blockNumber}"
      data-selector="place-holder"
    >
      <div
        class="tile tile-type-block d-flex align-items-center fade-up"
      >
        <span class="loading-spinner-small ml-1 mr-4">
          <span class="loading-spinner-block-1"></span>
          <span class="loading-spinner-block-2"></span>
        </span>
        <div>
          <span class="tile-title pr-0 pl-0">${blockNumber}</span>
          <div class="tile-transactions">${window.localized['Block Processing']}</div>
        </div>
      </div>
    </div>
  `
}

function loadBlocks (store) {
  const url = store.getState().blocksPath

  store.dispatch({ type: 'START_BLOCKS_FETCH' })

  $.getJSON(url)
    .done(response => {
      store.dispatch({ type: 'BLOCKS_FETCHED', msg: humps.camelizeKeys(response) })
    })
    .fail(() => store.dispatch({ type: 'BLOCKS_REQUEST_ERROR' }))
    .always(() => store.dispatch({ type: 'BLOCKS_FINISH_REQUEST' }))
}

function bindBlockErrorMessage (store) {
  $('[data-selector="chain-block-list"] [data-selector="error-message"]').on('click', _event => loadBlocks(store))
}
