import $ from 'jquery'
import humps from 'humps'
import numeral from 'numeral'
import 'numeral/locales'
import socket from '../socket'
import router from '../router'
import { batchChannel, initRedux } from '../utils'

const BATCH_THRESHOLD = 10

const initialState = {
  addressHash: null,
  filter: null,
  beyondPageOne: null,
  channelDisconnected: false,
  overview: null,
  newTransactions: [],
  batchCountAccumulator: 0
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD': {
      return Object.assign({}, state, {
        addressHash: action.params.addressHash,
        filter: action.params.filter,
        beyondPageOne: !!action.params.blockNumber
      })
    }
    case 'CHANNEL_DISCONNECTED': {
      if (state.beyondPageOne) return state

      return Object.assign({}, state, {
        channelDisconnected: true,
        batchCountAccumulator: 0
      })
    }
    case 'RECEIVED_UPDATED_OVERVIEW': {
      return Object.assign({}, state, {
        overview: action.msg.overview
      })
    }
    case 'RECEIVED_NEW_TRANSACTION_BATCH': {
      if (state.channelDisconnected || state.beyondPageOne) return state

      const incomingTransactions = humps.camelizeKeys(action.msgs)
        .filter(({toAddressHash, fromAddressHash}) => (
          !state.filter ||
          (state.filter === 'to' && toAddressHash === state.addressHash) ||
          (state.filter === 'from' && fromAddressHash === state.addressHash)
        ))

      if (!state.batchCountAccumulator && action.msgs.length < BATCH_THRESHOLD) {
        return Object.assign({}, state, {
          newTransactions: [
            ...state.newTransactions,
            ...incomingTransactions.map(({transactionHtml}) => transactionHtml)
          ]
        })
      } else {
        return Object.assign({}, state, {
          batchCountAccumulator: state.batchCountAccumulator + action.msgs.length
        })
      }
    }
    default:
      return state
  }
}

router.when('/addresses/:addressHash').then((params) => initRedux(reducer, {
  main (store) {
    const { addressHash, blockNumber, locale } = params
    const channel = socket.channel(`addresses:${addressHash}`, {})
    numeral.locale(locale)
    store.dispatch({ type: 'PAGE_LOAD', params })
    channel.join()
      .receive('ok', resp => { console.log('Joined successfully', `addresses:${addressHash}`, resp) })
      .receive('error', resp => { console.log('Unable to join', `addresses:${addressHash}`, resp) })
    channel.onError(() => store.dispatch({ type: 'CHANNEL_DISCONNECTED' }))
    channel.on('overview', (msg) => store.dispatch({ type: 'RECEIVED_UPDATED_OVERVIEW', msg }))
    if (!blockNumber) channel.on('transaction', batchChannel((msgs) => store.dispatch({ type: 'RECEIVED_NEW_TRANSACTION_BATCH', msgs })))
  },
  render (state, oldState) {
    const $channelDisconnected = $('[data-selector="channel-disconnected-message"]')
    const $overview = $('[data-selector="overview"]')
    const $emptyTransactionsList = $('[data-selector="empty-transactions-list"]')
    const $transactionsList = $('[data-selector="transactions-list"]')
    const $channelBatching = $('[data-selector="channel-batching-message"]')
    const $channelBatchingCount = $('[data-selector="channel-batching-count"]')

    if ($emptyTransactionsList.length && state.newTransactions.length) window.location.reload()
    if (state.channelDisconnected) $channelDisconnected.show()
    if (oldState.overview !== state.overview) $overview.empty().append(state.overview)
    if (state.batchCountAccumulator) {
      $channelBatching.show()
      $channelBatchingCount[0].innerHTML = numeral(state.batchCountAccumulator).format()
    } else {
      $channelBatching.hide()
    }
    if (oldState.newTransactions !== state.newTransactions && $transactionsList.length) {
      $transactionsList.prepend(state.newTransactions.slice(oldState.newTransactions.length).reverse().join(''))
    }
  }
}))
