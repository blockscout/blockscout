import '../../css/stakes.scss'

import $ from 'jquery'
import _ from 'lodash'
import { subscribeChannel } from '../socket'
import { connectElements } from '../lib/redux_helpers.js'
import { createAsyncLoadStore } from '../lib/async_listing_load'

export const initialState = {
  channel: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, _.omit(action, 'type'))
    }
    case 'CHANNEL_CONNECTED': {
      return Object.assign({}, state, { channel: action.channel })
    }
    default:
      return state
  }
}

const elements = {
}

const $stakesPage = $('[data-page="stakes"]')
if ($stakesPage.length) {
  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierPool')
  connectElements({ store, elements })

  const channel = subscribeChannel('stakes:staking_update')
  channel.on('staking_update', msg => onStakingUpdate(msg, store))
  store.dispatch({ type: 'CHANNEL_CONNECTED', channel })
}

function onStakingUpdate (msg, store) {
  $('[data-selector="stakes-top"]').html(msg.top_html)
}
