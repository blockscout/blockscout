import $ from 'jquery'
import omit from 'lodash/omit'
import humps from 'humps'
import { subscribeChannel } from '../../socket'
import { connectElements } from '../../lib/redux_helpers.js'
import { createAsyncLoadStore } from '../../lib/async_listing_load.js'
import '../address'

export const initialState = {
  addressHash: null,
  channelDisconnected: false
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, { channelDisconnected: true })
    }
    case 'RECEIVED_NEW_REWARD': {
      if (state.channelDisconnected) return state
      if (state.beyondPageOne) return state

      return Object.assign({}, state, {
        items: [
          action.blockHtml,
          ...state.items
        ]
      })
    }
    default:
      return state
  }
}

const elements = {
  '[data-selector="channel-disconnected-message"]': {
    render ($el, state) {
      if (state.channelDisconnected && !window.loading) $el.show()
    }
  }
}

if ($('[data-page="rewards"]').length) {
  window.onbeforeunload = () => {
    window.loading = true
  }

  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierHash')
  connectElements({ store, elements })
  const addressHash = $('[data-page="address-details"]')[0].dataset.pageAddressHash
  store.dispatch({
    type: 'PAGE_LOAD',
    addressHash
  })

  const rewardsChannel = subscribeChannel(`rewards:${addressHash}`)
  rewardsChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
  rewardsChannel.on('new_reward', (msg) => {
    store.dispatch({
      type: 'RECEIVED_NEW_REWARD',
      msg: humps.camelizeKeys(msg)
    })
  })
}
