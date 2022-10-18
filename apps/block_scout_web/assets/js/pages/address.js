import $ from 'jquery'
import omit from 'lodash.omit'
import URI from 'urijs'
import humps from 'humps'
import numeral from 'numeral'
import socket, { subscribeChannel } from '../socket'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import { updateAllCalculatedUsdValues } from '../lib/currency.js'
import { loadTokenBalanceDropdown } from '../lib/token_balance_dropdown'
import '../lib/token_balance_dropdown_search'
import '../lib/async_listing_load'
import '../app'
import {
  openQrModal
} from '../lib/modals'

export const initialState = {
  channelDisconnected: false,

  addressHash: null,
  filter: null,

  balance: null,
  balanceCard: null,
  fetchedCoinBalanceBlockNumber: null,
  transactionCount: null,
  tokenTransferCount: null,
  gasUsageCount: null,
  validationCount: null,
  countersFetched: false
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      if (state.beyondPageOne) return state

      return Object.assign({}, state, {
        channelDisconnected: true
      })
    }
    case 'COUNTERS_FETCHED': {
      return Object.assign({}, state, {
        transactionCount: action.transactionCount,
        tokenTransferCount: action.tokenTransferCount,
        gasUsageCount: action.gasUsageCount,
        validationCount: action.validationCount,
        crcTotalWorth: action.crcTotalWorth,
        countersFetched: true
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      if (state.channelDisconnected) return state

      const validationCount = state.validationCount + 1
      return Object.assign({}, state, { validationCount })
    }
    case 'RECEIVED_NEW_TRANSACTION': {
      if (state.channelDisconnected) return state

      const transactionCount = (action.msg.fromAddressHash === state.addressHash) ? state.transactionCount + 1 : state.transactionCount

      return Object.assign({}, state, { transactionCount })
    }
    case 'RECEIVED_NEW_TOKEN_TRANSFER': {
      if (state.channelDisconnected) return state

      const tokenTransferCount = (action.msg.fromAddressHash === state.addressHash) ? state.tokenTransferCount + 1 : state.tokenTransferCount

      return Object.assign({}, state, { tokenTransferCount })
    }
    case 'RECEIVED_UPDATED_BALANCE': {
      return Object.assign({}, state, {
        balanceCard: action.msg.balanceCard,
        balance: parseFloat(action.msg.balance),
        fetchedCoinBalanceBlockNumber: action.msg.fetchedCoinBalanceBlockNumber
      })
    }
    case 'RECEIVED_NEW_CURRENT_COIN_BALANCE': {
      if (state.initialBlockNumber && action.msg.currentCoinBalanceBlockNumber < state.initialBlockNumber) return
      return Object.assign({}, state, {
        currentCoinBalance: action.msg.currentCoinBalanceHtml,
        currentCoinBalanceBlockNumber: action.msg.currentCoinBalanceBlockNumberHtml,
        initialBlockNumber: state.newBlockNumber,
        newBlockNumber: action.msg.currentCoinBalanceBlockNumber
      })
    }
    default:
      return state
  }
}

let fetchedTokenBalanceBlockNumber = 0
function loadTokenBalance (blockNumber) {
  if (blockNumber > fetchedTokenBalanceBlockNumber) {
    fetchedTokenBalanceBlockNumber = blockNumber
    setTimeout(loadTokenBalanceDropdown, 1000)
  } else if (fetchedTokenBalanceBlockNumber === 0 && blockNumber === null) {
    setTimeout(loadTokenBalanceDropdown, 1000)
  }
}

