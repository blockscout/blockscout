import $ from 'jquery'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import { initRedux } from '../utils'

export const initialState = {
  blockNumber: null,
  confirmations: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      return Object.assign({}, state, {
        blockNumber: parseInt(action.blockNumber, 10)
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      if ((action.msg.blockNumber - state.blockNumber) > state.confirmations) {
        return Object.assign({}, state, {
          confirmations: action.msg.blockNumber - state.blockNumber
        })
      } else return state
    }
    default:
      return state
  }
}

const $transactionDetailsPage = $('[data-page="transaction-details"]')
if ($transactionDetailsPage.length) {
  initRedux(reducer, {
    main (store) {
      const blocksChannel = socket.channel(`blocks:new_block`, {})
      const $transactionBlockNumber = $('[data-selector="block-number"]')
      store.dispatch({
        type: 'PAGE_LOAD',
        blockNumber: $transactionBlockNumber.text()
      })
      blocksChannel.join()
      blocksChannel.on('new_block', (msg) => store.dispatch({ type: 'RECEIVED_NEW_BLOCK', msg: humps.camelizeKeys(msg) }))

      const transactionHash = $transactionDetailsPage[0].dataset.pageTransactionHash
      const transactionChannel = socket.channel(`transactions:${transactionHash}`, {})
      transactionChannel.join()
      transactionChannel.on('collated', () => window.location.reload())
    },
    render (state, oldState) {
      const $blockConfirmations = $('[data-selector="block-confirmations"]')

      if (oldState.confirmations !== state.confirmations) {
        $blockConfirmations.empty().append(numeral(state.confirmations).format())
      }
    }
  })
}
