import $ from 'jquery'
import humps from 'humps'
import numeral from 'numeral'
import 'numeral/locales'
import socket from '../socket'
import router from '../router'
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