const elements = {
  '[data-selector="channel-disconnected-message"]': {
    render ($el, state) {
      if (state.channelDisconnected && !window.loading) $el.show()
    }
  },
  '[data-selector="balance-card"]': {
    load ($el) {
      return { balanceCard: $el.html(), balance: parseFloat($el.find('.current-balance-in-wei').attr('data-wei-value')) }
    },
    render ($el, state, oldState) {
      if (oldState.balance === state.balance || (isNaN(oldState.balance) && isNaN(state.balance))) return
      $el.empty().append(state.balanceCard)
      loadTokenBalance(state.fetchedCoinBalanceBlockNumber)
      updateAllCalculatedUsdValues()
    }
  },
  '[data-selector="transaction-count"]': {
    load ($el) {
      return { transactionCount: numeral($el.text()).value() }
    },
    render ($el, state, oldState) {
      if (state.countersFetched) {
        if (oldState.transactionCount === state.transactionCount) return
        const transactionsDSName = (state.transactionCount === 1) ? ' Transaction' : ' Transactions'
        $el.empty().append(numeral(state.transactionCount).format() + transactionsDSName)
      }
    }
  },
  '[data-selector="transfer-count"]': {
    load ($el) {
      return { tokenTransferCount: numeral($el.text()).value() }
    },
    render ($el, state, oldState) {
      if (state.countersFetched) {
        if (oldState.tokenTransferCount === state.tokenTransferCount) return
        const transfersDSName = (state.tokenTransferCount === 1) ? ' Transfer' : ' Transfers'
        $el.empty().append(numeral(state.tokenTransferCount).format() + transfersDSName)
      }
    }
  },
  '[data-selector="gas-usage-count"]': {
    load ($el) {
      return { gasUsageCount: numeral($el.text()).value() }
    },
    render ($el, state, oldState) {
      if (state.countersFetched) {
        if (oldState.gasUsageCount === state.gasUsageCount) return
        $el.empty().append(numeral(state.gasUsageCount).format())
      }
    }
  },
  '[data-selector="fetched-coin-balance-block-number"]': {
    load ($el) {
      return { fetchedCoinBalanceBlockNumber: numeral($el.text()).value() }
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
      if (state.countersFetched && state.validationCount) {
        if (oldState.validationCount === state.validationCount) return
        $el.empty().append(numeral(state.validationCount).format())
        $('.address-validation-count-item').removeAttr('style')
      } else {
        $('.address-validation-count-item').css('display', 'none')
      }
    }
  },
  '[data-test="address-tokens-panel-crc-total-worth"]': {
    load ($el) {
      return { countersFetched: numeral($el.text()).value() }
    },
    render ($el, state, oldState) {
      if (state.countersFetched && state.crcTotalWorth) {
        if (oldState.crcTotalWorth === state.crcTotalWorth) return
        $el.empty().append(`${state.crcTotalWorth} CRC`)
        if (state.crcTotalWorth !== '0') {
          $('[data-test="address-tokens-panel-crc-total-worth-container"]').removeClass('d-none')
        } else {
          $('[data-test="address-tokens-panel-crc-total-worth-container"]').addClass('d-none')
        }
      } else {
        $('[data-test="address-tokens-panel-crc-total-worth-container"]').addClass('d-none')
      }
    }
  },
  '[data-selector="current-coin-balance"]': {
    render ($el, state, oldState) {
      if (!state.newBlockNumber || state.newBlockNumber > oldState.newBlockNumber) return
      $el.empty().append(state.currentCoinBalance)
      updateAllCalculatedUsdValues()
    }
  },
  '[data-selector="last-balance-update"]': {
    render ($el, state, oldState) {
      if (!state.newBlockNumber || state.newBlockNumber > oldState.newBlockNumber) return
      $el.empty().append(state.currentCoinBalanceBlockNumber)
    }
  },
  '[data-last-balance-update]': {
    load ($el) {
      return { initialBlockNumber: numeral($el.data('last-balance-update')).value() }
    }
  }
}

function loadCounters (store) {
  const $element = $('[data-async-counters]')
  const path = $element.data().asyncCounters

  function fetchCounters () {
    $.getJSON(path)
      .done(response => store.dispatch(Object.assign({ type: 'COUNTERS_FETCHED' }, humps.camelizeKeys(response))))
  }

  fetchCounters()
}

const $addressDetailsPage = $('[data-page="address-details"]')
if ($addressDetailsPage.length) {
  const pathParts = window.location.pathname.split('/')
  const shouldScroll = pathParts.includes('transactions') ||
  pathParts.includes('token-transfers') ||
  pathParts.includes('tokens') ||
  pathParts.includes('internal-transactions') ||
  pathParts.includes('coin-balances') ||
  pathParts.includes('logs') ||
  pathParts.includes('validations') ||
  pathParts.includes('contracts') ||
  pathParts.includes('decompiled-contracts') ||
  pathParts.includes('read-contract') ||
  pathParts.includes('read-proxy') ||
  pathParts.includes('write-contract') ||
  pathParts.includes('write-proxy')

  if (shouldScroll) {
    location.href = '#address-tabs'
  }

  window.onbeforeunload = () => {
    window.loading = true
  }

  const store = createStore(reducer)
  const addressHash = $addressDetailsPage[0].dataset.pageAddressHash
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
  addressChannel.on('balance', (msg) => store.dispatch({
    type: 'RECEIVED_UPDATED_BALANCE',
    msg: humps.camelizeKeys(msg)
  }))
  addressChannel.on('token_balance', (msg) => loadTokenBalance(
    msg.block_number
  ))
  addressChannel.on('transaction', (msg) => {
    store.dispatch({
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: humps.camelizeKeys(msg)
    })
  })
  addressChannel.on('transfer', (msg) => {
    store.dispatch({
      type: 'RECEIVED_NEW_TOKEN_TRANSFER',
      msg: humps.camelizeKeys(msg)
    })
  })
  addressChannel.on('current_coin_balance', (msg) => {
    store.dispatch({
      type: 'RECEIVED_NEW_CURRENT_COIN_BALANCE',
      msg: humps.camelizeKeys(msg)
    })
  })

  const blocksChannel = socket.channel(`blocks:${addressHash}`, {})
  blocksChannel.join()
  blocksChannel.onError(() => store.dispatch({
    type: 'CHANNEL_DISCONNECTED'
  }))
  blocksChannel.on('new_block', (msg) => store.dispatch({
    type: 'RECEIVED_NEW_BLOCK',
    msg: humps.camelizeKeys(msg)
  }))

  addressChannel.push('get_balance', {})
    .receive('ok', (msg) => store.dispatch({
      type: 'RECEIVED_UPDATED_BALANCE',
      msg: humps.camelizeKeys(msg)
    }))

  loadCounters(store)

  $('.btn-qr-icon').click(_event => {
    openQrModal()
  })
}
