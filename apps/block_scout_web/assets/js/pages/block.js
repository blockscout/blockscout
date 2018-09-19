import $ from 'jquery'
import URI from 'urijs'
import humps from 'humps'
import socket from '../socket'
import { updateAllAges } from '../lib/from_now'
import { initRedux } from '../utils'

export const initialState = {
  beyondPageOne: null,
  channelDisconnected: false,
  newBlock: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      return Object.assign({}, state, {
        beyondPageOne: action.beyondPageOne
      })
    }
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, {
        channelDisconnected: true
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      if (state.channelDisconnected) return state

      return Object.assign({}, state, {
        newBlock: action.msg.blockHtml
      })
    }
    default:
      return state
  }
}

const $blockListPage = $('[data-page="block-list"]')
if ($blockListPage.length) {
  initRedux(reducer, {
    main (store) {
      const state = store.dispatch({
        type: 'PAGE_LOAD',
        beyondPageOne: !!humps.camelizeKeys(URI(window.location).query(true)).blockNumber
      })
      if (!state.beyondPageOne) {
        const blocksChannel = socket.channel(`blocks:new_block`, {})
        blocksChannel.join()
        blocksChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
        blocksChannel.on('new_block', (msg) =>
          store.dispatch({ type: 'RECEIVED_NEW_BLOCK', msg: humps.camelizeKeys(msg) })
        )
      }
    },
    render (state, oldState) {
      const $channelDisconnected = $('[data-selector="channel-disconnected-message"]')
      const $blocksList = $('[data-selector="blocks-list"]')

      if (state.channelDisconnected) $channelDisconnected.show()
      if (oldState.newBlock !== state.newBlock) {
        const fromBottom = document.body.scrollHeight - window.scrollY
        let clingBottomAnimationFrame
        let expectedScrollPosition = window.scrollY
        function clingBottom () {
          if (expectedScrollPosition !== window.scrollY) return stopCling()

          expectedScrollPosition = document.body.scrollHeight - fromBottom
          $(window).scrollTop(expectedScrollPosition)
          clingBottomAnimationFrame = requestAnimationFrame(clingBottom)
        }
        function stopCling () {
          cancelAnimationFrame(clingBottomAnimationFrame)
          $blocksList.off('animationend animationcancel', stopCling)
        }
        if (window.scrollY > $blocksList.offset().top) {
          clingBottomAnimationFrame = requestAnimationFrame(clingBottom)
          $blocksList.on('animationend animationcancel', stopCling)
        }
        $blocksList.prepend(state.newBlock)
        updateAllAges()
      }
    }
  })
}
