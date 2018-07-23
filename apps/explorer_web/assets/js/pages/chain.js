import $ from 'jquery'
import humps from 'humps'
import router from '../router'
import socket from '../socket'
import { updateAllAges } from '../lib/from_now'
import { initRedux } from '../utils'

export const initialState = {
  newBlock: null,
  channelDisconnected: false
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, {
        channelDisconnected: true
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      return Object.assign({}, state, {
        newBlock: humps.camelizeKeys(action.msg).homepageBlockHtml
      })
    }
    default:
      return state
  }
}

router.when('', { exactPathMatch: true }).then(() => initRedux(reducer, {
  main (store) {
    const blocksChannel = socket.channel(`blocks:new_block`)
    blocksChannel.join()
      .receive('ok', resp => { console.log('Joined successfully', 'blocks:new_block', resp) })
      .receive('error', resp => { console.log('Unable to join', 'blocks:new_block', resp) })
    blocksChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
    blocksChannel.on('new_block', msg => store.dispatch({ type: 'RECEIVED_NEW_BLOCK', msg }))
  },
  render (state, oldState) {
    const $blockList = $('[data-selector="chain-block-list"]')

    if (oldState.newBlock !== state.newBlock) {
      $blockList.children().last().remove()
      $blockList.prepend(state.newBlock)
      updateAllAges()
    }
  }
}))
