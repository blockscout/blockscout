import $ from 'jquery'
import humps from 'humps'
import numeral from 'numeral'
import 'numeral/locales'
import socket from '../socket'
import router from '../router'
import { updateAllAges } from '../lib/from_now'
import { batchChannel, initRedux } from '../utils'

const BATCH_THRESHOLD = 10

export const initialState = {
  batchCountAccumulator: 0,
  beyondPageOne: null,
  blockNumber: null,
  channelDisconnected: false,
  confirmations: null,
  newTransactions: []
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      return Object.assign({}, state, {
        beyondPageOne: !!action.index,
        blockNumber: parseInt(action.blockNumber, 10)
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
      if ((action.msg.blockNumber - state.blockNumber) > state.confirmations) {
        return Object.assign({}, state, {
          confirmations: action.msg.blockNumber - state.blockNumber
        })
      } else return state
    }
    case 'RECEIVED_NEW_TRANSACTION_BATCH': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      if (!state.batchCountAccumulator && action.msgs.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          newTransactions: [
            ...state.newTransactions,
            ...action.msgs.map(({transactionHtml}) => transactionHtml)
          ]
        })
      } else {
        return Object.assign({}, state, {
          batchCountAccumulator: state.batchCountAccumulator + action.msgs.length
        })
      }
    }
    default:
      return state
  }
}

router.when('/transactions/:transactionHash').then(({ locale }) => initRedux(reducer, {
  main (store) {
    const blocksChannel = socket.channel(`blocks:new_block`, {})
    const $transactionBlockNumber = $('[data-selector="block-number"]')
    numeral.locale(locale)
    store.dispatch({ type: 'PAGE_LOAD', blockNumber: $transactionBlockNumber.text() })
    blocksChannel.join()
    blocksChannel.on('new_block', (msg) => store.dispatch({ type: 'RECEIVED_NEW_BLOCK', msg: humps.camelizeKeys(msg) }))
  },
  render (state, oldState) {
    const $blockConfirmations = $('[data-selector="block-confirmations"]')

    if (oldState.confirmations !== state.confirmations) {
      $blockConfirmations.empty().append(numeral(state.confirmations).format())
    }
  }
}))

router.when('/transactions', { exactPathMatch: true }).then((params) => initRedux(reducer, {
  main (store) {
    const { locale, index } = params
    const transactionsChannel = socket.channel(`transactions:new_transaction`)
    numeral.locale(locale)
    store.dispatch({ type: 'PAGE_LOAD', index })
    transactionsChannel.join()
    transactionsChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
    transactionsChannel.on('new_transaction', batchChannel((msgs) =>
      store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION_BATCH', msgs: humps.camelizeKeys(msgs) }))
    )
  },
  render (state, oldState) {
    const $channelBatching = $('[data-selector="channel-batching-message"]')
    const $channelBatchingCount = $('[data-selector="channel-batching-count"]')
    const $channelDisconnected = $('[data-selector="channel-disconnected-message"]')
    const $transactionsList = $('[data-selector="transactions-list"]')

    if (state.channelDisconnected) $channelDisconnected.show()
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
