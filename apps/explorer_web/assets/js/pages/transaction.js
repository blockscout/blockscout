import $ from 'jquery'
import numeral from 'numeral'
import 'numeral/locales'
import socket from '../socket'
import router from '../router'
import { initRedux } from '../utils'

export const initialState = {confirmations: null}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'RECEIVED_UPDATED_CONFIRMATIONS': {
      return Object.assign({}, state, {
        confirmations: action.msg.confirmations
      })
    }
    default:
      return state
  }
}

router.when('/transactions/:transactionHash').then((params) => initRedux(reducer, {
  main (store) {
    const { transactionHash, locale } = params
    const channel = socket.channel(`transactions:${transactionHash}`, {})
    numeral.locale(locale)
    channel.join()
      .receive('ok', resp => { console.log('Joined successfully', `transactions:${transactionHash}`, resp) })
      .receive('error', resp => { console.log('Unable to join', `transactions:${transactionHash}`, resp) })
    channel.on('confirmations', (msg) => store.dispatch({ type: 'RECEIVED_UPDATED_CONFIRMATIONS', msg }))
  },
  render (state, oldState) {
    const $blockConfirmations = $('[data-selector="block_confirmations"]')
    if (oldState.confirmations !== state.confirmations) {
      $blockConfirmations.empty().append(numeral(msg.confirmations).format())
    }
  }
}))
