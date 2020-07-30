import $ from 'jquery'
import omit from 'lodash/omit'
import humps from 'humps'
import socket from '../socket'
import { createAsyncLoadStore } from '../lib/async_listing_load'
import { batchChannel } from '../lib/utils'
import '../app'

const BATCH_THRESHOLD = 10

export const initialState = {
  channelDisconnected: false,
  tokenTransferCount: null,
  tokenTransfersBatch: []
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, {
        channelDisconnected: true,
        tokenTransfersBatch: []
      })
    }
    case 'RECEIVED_NEW_TOKEN_TRANSFER_BATCH': {
      if (state.channelDisconnected) return state

      const tokenTransferCount = state.tokenTransferCount + action.msgs.length

      const tokenTransfersLength = state.items.length + action.msgs.length
      if (tokenTransfersLength < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          items: [
            ...action.msgs.map(msg => msg.tokenTransferHtml).reverse(),
            ...state.items
          ],
          tokenTransferCount
        })
      } else if (!state.tokenTransfersBatch.length && action.msgs.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          items: [
            ...action.msgs.map(msg => msg.tokenTransferHtml).reverse(),
            ...state.items.slice(0, -1 * action.msgs.length)
          ],
          tokenTransferCount
        })
      } else {
        return Object.assign({}, state, {
          tokenTransfersBatch: [
            ...action.msgs.reverse(),
            ...state.tokenTransfersBatch
          ],
          tokenTransferCount
        })
      }
    }
    default:
      return state
  }
}

const $tokenTransferListPage = $('[data-page="token-transfer-list"]')
if ($tokenTransferListPage.length) {
  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierHash')

  const tokenTransfersChannel = socket.channel('token_transfers:new_token_transfer')
  tokenTransfersChannel.join()
  tokenTransfersChannel.onError(() => store.dispatch({
    type: 'CHANNEL_DISCONNECTED'
  }))
  tokenTransfersChannel.on('token_transfer', batchChannel((msgs) => {
    store.dispatch({
      type: 'RECEIVED_NEW_TOKEN_TRANSFER_BATCH',
      msgs: humps.camelizeKeys(msgs)
    })
  }))
}
