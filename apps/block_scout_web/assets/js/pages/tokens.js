import $ from 'jquery'
import omit from 'lodash/omit'
import humps from 'humps'
import { subscribeChannel } from '../socket'
import { connectElements } from '../lib/redux_helpers.js'
import { createAsyncLoadStore } from '../lib/async_listing_load'
import './address'

const BATCH_THRESHOLD = 10

export const initialState = {
  channelDisconnected: false,
  tokenTransferCount: null,
  tokenTransfersBatch: []
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, {
        channelDisconnected: true,
        tokenTransfersBatch: []
      })
    }
    case 'RECEIVED_NEW_TOKEN_TRANSFER': {
      if (state.channelDisconnected) return state

      // const tokenTransferCount = state.tokenTransferCount + action.msgs.length

      // const tokenTransfersLength = state.items.length + action.msgs.length
      console.log(action)
      return Object.assign({}, state, { items: [action.msg.tokenTransferHtml, ...state.items] })
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

const $tokenTransferListPage = $('[data-page="token-transfer-list"]')
if ($tokenTransferListPage.length) {
  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierHash')

  connectElements({ store, elements })

  const tokenTransfersChannel = subscribeChannel('token_transfers:new_token_transfer')
  tokenTransfersChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
  tokenTransfersChannel.on('token_transfer', (msg) => {
    store.dispatch({
      type: 'RECEIVED_NEW_TOKEN_TRANSFER',
      msg: humps.camelizeKeys(msg)
    })
  })
}
