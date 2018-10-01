import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import socket from '../socket'
import { updateAllAges } from '../lib/from_now'
import { initRedux, prependWithClingBottom } from '../utils'

export const initialState = {
  beyondPageOne: null,
  channelDisconnected: false,
  currentBlockNumber: null,
  newBlock: null,
  replaceBlock: null,
  skippedBlockNumbers: []
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      let blockNumber = parseInt(state.currentBlockNumber)
      if (!action.beyondPageOne) {
        blockNumber = parseInt(action.highestBlockNumber)
      }
      return Object.assign({}, state, {
        beyondPageOne: action.beyondPageOne,
        currentBlockNumber: blockNumber
      })
    }
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, {
        channelDisconnected: true
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      let skippedBlockNumbers = state.skippedBlockNumbers.slice(0)
      let replaceBlock = null
      const blockNumber = parseInt(action.msg.blockNumber)
      if (blockNumber > state.currentBlockNumber + 1) {
        for (let i = state.currentBlockNumber + 1; i < action.msg.blockNumber; i++) {
          skippedBlockNumbers.push(i)
        }
      } else if (_.indexOf(skippedBlockNumbers, blockNumber) != -1) {
        skippedBlockNumbers = _.without(skippedBlockNumbers, blockNumber)
        replaceBlock = blockNumber
      }
      return Object.assign({}, state, {
        currentBlockNumber: blockNumber > state.currentBlockNumber ? blockNumber : state.currentBlockNumber,
        newBlock: action.msg.blockHtml,
        replaceBlock,
        skippedBlockNumbers
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
        beyondPageOne: !!humps.camelizeKeys(URI(window.location).query(true)).blockNumber,
        highestBlockNumber: $('[data-selector="block-number"]').filter(':first').text()
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
        if (oldState.skippedBlockNumbers !== state.skippedBlockNumbers) {
          const newSkippedBlockNumbers = _.difference(state.skippedBlockNumbers, oldState.skippedBlockNumbers)
          if (state.replaceBlock) {
            const $placeHolder = $(`[data-selector="place-holder"][data-block-number="${state.replaceBlock}"] div.tile`)
            $placeHolder.addClass('shrink-out')
            setTimeout(() => $placeHolder.replaceWith(state.newBlock), 400)
          } else {
            _.map(newSkippedBlockNumbers, (skippedBlockNumber) => {
              prependWithClingBottom($blocksList, placeHolderBlock(skippedBlockNumber))
            })
            prependWithClingBottom($blocksList, state.newBlock)
          }
        } else {
          prependWithClingBottom($blocksList, state.newBlock)
        }
        updateAllAges()
      }
    }
  })
}

function placeHolderBlock(blockNumber) {
  return `
    <div class="my-3" style="height: 98px;">
      <div
        class="tile tile-type-block d-flex align-items-center fade-up"
        data-selector="place-holder"
        data-block-number="${blockNumber}"
        style="height: 98px;"
      >
        <span class="loading-spinner-small ml-1 mr-4">
          <span class="loading-spinner-block-1"></span>
          <span class="loading-spinner-block-2"></span>
        </span>
        <div>
          <div class="tile-title">${blockNumber}</div>
          <div> Block Mined, awaiting import...</div>
        </div>
      </div>
    </div>
  `
}
