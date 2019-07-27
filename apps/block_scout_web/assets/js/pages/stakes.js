import '../../css/stakes.scss'

import $ from 'jquery'
import _ from 'lodash'
import { subscribeChannel } from '../socket'
import { connectElements } from '../lib/redux_helpers.js'
import { createAsyncLoadStore, refreshPage } from '../lib/async_listing_load'
import Web3 from 'web3'

export const initialState = {
  channel: null,
  web3: null,
  account: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, _.omit(action, 'type'))
    }
    case 'CHANNEL_CONNECTED': {
      return Object.assign({}, state, { channel: action.channel })
    }
    case 'WEB3_DETECTED': {
      return Object.assign({}, state, { web3: action.web3 })
    }
    case 'ACCOUNT_UPDATED': {
      return Object.assign({}, state, {
        account: action.account,
        additionalParams: { account: action.account }
      })
    }
    }
    default:
      return state
  }
}

const elements = {
}

const $stakesPage = $('[data-page="stakes"]')
if ($stakesPage.length) {
  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierPool')
  connectElements({ store, elements })

  const channel = subscribeChannel('stakes:staking_update')
  channel.on('staking_update', msg => onStakingUpdate(msg, store))
  store.dispatch({ type: 'CHANNEL_CONNECTED', channel })

  initializeWeb3(store)
}

function onStakingUpdate (msg, store) {
  $('[data-selector="stakes-top"]').html(msg.top_html)

  if (store.getState().web3) {
    $('[data-selector="login-button"]').on('click', loginByMetamask)
  }
}

function initializeWeb3 (store) {
  if (window.ethereum) {
    const web3 = new Web3(window.ethereum)
    store.dispatch({ type: 'WEB3_DETECTED', web3 })

    setInterval(async function () {
      const accounts = await web3.eth.getAccounts()
      const account = accounts[0] ? accounts[0].toLowerCase() : null

      if (account !== store.getState().account) {
        setAccount(account, store)
      }
    }, 100)
  }
}

function setAccount (account, store) {
  store.dispatch({ type: 'ACCOUNT_UPDATED', account })
  store.getState().channel.push('set_account', account)
  refreshPage(store)
}

async function loginByMetamask (event) {
  event.stopPropagation()
  event.preventDefault()

  try {
    await window.ethereum.enable()
  } catch (e) {
    console.log(e)
    console.error('User denied account access')
  }
}
