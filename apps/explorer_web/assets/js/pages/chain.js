import $ from 'jquery'
import humps from 'humps'
import numeral from 'numeral'
import 'numeral/locales'
import router from '../router'
import socket from '../socket'
import { updateAllAges } from '../lib/from_now'
import { batchChannel, initRedux } from '../utils'

const BATCH_THRESHOLD = 10

export const initialState = {
  addressCount: null,
  averageBlockTime: null,
  batchCountAccumulator: 0,
  newBlock: null,
  newTransactions: [],
  transactionCount: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      return Object.assign({}, state, {
        transactionCount: numeral(action.transactionCount).value()
      })
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

router.when('', { exactPathMatch: true }).then(({ locale }) => initRedux(reducer, {
  main (store) {
    numeral.locale(locale)
    const addressesChannel = socket.channel(`addresses:new_address`)
    addressesChannel.join()
    addressesChannel.on('count', msg => store.dispatch({ type: 'RECEIVED_NEW_ADDRESS_COUNT', msg: humps.camelizeKeys(msg) }))

    const blocksChannel = socket.channel(`blocks:new_block`)
    store.dispatch({
      type: 'PAGE_LOAD',
      transactionCount: $('[data-selector="transaction-count"]').text()
    })
    blocksChannel.join()
    blocksChannel.on('new_block', msg => store.dispatch({ type: 'RECEIVED_NEW_BLOCK', msg: humps.camelizeKeys(msg) }))

    const transactionsChannel = socket.channel(`transactions:new_transaction`)
    transactionsChannel.join()
    transactionsChannel.on('new_transaction', batchChannel((msgs) =>
      store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION_BATCH', msgs: humps.camelizeKeys(msgs) }))
    )
  },
  render (state, oldState) {
    const $addressCount = $('[data-selector="address-count"]')
    const $averageBlockTime = $('[data-selector="average-block-time"]')
    const $blockList = $('[data-selector="chain-block-list"]')
    const $channelBatching = $('[data-selector="channel-batching-message"]')
    const $channelBatchingCount = $('[data-selector="channel-batching-count"]')
    const $transactionsList = $('[data-selector="transactions-list"]')
    const $transactionCount = $('[data-selector="transaction-count"]')

    if (oldState.addressCount !== state.addressCount) {
       $addressCount.empty().append(state.addressCount)
    }
    if (oldState.averageBlockTime !== state.averageBlockTime) {
       $averageBlockTime.empty().append(state.averageBlockTime)
    }
    if (oldState.newBlock !== state.newBlock) {
      $blockList.children().last().remove()
      $blockList.prepend(state.newBlock)
      updateAllAges()
    }
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
      $transactionsList.prepend(newTransactionsToInsert.reverse().join(''))

      updateAllAges()
    }
  }
}))
