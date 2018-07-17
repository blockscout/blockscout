import $ from 'jquery'
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
    case 'RECEIVED_UPDATED_CONFIRMATIONS': {
      if ((action.msg.block_number - state.blockNumber) > state.confirmations) {
        return Object.assign({}, state, {
          confirmations: action.msg.block_number - state.blockNumber
        })
      } else return state
    }
    default:
      return state
  }
}

router.when('/transactions/:transactionHash').then((params) => initRedux(reducer, {
  main (store) {
    const { transactionHash, locale } = params
    const channel = socket.channel(`transactions:confirmations`, {})
    const $transactionBlockNumber = $('[data-selector="block-number"]')
    numeral.locale(locale)
    store.dispatch({ type: 'PAGE_LOAD', blockNumber: $transactionBlockNumber.text() })
    channel.join()
      .receive('ok', resp => { console.log('Joined successfully', `transactions:confirmations`, resp) })
      .receive('error', resp => { console.log('Unable to join', `transactions:confirmations`, resp) })
    channel.on('update', (msg) => store.dispatch({ type: 'RECEIVED_UPDATED_CONFIRMATIONS', msg }))
  },
  render (state, oldState) {
    const $blockConfirmations = $('[data-selector="block-confirmations"]')
    if (oldState.confirmations !== state.confirmations) {
      $blockConfirmations.empty().append(numeral(state.confirmations).format())
    }
  }
}))
