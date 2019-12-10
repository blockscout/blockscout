import '../../css/stakes.scss'

import $ from 'jquery'
import _ from 'lodash'
import { subscribeChannel } from '../socket'
import { connectElements } from '../lib/redux_helpers.js'
import { createAsyncLoadStore, refreshPage } from '../lib/async_listing_load'
import Web3 from 'web3'
import { openPoolInfoModal } from './stakes/validator_info'
import { openDelegatorsListModal } from './stakes/delegators_list'
import { openBecomeCandidateModal } from './stakes/become_candidate'
import { openRemovePoolModal } from './stakes/remove_pool'
import { openMakeStakeModal } from './stakes/make_stake'
import { openMoveStakeModal } from './stakes/move_stake'
import { openWithdrawStakeModal } from './stakes/withdraw_stake'
import { openClaimRewardModal } from './stakes/claim_reward'
import { openClaimWithdrawalModal } from './stakes/claim_withdrawal'
import { checkForTokenDefinition } from './stakes/utils'
import { openWarningModal } from '../lib/modals'

const stakesPageSelector = '[data-page="stakes"]'

export const initialState = {
  account: null,
  blockRewardContract: null,
  channel: null,
  lastBlockNumber: 0,
  lastEpochNumber: 0,
  network: null,
  refreshInterval: null,
  stakingAllowed: false,
  stakingTokenDefined: false,
  stakingContract: null,
  tokenDecimals: 0,
  tokenSymbol: '',
  validatorSetApplyBlock: 0,
  web3: null
}

