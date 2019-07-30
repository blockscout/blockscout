import '../../css/stakes.scss'

import $ from 'jquery'
import _ from 'lodash'
import { subscribeChannel } from '../socket'
import { connectElements } from '../lib/redux_helpers.js'
import { createAsyncLoadStore, refreshPage } from '../lib/async_listing_load'
import Web3 from 'web3'
import { openValidatorInfoModal } from './stakes/validator_info'
import { openBecomeCandidateModal } from './stakes/become_candidate'
import { openRemovePoolModal } from './stakes/remove_pool'
import { openMakeStakeModal } from './stakes/make_stake'
import { openMoveStakeModal } from './stakes/move_stake'

export const initialState = {
  channel: null,
  web3: null,
  account: null,
  stakingContract: null,
  blockRewardContract: null,
  tokenDecimals: 0,
  tokenSymbol: ''
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
    case 'RECEIVED_CONTRACTS': {
      return Object.assign({}, state, {
        stakingContract: action.stakingContract,
        blockRewardContract: action.blockRewardContract,
        tokenDecimals: action.tokenDecimals,
        tokenSymbol: action.tokenSymbol
      })
    }
    default:
      return state
  }
}

const elements = {
}

const $stakesPage = $('[data-page="stakes"]')
const $stakesTop = $('[data-selector="stakes-top"]')
if ($stakesPage.length) {
  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierPool')
  connectElements({ store, elements })

  const channel = subscribeChannel('stakes:staking_update')
  store.dispatch({ type: 'CHANNEL_CONNECTED', channel })

  channel.on('staking_update', msg => $stakesTop.html(msg.top_html))
  channel.on('contracts', msg => {
    const web3 = store.getState().web3
    const stakingContract =
      new web3.eth.Contract(msg.staking_contract.abi, msg.staking_contract.address)
    const blockRewardContract =
      new web3.eth.Contract(msg.block_reward_contract.abi, msg.block_reward_contract.address)

    store.dispatch({
      type: 'RECEIVED_CONTRACTS',
      stakingContract,
      blockRewardContract,
      tokenDecimals: parseInt(msg.token_decimals),
      tokenSymbol: msg.token_symbol
    })
  })

  $(document.body)
    .on('click', '.js-validator-info', event => openValidatorInfoModal(event, store))
    .on('click', '.js-become-candidate', () => openBecomeCandidateModal(store))
    .on('click', '.js-remove-pool', () => openRemovePoolModal(store))
    .on('click', '.js-make-stake', event => openMakeStakeModal(event, store))
    .on('click', '.js-move-stake', event => openMoveStakeModal(event, store))

  initializeWeb3(store)
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

    $stakesTop.on('click', '[data-selector="login-button"]', loginByMetamask)
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
