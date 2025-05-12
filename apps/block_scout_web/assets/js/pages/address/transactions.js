import $ from 'jquery'
import omit from 'lodash.omit'
import URI from 'urijs'
import humps from 'humps'
import numeral from 'numeral'
import { subscribeChannel } from '../../socket'
import { connectElements } from '../../lib/redux_helpers.js'
import { createAsyncLoadStore } from '../../lib/async_listing_load'
import { batchChannel } from '../../lib/utils'
import '../address'
import { isFiltered } from './utils'

const BATCH_THRESHOLD = 6

export const initialState = {
  addressHash: null,
  channelDisconnected: false,
  filter: null,
  transactionsBatch: []
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
    case 'RECEIVED_NEW_TRANSACTION': {
      if (state.channelDisconnected) return state

      if (state.beyondPageOne ||
        (state.filter === 'to' && action.msg.toAddressHash !== state.addressHash) ||
        (state.filter === 'from' && action.msg.fromAddressHash !== state.addressHash)) {
        return state
      }

      return Object.assign({}, state, { items: [action.msg.transactionHtml, ...state.items] })
    }
    case 'RECEIVED_NEW_TRANSACTION_BATCH': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      const transactionCount = state.transactionCount + action.msgs.length

      if (!state.transactionsBatch.length && action.msgs.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          items: [
            ...action.msgs.map(msg => msg.transactionHtml).reverse(),
            ...state.items
          ],
          transactionCount
        })
      } else {
        return Object.assign({}, state, {
          transactionsBatch: [
            ...action.msgs.reverse(),
            ...state.transactionsBatch
          ],
          transactionCount
        })
      }
    }
    case 'RECEIVED_NEW_REWARD': {
      if (state.channelDisconnected) return state

      return Object.assign({}, state, { items: [action.msg.rewardHtml, ...state.items] })
    }
    case 'TRANSACTION_BATCH_EXPANDED': {
      return Object.assign({}, state, {
        transactionsBatch: []
      })
    }
    case 'TRANSACTIONS_FETCHED':
      return Object.assign({}, state, { items: [...action.msg.items] })
    case 'TRANSACTIONS_FETCH_ERROR': {
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      $channelBatching.show()
      return state
    }
    default:
      return state
  }
}

const elements = {
  '[data-selector="channel-disconnected-message"]': {
    render ($el, state) {
      // @ts-ignore
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
  },
  '[data-selector="channel-batching-count"]': {
    render ($el, state, _oldState) {
      const $channelBatching = $('[data-selector="channel-batching-message"]')
      if (!state.transactionsBatch.length) return $channelBatching.hide()
      $channelBatching.show()
      $el[0].innerHTML = numeral(state.transactionsBatch.length).format()
    }
  }
}

if ($('[data-page="address-transactions"]').length) {
  window.onbeforeunload = () => {
    // @ts-ignore
    window.loading = true
  }

  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierHash')
  const addressHash = $('[data-page="address-details"]')[0].dataset.pageAddressHash
  // @ts-ignore
  const { filter, blockNumber } = humps.camelizeKeys(URI(window.location).query(true))

  connectElements({ store, elements })

  store.dispatch({
    type: 'PAGE_LOAD',
    addressHash,
    filter,
    beyondPageOne: !!blockNumber
  })

  const addressChannel = subscribeChannel(`addresses_old:${addressHash}`)
  addressChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
  addressChannel.on('transaction', batchChannel((msgs) =>
    store.dispatch({
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: humps.camelizeKeys(msgs)
    })
  ))
  addressChannel.on('pending_transaction', batchChannel((msgs) =>
    store.dispatch({
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: humps.camelizeKeys(msgs)
    })
  ))

  const rewardsChannel = subscribeChannel(`rewards_old:${addressHash}`)
  rewardsChannel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
  rewardsChannel.on('new_reward', (msg) => {
    store.dispatch({
      type: 'RECEIVED_NEW_REWARD',
      msg: humps.camelizeKeys(msg)
    })
  })

  const $txReloadButton = $('[data-selector="reload-transactions-button"]')
  const $channelBatching = $('[data-selector="channel-batching-message"]')
  $txReloadButton.on('click', (event) => {
    event.preventDefault()
    loadTransactions(store)
    $channelBatching.hide()
    store.dispatch({
      type: 'TRANSACTION_BATCH_EXPANDED'
    })
  })
}

function loadTransactions (store) {
  const path = $('[class="card-body"]')[0].dataset.asyncListing
  store.dispatch({ type: 'START_TRANSACTIONS_FETCH' })
  // @ts-ignore
  $.getJSON(path, { type: 'JSON' })
    .done(response => store.dispatch({ type: 'TRANSACTIONS_FETCHED', msg: humps.camelizeKeys(response) }))
    .fail(() => store.dispatch({ type: 'TRANSACTIONS_FETCH_ERROR' }))
    .always(() => store.dispatch({ type: 'FINISH_TRANSACTIONS_FETCH' }))
}