// 100 - id of xDai network, 101 - id of xDai test network
export const allowedNetworkIds = [100, 101]

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
        additionalParams: Object.assign({}, state.additionalParams, {
          account: action.account
        })
      })
    }
    case 'NETWORK_UPDATED': {
      return Object.assign({}, state, {
        network: action.network,
        additionalParams: Object.assign({}, state.additionalParams, {
          network: action.network
        })
      })
    }
    case 'FILTERS_UPDATED': {
      return Object.assign({}, state, {
        additionalParams: Object.assign({}, state.additionalParams, {
          filterBanned: action.filterBanned,
          filterMy: action.filterMy
        })
      })
    }
    case 'RECEIVED_UPDATE': {
      return Object.assign({}, state, {
        lastBlockNumber: action.lastBlockNumber,
        lastEpochNumber: action.lastEpochNumber,
        stakingAllowed: action.stakingAllowed,
        stakingTokenDefined: action.stakingTokenDefined,
        validatorSetApplyBlock: action.validatorSetApplyBlock
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
    case 'FINISH_REQUEST': {
      $(stakesPageSelector).fadeTo(0, 1)
      return state
    }
    default:
      return state
  }
}

function reloadPoolList(msg, store) {
  store.dispatch({
    type: 'RECEIVED_UPDATE',
    lastBlockNumber: msg.block_number,
    lastEpochNumber: msg.epoch_number,
    stakingAllowed: msg.staking_allowed,
    stakingTokenDefined: msg.staking_token_defined,
    validatorSetApplyBlock: msg.validator_set_apply_block
  })
  refreshPage(store)
}

const elements = {
  '[data-page="stakes"]': {
    load ($el) {
      return {
        refreshInterval: $el.data('refresh-interval') || null,
        additionalParams: {
          filterBanned: $el.find('[pool-filter-banned]').prop('checked'),
          filterMy: $el.find('[pool-filter-my]').prop('checked')
        }
      }
    }
  }
}

const $stakesPage = $(stakesPageSelector)
const $stakesTop = $('[data-selector="stakes-top"]')
if ($stakesPage.length) {
  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierPool')
  connectElements({ store, elements })

  const channel = subscribeChannel('stakes:staking_update')
  store.dispatch({ type: 'CHANNEL_CONNECTED', channel })

  const $refreshInformer = $('.refresh-informer', $stakesPage)

  channel.on('staking_update', msg => {
    // hide tooltip on tooltip triggering element reloading
    // due to issues with bootstrap tooltips https://github.com/twbs/bootstrap/issues/13133
    const stakesTopTooltipID = $('[aria-describedby]', $stakesTop).attr('aria-describedby')
    $('#' + stakesTopTooltipID).hide()

    $stakesTop.html(msg.top_html)

    const state = store.getState()

    if (!state.account) {
      $stakesPage.find('[pool-filter-my]').prop('checked', false);
    }

    let lastBlockNumber = state.lastBlockNumber

    if (
      msg.staking_allowed !== state.stakingAllowed ||
      msg.epoch_number > state.lastEpochNumber ||
      msg.validator_set_apply_block != state.validatorSetApplyBlock ||
      (state.refreshInterval && msg.block_number >= state.lastBlockNumber + state.refreshInterval)
    ) {
      reloadPoolList(msg, store)
      lastBlockNumber = msg.block_number
    }

    const refreshGap = msg.block_number - lastBlockNumber
    $refreshInformer.find('span').html(refreshGap)
    if (refreshGap > 0) {
      $refreshInformer.show()
    } else {
      $refreshInformer.hide()
    }

    const $refreshInformerLink = $refreshInformer.find('a')
    $refreshInformerLink.off('click')
    $refreshInformerLink.on('click', (event) => {
      event.preventDefault()
      $refreshInformer.hide()
      $stakesPage.fadeTo(0, 0.5)
      reloadPoolList(msg, store)
    })
  })

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
    .on('click', '.js-pool-info', event => {
      if (checkForTokenDefinition(store)) {
        openPoolInfoModal(event, store)
      }
    })
    .on('click', '.js-delegators-list', event => {
      openDelegatorsListModal(event, store)
    })
    .on('click', '.js-become-candidate', () => {
      if (checkForTokenDefinition(store)) {
        openBecomeCandidateModal(store)
      }
    })
    .on('click', '.js-remove-pool', () => {
      openRemovePoolModal(store)
    })
    .on('click', '.js-make-stake', event => {
      if (checkForTokenDefinition(store)) {
        openMakeStakeModal(event, store)
      }
    })
    .on('click', '.js-move-stake', event => {
      if (checkForTokenDefinition(store)) {
        openMoveStakeModal(event, store)
      }
    })
    .on('click', '.js-withdraw-stake', event => {
      if (checkForTokenDefinition(store)) {
        openWithdrawStakeModal(event, store)
      }
    })
    .on('click', '.js-claim-reward', () => {
      if (checkForTokenDefinition(store)) {
        openClaimRewardModal(store)
      }
    })
    .on('click', '.js-claim-withdrawal', event => {
      if (checkForTokenDefinition(store)) {
        openClaimWithdrawalModal(event, store)
      }
    })

  $stakesPage
    .on('change', '[pool-filter-banned]', () => updateFilters(store, 'banned'))
    .on('change', '[pool-filter-my]', () => updateFilters(store, 'my'))

  initializeWeb3(store)
}

function updateFilters (store, filterType) {
  const filterBanned = $stakesPage.find('[pool-filter-banned]');
  const filterMy = $stakesPage.find('[pool-filter-my]');
  if (filterType == 'my' && !store.getState().account) {
    filterMy.prop('checked', false);
    openWarningModal('Unauthorized', 'Please login with MetaMask')
    return
  }
  store.dispatch({
    type: 'FILTERS_UPDATED',
    filterBanned: filterBanned.prop('checked'),
    filterMy: filterMy.prop('checked')
  })
  refreshPage(store)
}

function initializeWeb3 (store) {
  if (window.ethereum) {
    const web3 = new Web3(window.ethereum)
    store.dispatch({ type: 'WEB3_DETECTED', web3 })

    setInterval(async function () {
      const networkId = await web3.eth.net.getId()
      if (!store.getState().network || (networkId !== store.getState().network.id)) {
        setNetwork(networkId, store)
      }

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

function setNetwork (networkId, store) {
  let network = {
    id: networkId,
    authorized: false
  }

  if (allowedNetworkIds.includes(networkId)) {
    network.authorized = true
  } else {
    openWarningModal('Unauthorized', 'Connect to the xDai Chain for staking.<br /> <a href="https://docs.xdaichain.com" target="_blank">Instructions</a>')
  }

  store.dispatch({ type: 'NETWORK_UPDATED', network })
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
