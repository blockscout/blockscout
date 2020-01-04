import $ from 'jquery'
import omit from 'lodash/omit'
import humps from 'humps'
import socket from '../../socket'
import { connectElements } from '../../lib/redux_helpers.js'
import { createAsyncLoadStore } from '../../lib/async_listing_load'

export const initialState = {
  channelDisconnected: false
}

export function reducer (state, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      if (state.beyondPageOne) return state

      return Object.assign({}, state, {
        channelDisconnected: true
      })
    }
    case 'RECEIVED_NEW_COIN_BALANCE': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      return Object.assign({}, state, {
        items: [action.msg.coinBalanceHtml, ...state.items]
      })
    }
    default:
      return state
  }
}

const elements = {
  '[data-selector="channel-disconnected-message"]': {
    render ($el, state) {
      if (state.channelDisconnected) $el.show()
    }
  }
}

if ($('[data-page="coin-balance-history"]').length) {
  const store = createAsyncLoadStore(reducer, initialState, 'dataset.blockNumber')
  const addressHash = $('[data-page="address-details"]')[0].dataset.pageAddressHash

  store.dispatch({ type: 'PAGE_LOAD', addressHash })
  connectElements({ store, elements })

  const addressChannel = socket.channel(`addresses:${addressHash}`, {})
  addressChannel.join()
  addressChannel.onError(() => store.dispatch({
    type: 'CHANNEL_DISCONNECTED'
  }))
  addressChannel.on('coin_balance', (msg) => {
    store.dispatch({
      type: 'RECEIVED_NEW_COIN_BALANCE',
      msg: humps.camelizeKeys(msg)
    })
  })
}
