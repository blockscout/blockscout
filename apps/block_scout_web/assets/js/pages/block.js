import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import socket from '../socket'
import { updateAllAges } from '../lib/from_now'
import { buildFullBlockList, initRedux, beforeWithClingBottom, skippedBlockListBuilder } from '../utils'

export const initialState = {
  blockNumbers: [],
  beyondPageOne: null,
  channelDisconnected: false,
  newBlock: null,
  replaceBlock: null,
  skippedBlockNumbers: []
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      const blockNumbers = buildFullBlockList(action.blockNumbers)
      const skippedBlockNumbers = _.difference(blockNumbers, action.blockNumbers)
      return Object.assign({}, state, {
        beyondPageOne: action.beyondPageOne,
        blockNumbers,
        skippedBlockNumbers
      })
    }
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, {
        channelDisconnected: true
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      const blockNumber = parseInt(action.msg.blockNumber)
      if (_.includes(state.blockNumbers, blockNumber)) {
        return Object.assign({}, state, {
          newBlock: action.msg.blockHtml,
          replaceBlock: blockNumber,
          skippedBlockNumbers: _.without(state.skippedBlockNumbers, blockNumber)
        })
      } else if (blockNumber < _.last(state.blockNumbers)) {
        return state
      } else {
        let skippedBlockNumbers = state.skippedBlockNumbers.slice(0)
        if (blockNumber > state.blockNumbers[0] + 1) {
          skippedBlockListBuilder(skippedBlockNumbers, blockNumber, state.blockNumbers[0])
        }
        const newBlockNumbers = _.chain([blockNumber])
          .union(skippedBlockNumbers, state.blockNumbers)
          .orderBy([], ['desc'])
          .value()

        return Object.assign({}, state, {
          blockNumbers: newBlockNumbers,
          newBlock: action.msg.blockHtml,
          replaceBlock: null,
          skippedBlockNumbers
        })
      }
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
        blockNumbers: $('[data-selector="block-number"]').map((index, el) => parseInt(el.innerText)).toArray()
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
      const skippedBlockNumbers = _.difference(state.skippedBlockNumbers, oldState.skippedBlockNumbers)

      if (state.channelDisconnected) $channelDisconnected.show()
      if ((state.newBlock && oldState.newBlock !== state.newBlock) || skippedBlockNumbers.length) {
        if (state.replaceBlock && oldState.replaceBlock !== state.replaceBlock) {
          const $replaceBlock = $(`[data-block-number="${state.replaceBlock}"]`)
          $replaceBlock.addClass('shrink-out')
          setTimeout(() => $replaceBlock.replaceWith(state.newBlock), 400)
        } else {
          if (skippedBlockNumbers.length) {
            _.forEachRight(skippedBlockNumbers, (skippedBlockNumber) => {
              beforeWithClingBottom($(`[data-block-number="${skippedBlockNumber - 1}"]`), placeHolderBlock(skippedBlockNumber))
            })
          }
          beforeWithClingBottom($(`[data-block-number="${state.blockNumbers[0] - 1}"]`), state.newBlock)
        }
        updateAllAges()
      }
    }
  })
}

function placeHolderBlock (blockNumber) {
  return `
    <div class="my-3" style="height: 98px;" data-selector="place-holder" data-block-number="${blockNumber}">
      <div
        class="tile tile-type-block d-flex align-items-center fade-up"
        style="height: 98px;"
      >
        <span class="loading-spinner-small ml-1 mr-4">
          <span class="loading-spinner-block-1"></span>
          <span class="loading-spinner-block-2"></span>
        </span>
        <div>
          <div class="tile-title">${blockNumber}</div>
          <div>${window.localized['Block Processing']}</div>
        </div>
      </div>
    </div>
  `
}
