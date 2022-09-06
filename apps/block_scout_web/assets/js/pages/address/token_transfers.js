import $ from 'jquery'
import omit from 'lodash/omit'
import URI from 'urijs'
import humps from 'humps'
import { subscribeChannel } from '../../socket'
import { connectElements } from '../../lib/redux_helpers.js'
import { createAsyncLoadStore } from '../../lib/async_listing_load'
import '../address'
import { isFiltered } from './utils'

export const initialState = {
  addressHash: null,
  channelDisconnected: false,
  filter: null
}

export function reducer (state, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      if (state.beyondPageOne) return state

      return Object.assign({}, state, { channelDisconnected: true })
    }
    case 'RECEIVED_NEW_TOKEN_TRANSFER': {
      if (state.channelDisconnected) return state

      if (state.beyondPageOne ||
        (state.filter === 'to' && action.msg.toAddressHash !== state.addressHash) ||
        (state.filter === 'from' && action.msg.fromAddressHash !== state.addressHash)) {
        return state
      }

      return Object.assign({}, state, { items: [action.msg.tokenTransferHtml, ...state.items] })
    }
    case 'RECEIVED_NEW_REWARD': {
      if (state.channelDisconnected) return state

      return Object.assign({}, state, { items: [action.msg.rewardHtml, ...state.items] })
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
  },
  '[data-test="filter_dropdown"]': {
    render ($el, state) {
      if (state.emptyResponse && !state.isSearch) {
        if (isFiltered(state.filter)) {
          $el.addClass('no-rm')
        } else {
          return $el.hide()
        }
      } else {
        $el.removeClass('no-rm')
      }

      return $el.show()
    }
  }
}

if ($('[data-page="address-token-transfers"]').length) {
  window.onbeforeunload = () => {
    window.loading = true
  }

  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierHash')
  const addressHash = $('[data-page="address-details"]')[0].dataset.pageAddressHash
  const { filter, blockNumber } = humps.camelizeKeys(URI(window.location).query(true))

  connectElements({ store, elements })

  store.dispatch({
    type: 'PAGE_LOAD',
    addressHash,
    filter,
    beyondPageOne: !!blockNumber
  })

  const addressChannel = subscribeChannel(`addresses:${addressHash}`)
  addressChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
  addressChannel.on('token_transfer', (msg) => {
    store.dispatch({
      type: 'RECEIVED_NEW_TOKEN_TRANSFER',
      msg: humps.camelizeKeys(msg)
    })
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
