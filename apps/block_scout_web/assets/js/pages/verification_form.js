import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import numeral from 'numeral'
import socket, { subscribeChannel } from '../socket'
import { createStore, connectElements } from '../lib/redux_helpers.js'

export const initialState = {
  channelDisconnected: false,

  addressHash: null,
  filter: null,

  balance: null,
  balanceCard: null,
  fetchedCoinBalanceBlockNumber: null,
  transactionCount: null,
  validationCount: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, _.omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      if (state.beyondPageOne) return state

      return Object.assign({}, state, {
        channelDisconnected: true
      })
    }
    case 'RECEIVED_VERIFICATION_RESULT': {
      if (action.msg.verificationResult === "ok") {
          window.location.replace(window.location.href.split('/contract_verifications')[0] + '/contracts')
      }
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
  },
  '[data-selector="balance-card"]': {
    load ($el) {
      return { balanceCard: $el.html(), balance: parseFloat($el.find('.current-balance-in-wei').attr('data-wei-value')) }
    },
    render ($el, state, oldState) {
      if (oldState.balance === state.balance) return
      $el.empty().append(state.balanceCard)
      loadTokenBalanceDropdown()
      updateAllCalculatedUsdValues()
    }
  },
  '[data-selector="transaction-count"]': {
    load ($el) {
      return { transactionCount: numeral($el.text()).value() }
    },
    render ($el, state, oldState) {
      if (oldState.transactionCount === state.transactionCount) return
      $el.empty().append(numeral(state.transactionCount).format())
    }
  },
  '[data-selector="fetched-coin-balance-block-number"]': {
    load ($el) {
      return {fetchedCoinBalanceBlockNumber: numeral($el.text()).value()}
    },
    render ($el, state, oldState) {
      if (oldState.fetchedCoinBalanceBlockNumber === state.fetchedCoinBalanceBlockNumber) return
      $el.empty().append(numeral(state.fetchedCoinBalanceBlockNumber).format())
    }
  },
  '[data-selector="validation-count"]': {
    load ($el) {
      return { validationCount: numeral($el.text()).value() }
    },
    render ($el, state, oldState) {
      if (oldState.validationCount === state.validationCount) return
      $el.empty().append(numeral(state.validationCount).format())
    }
  }
}

const $contractVerificationPage = $('[data-page="contract-verification"]')

if ($contractVerificationPage.length) {
  const store = createStore(reducer)
  const addressHash = $('#smart_contract_address_hash').val()
  const { filter, blockNumber } = humps.camelizeKeys(URI(window.location).query(true))
  store.dispatch({
    type: 'PAGE_LOAD',
    addressHash,
    filter,
    beyondPageOne: !!blockNumber
  })
  connectElements({ store, elements })

  const addressChannel = subscribeChannel(`addresses:${addressHash}`)

  addressChannel.onError(() => store.dispatch({
    type: 'CHANNEL_DISCONNECTED'
  }))
  addressChannel.on("verification", (msg) => store.dispatch({
    type: 'RECEIVED_VERIFICATION_RESULT',
    msg: humps.camelizeKeys(msg)
  }))
}
