import $ from 'jquery'
import _ from 'lodash'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { updateAllAges } from '../lib/from_now'
import { exchangeRateChannel, formatUsdValue } from '../lib/currency'
import { batchChannel, buildFullBlockList, initRedux, skippedBlockListBuilder, slideDownPrepend } from '../utils'
import { createMarketHistoryChart } from '../lib/market_history_chart'

const BATCH_THRESHOLD = 10

export const initialState = {
  addressCount: null,
  availableSupply: null,
  averageBlockTime: null,
  batchCountAccumulator: 0,
  blockNumbers: [],
  marketHistoryData: null,
  newBlock: null,
  newTransactions: [],
  replaceBlock: null,
  skippedBlockNumbers: [],
  transactionCount: null,
  usdMarketCap: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      const fullBlockNumberList = buildFullBlockList(action.blockNumbers)
      const fullSkippedBlockNumberList = _.difference(fullBlockNumberList, action.blockNumbers)
      const blockNumbers = fullBlockNumberList.slice(0, 4)
      return Object.assign({}, state, {
        blockNumbers,
        transactionCount: numeral(action.transactionCount).value(),
        skippedBlockNumbers: _.intersection(fullSkippedBlockNumberList, blockNumbers)
      })
    }
    case 'RECEIVED_NEW_ADDRESS_COUNT': {
      return Object.assign({}, state, {
        addressCount: action.msg.count
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      const blockNumber = parseInt(action.msg.blockNumber)
      if (_.includes(state.blockNumbers, blockNumber)) {
        return Object.assign({}, state, {
          averageBlockTime: action.msg.averageBlockTime,
          newBlock: action.msg.chainBlockHtml,
          replaceBlock: blockNumber,
          skippedBlockNumbers: _.without(state.skippedBlockNumbers, blockNumber)
        })
      } else if (blockNumber < _.last(state.blockNumbers)) {
        return Object.assign({}, state, { newBlock: null })
      } else {
        let skippedBlockNumbers = state.skippedBlockNumbers.slice(0)
        if (blockNumber > state.blockNumbers[0] + 1) {
          let oldestBlock = state.blockNumbers[0]
          if (blockNumber - oldestBlock >= 3) {
            skippedBlockNumbers = []
            if (blockNumber - oldestBlock > 3) oldestBlock = blockNumber - 4
          }
          skippedBlockListBuilder(skippedBlockNumbers, blockNumber, oldestBlock)
        }
        const newBlockNumbers = _.chain([blockNumber])
          .union(skippedBlockNumbers, state.blockNumbers)
          .orderBy([], ['desc'])
          .slice(0, 4)
          .value()
        const newSkippedBlockNumbers = _.intersection(skippedBlockNumbers, newBlockNumbers)
        return Object.assign({}, state, {
          averageBlockTime: action.msg.averageBlockTime,
          blockNumbers: newBlockNumbers,
          newBlock: action.msg.chainBlockHtml,
          replaceBlock: null,
          skippedBlockNumbers: newSkippedBlockNumbers
        })
      }
    }
    case 'RECEIVED_NEW_EXCHANGE_RATE': {
      return Object.assign({}, state, {
        availableSupply: action.msg.exchangeRate.availableSupply,
        marketHistoryData: action.msg.marketHistoryData,
        usdMarketCap: action.msg.exchangeRate.marketCapUsd
      })
    }
    case 'RECEIVED_NEW_TRANSACTION_BATCH': {
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

let chart
const $chainDetailsPage = $('[data-page="chain-details"]')
if ($chainDetailsPage.length) {
  initRedux(reducer, {
    main (store) {
      const addressesChannel = socket.channel(`addresses:new_address`)
      addressesChannel.join()
      addressesChannel.on('count', msg => store.dispatch({ type: 'RECEIVED_NEW_ADDRESS_COUNT', msg: humps.camelizeKeys(msg) }))

      const blocksChannel = socket.channel(`blocks:new_block`)
      store.dispatch({
        type: 'PAGE_LOAD',
        blockNumbers: $('[data-selector="block-number"]').map((index, el) => parseInt(el.innerText)).toArray(),
        transactionCount: $('[data-selector="transaction-count"]').text()
      })
      blocksChannel.join()
      blocksChannel.on('new_block', msg => store.dispatch({ type: 'RECEIVED_NEW_BLOCK', msg: humps.camelizeKeys(msg) }))

      exchangeRateChannel.on('new_rate', (msg) => store.dispatch({ type: 'RECEIVED_NEW_EXCHANGE_RATE', msg: humps.camelizeKeys(msg) }))

      const transactionsChannel = socket.channel(`transactions:new_transaction`)
      transactionsChannel.join()
      transactionsChannel.on('transaction', batchChannel((msgs) =>
        store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION_BATCH', msgs: humps.camelizeKeys(msgs) }))
      )

      chart = createMarketHistoryChart($('[data-chart="marketHistoryChart"]')[0])
    },
    render (state, oldState) {
      const $addressCount = $('[data-selector="address-count"]')
      const $averageBlockTime = $('[data-selector="average-block-time"]')
      const $blockList = $('[data-selector="chain-block-list"]')
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      const $channelBatchingCount = $('[data-selector="channel-batching-count"]')
      const $marketCap = $('[data-selector="market-cap"]')
      const $transactionsList = $('[data-selector="transactions-list"]')
      const $transactionCount = $('[data-selector="transaction-count"]')
      const newTransactions = _.difference(state.newTransactions, oldState.newTransactions)
      const skippedBlockNumbers = _.difference(state.skippedBlockNumbers, oldState.skippedBlockNumbers)

      if (oldState.addressCount !== state.addressCount) {
        $addressCount.empty().append(state.addressCount)
      }
      if (oldState.averageBlockTime !== state.averageBlockTime) {
        $averageBlockTime.empty().append(state.averageBlockTime)
      }
      if (oldState.usdMarketCap !== state.usdMarketCap) {
        $marketCap.empty().append(formatUsdValue(state.usdMarketCap))
      }
      if ((state.newBlock && oldState.newBlock !== state.newBlock) || skippedBlockNumbers.length) {
        if (state.replaceBlock && oldState.replaceBlock !== state.replaceBlock) {
          const $replaceBlock = $(`[data-block-number="${state.replaceBlock}"]`)
          $replaceBlock.addClass('shrink-out')
          setTimeout(() => $replaceBlock.replaceWith(state.newBlock), 400)
        } else {
          if (state.newBlock) {
            $blockList.children().last().remove()
            $blockList.prepend(newBlockHtml(state.newBlock))
          }
          if (skippedBlockNumbers.length) {
            const newSkippedBlockNumbers = _.intersection(skippedBlockNumbers, state.blockNumbers)
            _.each(newSkippedBlockNumbers, (skippedBlockNumber) => {
              $blockList.children().last().remove()
              $(`[data-block-number="${skippedBlockNumber + 1}"]`).parent().after(placeHolderBlock(skippedBlockNumber))
            })
          }
        }
        updateAllAges()
      }
      if (oldState.transactionCount !== state.transactionCount) $transactionCount.empty().append(numeral(state.transactionCount).format())
      if (state.batchCountAccumulator) {
        $channelBatching.show()
        $channelBatchingCount[0].innerHTML = numeral(state.batchCountAccumulator).format()
      } else {
        $channelBatching.hide()
      }
      if (newTransactions.length) {
        const newTransactionsToInsert = state.newTransactions.slice(oldState.newTransactions.length)
        $transactionsList
          .children()
          .slice($transactionsList.children().length - newTransactionsToInsert.length, $transactionsList.children().length)
          .remove()
        slideDownPrepend($transactionsList, newTransactionsToInsert.reverse().join(''))

        updateAllAges()
      }
      if (oldState.availableSupply !== state.availableSupply || oldState.marketHistoryData !== state.marketHistoryData) {
        chart.update(state.availableSupply, state.marketHistoryData)
      }
    }
  })
}

function newBlockHtml (blockHtml) {
  return `
    <div class="col-lg-3 fade-up-blocks-chain">
      ${blockHtml}
    </div>
  `
}

function placeHolderBlock (blockNumber) {
  return `
    <div
      class="col-lg-3 fade-up-blocks-chain"
      style="min-height: 100px;"
    >
      <div
        class="tile tile-type-block d-flex align-items-center fade-up"
        style="height: 100px;"
        data-selector="place-holder"
        data-block-number="${blockNumber}"
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
