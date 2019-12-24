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
import { openClaimRewardModal, connectionLost } from './stakes/claim_reward'
import { openClaimWithdrawalModal } from './stakes/claim_withdrawal'
import { checkForTokenDefinition } from './stakes/utils'
import { openWarningModal, openErrorModal } from '../lib/modals'

const stakesPageSelector = '[data-page="stakes"]'

export const initialState = {
  account: null,
  blockRewardContract: null,
  channel: null,
  currentBlockNumber: 0, // current block number
  lastEpochNumber: 0,
  network: null,
  refreshBlockNumber: 0, // last page refresh block number
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
    case 'BLOCK_CREATED': {
      return Object.assign({}, state, {
        currentBlockNumber: action.currentBlockNumber
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
          filterBanned: 'filterBanned' in action ? action.filterBanned : state.additionalParams.filterBanned,
          filterMy: 'filterMy' in action ? action.filterMy : state.additionalParams.filterMy
        })
      })
    }
    case 'PAGE_REFRESHED': {
      return Object.assign({}, state, {
        refreshBlockNumber: action.refreshBlockNumber
      })
    }
    case 'RECEIVED_UPDATE': {
      return Object.assign({}, state, {
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
const $refreshInformer = $('.refresh-informer', $stakesPage)
if ($stakesPage.length) {
  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierPool')
  connectElements({ store, elements })

  const channel = subscribeChannel('stakes:staking_update')
  store.dispatch({ type: 'CHANNEL_CONNECTED', channel })

  channel.on('staking_update', msg => {
    const state = store.getState()
    const firstMsg = (state.currentBlockNumber == 0)
    const accountChanged = (msg.account != state.account)

    store.dispatch({ type: 'BLOCK_CREATED', currentBlockNumber: msg.block_number })

    // hide tooltip on tooltip triggering element reloading
    // due to issues with bootstrap tooltips https://github.com/twbs/bootstrap/issues/13133
    const stakesTopTooltipID = $('[aria-describedby]', $stakesTop).attr('aria-describedby')
    $('#' + stakesTopTooltipID).hide()

    $stakesTop.html(msg.top_html)

    if (accountChanged) {
      store.dispatch({ type: 'ACCOUNT_UPDATED', account: msg.account })
      resetFilterMy(store)
    }

    if (
      msg.staking_allowed !== state.stakingAllowed ||
      msg.epoch_number > state.lastEpochNumber ||
      msg.validator_set_apply_block != state.validatorSetApplyBlock ||
      (state.refreshInterval && msg.block_number >= state.refreshBlockNumber + state.refreshInterval)
    ) {
      if (firstMsg || accountChanged) {
        // Don't refresh the page for the first load
        // as it is already refreshed by `initialize` function.
        // Also, don't refresh that after reconnect
        // as it is already refreshed by `setAccount` function.
        msg.dont_refresh_page = true
      }
      reloadPoolList(msg, store)
    }

    const refreshBlockNumber = store.getState().refreshBlockNumber
    const refreshGap = msg.block_number - refreshBlockNumber
    $refreshInformer.find('span').html(refreshGap)
    if (refreshGap > 0 && refreshBlockNumber > 0) {
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
      delete msg.dont_refresh_page // refresh anyway
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

  channel.onError(connectionLost)

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
    .on('click', '.js-claim-reward', event => {
      if (checkForTokenDefinition(store)) {
        openClaimRewardModal(event, store)
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

  initialize(store)
}

function initialize(store) {
  if (window.ethereum) {
    const web3 = new Web3(window.ethereum)
    store.dispatch({ type: 'WEB3_DETECTED', web3 })

    let timeoutId

    checkNetworkAndAccount()

    async function checkNetworkAndAccount() {
      const networkId = await web3.eth.net.getId()
      const state = store.getState()
      let refresh = false

      if (!state.network || (networkId !== state.network.id)) {
        setNetwork(networkId, store)
        refresh = true
      }

      const accounts = await web3.eth.getAccounts()
      const account = accounts[0] ? accounts[0].toLowerCase() : null

      if (account !== state.account) {
        setAccount(account, store)
      } else if (refresh) {
        refreshPageWrapper(store)
      }

      clearTimeout(timeoutId)
      timeoutId = setTimeout(checkNetworkAndAccount, 100)
    }

    $stakesTop.on('click', '[data-selector="login-button"]', loginByMetamask)
  } else {
    refreshPageWrapper(store)
  }
}

async function loginByMetamask() {
  event.stopPropagation()
  event.preventDefault()
  try {
    await window.ethereum.enable()
  } catch (e) {
    console.log(e)
    console.error('User denied account access')
  }
}

function refreshPageWrapper(store) {
  let currentBlockNumber = store.getState().currentBlockNumber
  if (!currentBlockNumber) {
    currentBlockNumber = $('[data-block-number]', $stakesTop).data('blockNumber')
  }

  refreshPage(store)
  store.dispatch({
    type: 'PAGE_REFRESHED',
    refreshBlockNumber: currentBlockNumber
  })
  $refreshInformer.hide()
}

function reloadPoolList(msg, store) {
  store.dispatch({
    type: 'RECEIVED_UPDATE',
    lastEpochNumber: msg.epoch_number,
    stakingAllowed: msg.staking_allowed,
    stakingTokenDefined: msg.staking_token_defined,
    validatorSetApplyBlock: msg.validator_set_apply_block
  })
  if (!msg.dont_refresh_page) {
    refreshPageWrapper(store)
  }
}

function resetFilterMy(store) {
  $stakesPage.find('[pool-filter-my]').prop('checked', false);
  store.dispatch({ type: 'FILTERS_UPDATED', filterMy: false })
}

function setAccount(account, store) {
  store.dispatch({ type: 'ACCOUNT_UPDATED', account })
  if (!account) {
    resetFilterMy(store)
  }

  const errorMsg = 'Cannot properly set account due to connection loss. Please, reload the page.'
  const $addressField = $('.stakes-top-stats-item-address .stakes-top-stats-value')
  $addressField.html('Loading...')
  store.getState().channel.push(
    'set_account', account
  ).receive('ok', () => {
    $addressField.html(account)
    refreshPageWrapper(store)
  }).receive('error', () => {
    openErrorModal('Change account', errorMsg, true)
  }).receive('timeout', () => {
    openErrorModal('Change account', errorMsg, true)
  })
}

function setNetwork(networkId, store) {
  let network = {
    id: networkId,
    authorized: false
  }

  if (allowedNetworkIds.includes(networkId)) {
    network.authorized = true
  } else {
    openWarningModal('Unauthorized', 'Please, connect to the xDai Chain.<br /><a href="https://xdaichain.com" target="_blank">Instructions</a>')
  }

  store.dispatch({ type: 'NETWORK_UPDATED', network })
}

function updateFilters(store, filterType) {
  const filterBanned = $stakesPage.find('[pool-filter-banned]');
  const filterMy = $stakesPage.find('[pool-filter-my]');
  const state = store.getState()
  if (filterType == 'my' && !state.account) {
    filterMy.prop('checked', false);
    openWarningModal('Unauthorized', 'Please login with MetaMask')
    return
  }
  store.dispatch({
    type: 'FILTERS_UPDATED',
    filterBanned: filterBanned.prop('checked'),
    filterMy: filterMy.prop('checked')
  })
  refreshPageWrapper(store)
}
