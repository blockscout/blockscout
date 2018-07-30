import $ from 'jquery'
import humps from 'humps'
import router from '../router'
import socket from '../socket'
import { updateAllAges } from '../lib/from_now'
import { batchChannel, initRedux } from '../utils'

const BATCH_THRESHOLD = 10

export const initialState = {
  batchCountAccumulator: 0,
  channelDisconnected: false,
  newBlock: null,
  newTransactions: []
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'RECEIVED_NEW_BLOCK': {
      return Object.assign({}, state, {
        newBlock: humps.camelizeKeys(action.msg).homepageBlockHtml
      })
    }
    case 'RECEIVED_NEW_TRANSACTION_BATCH': {
      if (!state.batchCountAccumulator && action.msgs.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          newTransactions: [
            ...state.newTransactions,
            ...humps.camelizeKeys(action.msgs).map(({homepageTransactionHtml}) => homepageTransactionHtml)
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

router.when('', { exactPathMatch: true }).then(() => initRedux(reducer, {
  main (store) {
    const blocksChannel = socket.channel(`blocks:new_block`)
    blocksChannel.join()
    blocksChannel.on('new_block', msg => store.dispatch({ type: 'RECEIVED_NEW_BLOCK', msg }))

    const transactionsChannel = socket.channel(`transactions:new_transaction`)
    transactionsChannel.join()
    transactionsChannel.on('new_transaction', batchChannel((msgs) =>
      store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION_BATCH', msgs }))
    )
  },
  render (state, oldState) {
    const $blockList = $('[data-selector="chain-block-list"]')
    const $transactionsList = $('[data-selector="transactions-list"]')

    if (oldState.newBlock !== state.newBlock) {
      $blockList.children().last().remove()
      $blockList.prepend(state.newBlock)
      updateAllAges()
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
