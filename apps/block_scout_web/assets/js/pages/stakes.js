import '../../css/stakes.scss'

import $ from 'jquery'
import _ from 'lodash'
import { subscribeChannel } from '../socket'
import { connectElements } from '../lib/redux_helpers.js'
import { createAsyncLoadStore, refreshPage } from '../lib/async_listing_load'
import Queue from '../lib/queue'
import Web3 from 'web3'
import { openPoolInfoModal } from './stakes/validator_info'
import { openDelegatorsListModal } from './stakes/delegators_list'
import { openBecomeCandidateModal, becomeCandidateConnectionLost } from './stakes/become_candidate'
import { openRemovePoolModal } from './stakes/remove_pool'
import { openMakeStakeModal } from './stakes/make_stake'
import { openMoveStakeModal } from './stakes/move_stake'
import { openWithdrawStakeModal } from './stakes/withdraw_stake'
import { openClaimRewardModal, claimRewardConnectionLost } from './stakes/claim_reward'
import { openClaimWithdrawalModal } from './stakes/claim_withdrawal'
import { checkForTokenDefinition, isSupportedNetwork } from './stakes/utils'
import { currentModal, openWarningModal, openErrorModal } from '../lib/modals'
import constants from './stakes/constants'

const stakesPageSelector = '[data-page="stakes"]'

export const initialState = {
  account: null,
  blockRewardContract: null,
  channel: null,
  currentBlockNumber: 0, // current block number
  finishRequestResolve: null,
  lastEpochNumber: 0,
  loading: true,
  network: null,
  refreshBlockNumber: 0, // last page refresh block number
  refreshInterval: null,
  refreshPageFunc: refreshPageWrapper,
  stakingAllowed: false,
  stakingTokenDefined: false,
  stakingContract: null,
  tokenContract: null,
  tokenDecimals: 0,
  tokenSymbol: '',
  validatorSetApplyBlock: 0,
  validatorSetContract: null,
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
        refreshBlockNumber: action.refreshBlockNumber,
        finishRequestResolve: action.finishRequestResolve
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
        validatorSetContract: action.validatorSetContract,
        tokenContract: action.tokenContract,
        tokenDecimals: action.tokenDecimals,
        tokenSymbol: action.tokenSymbol
      })
    }
    case 'FINISH_REQUEST': {
      $(stakesPageSelector).fadeTo(0, 1)
      if (state.finishRequestResolve) {
        state.finishRequestResolve()
        return Object.assign({}, state, {
          finishRequestResolve: null
        })
      }
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

  let updating = false

  async function onStakingUpdate (msg) { // eslint-disable-line no-inner-declarations
    const state = store.getState()

    if (state.finishRequestResolve || updating) {
      return
    }
    updating = true

    store.dispatch({ type: 'BLOCK_CREATED', currentBlockNumber: msg.block_number })

    // hide tooltip on tooltip triggering element reloading
    // due to issues with bootstrap tooltips https://github.com/twbs/bootstrap/issues/13133
    const stakesTopTooltipID = $('[aria-describedby]', $stakesTop).attr('aria-describedby')
    $('#' + stakesTopTooltipID).hide()

    $stakesTop.html(msg.top_html)

    if (accountChanged(msg.account, state)) {
      store.dispatch({ type: 'ACCOUNT_UPDATED', account: msg.account })
      resetFilterMy(store)
    }

    if (
      msg.staking_allowed !== state.stakingAllowed ||
      msg.epoch_number > state.lastEpochNumber ||
      msg.validator_set_apply_block !== state.validatorSetApplyBlock ||
      (state.refreshInterval && msg.block_number >= state.refreshBlockNumber + state.refreshInterval) ||
      accountChanged(msg.account, state) ||
      msg.by_set_account
    ) {
      await reloadPoolList(msg, store)
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
    $refreshInformerLink.on('click', async (event) => {
      event.preventDefault()
      if (!store.getState().finishRequestResolve) {
        $refreshInformer.hide()
        $stakesPage.fadeTo(0, 0.5)
        await reloadPoolList(msg, store)
      }
    })

    updating = false
  }

  const messagesQueue = new Queue()

  setTimeout(async () => {
    while (true) {
      const msg = messagesQueue.dequeue()
      if (msg) {
        // Synchronously handle the message
        await onStakingUpdate(msg)
      } else {
        // Wait for the next message
        await new Promise(resolve => setTimeout(resolve, 10))
      }
    }
  }, 0)

  channel.on('staking_update', msg => {
    messagesQueue.enqueue(msg)
  })

  channel.on('contracts', msg => {
    const web3 = store.getState().web3
    const stakingContract =
      new web3.eth.Contract(msg.staking_contract.abi, msg.staking_contract.address)
    const blockRewardContract =
      new web3.eth.Contract(msg.block_reward_contract.abi, msg.block_reward_contract.address)
    const validatorSetContract =
      new web3.eth.Contract(msg.validator_set_contract.abi, msg.validator_set_contract.address)
    const tokenContract =
      new web3.eth.Contract(msg.token_contract.abi, msg.token_contract.address)

    store.dispatch({
      type: 'RECEIVED_CONTRACTS',
      stakingContract,
      blockRewardContract,
      validatorSetContract,
      tokenContract,
      tokenDecimals: parseInt(msg.token_decimals, 10),
      tokenSymbol: msg.token_symbol
    })
  })

  channel.onError(becomeCandidateConnectionLost)
  channel.onError(claimRewardConnectionLost)

  $(document.body)
    .on('click', '.js-pool-info', event => {
      if (checkForTokenDefinition(store)) {
        openPoolInfoModal(event, store)
      }
    })
    .on('click', '.js-delegators-list', event => {
      openDelegatorsListModal(event, store)
    })
    .on('click', '.js-become-candidate', event => {
      if (checkForTokenDefinition(store)) {
        openBecomeCandidateModal(event, store)
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

function accountChanged (account, state) {
  return account !== state.account
}

async function getAccounts () {
  let accounts = []
  try {
    accounts = await window.ethereum.request({ method: 'eth_accounts' })
  } catch (e) {
    console.error(`eth_accounts request failed. ${constants.METAMASK_VERSION_WARNING}`)
    openErrorModal('Get account', `Cannot get your account address. ${constants.METAMASK_VERSION_WARNING}`)
  }
  return accounts
}

async function getNetId (web3) {
  let netId = null
  if (!window.ethereum.chainId) {
    console.error(`Cannot get chainId. ${constants.METAMASK_VERSION_WARNING}`)
  } else {
    const { chainId } = window.ethereum
    netId = web3.utils.isHex(chainId) ? web3.utils.hexToNumber(chainId) : chainId
  }
  return netId
}

function hideCurrentModal () {
  const $modal = currentModal()
  if ($modal) $modal.modal('hide')
}

function initialize (store) {
  if (window.ethereum) {
    const web3 = new Web3(window.ethereum)
    if (window.ethereum.autoRefreshOnNetworkChange) {
      window.ethereum.autoRefreshOnNetworkChange = false
    }
    store.dispatch({ type: 'WEB3_DETECTED', web3 })

    initNetworkAndAccount(store, web3)

    window.ethereum.on('chainChanged', async (chainId) => {
      const newNetId = web3.utils.isHex(chainId) ? web3.utils.hexToNumber(chainId) : chainId
      setNetwork(newNetId, store, true)
    })

    window.ethereum.on('accountsChanged', async (accs) => {
      const newAccount = accs && accs.length > 0 ? accs[0].toLowerCase() : null
      if (accountChanged(newAccount, store.getState())) {
        await setAccount(newAccount, store)
      }
    })

    $stakesTop.on('click', '[data-selector="login-button"]', loginByMetamask)
  } else {
    // We do the first load immediately if the latest version of MetaMask is not installed
    refreshPageWrapper(store)
  }
}

async function initNetworkAndAccount (store, web3) {
  const state = store.getState()
  const networkId = await getNetId(web3)

  if (!state.network || (networkId !== state.network.id)) {
    setNetwork(networkId, store, false)
  }

  const accounts = await getAccounts()
  const account = accounts[0] ? accounts[0].toLowerCase() : null

  if (accountChanged(account, state)) {
    await setAccount(account, store)
    // We don't call `refreshPageWrapper` in this case because it will be called
    // by the `onStakingUpdate` function
  } else {
    await refreshPageWrapper(store)
  }
}

async function loginByMetamask () {
  event.stopPropagation()
  event.preventDefault()
  try {
    await window.ethereum.request({ method: 'eth_requestAccounts' })
  } catch (e) {
    console.log(e)
    if (e.code !== 4001) {
      console.error(`eth_requestAccounts failed. ${constants.METAMASK_VERSION_WARNING}`)
      openErrorModal(`Request account access', 'Cannot request access to your account in MetaMask. ${constants.METAMASK_VERSION_WARNING}`)
    }
  }
}

async function refreshPageWrapper (store) {
  while (store.getState().finishRequestResolve) {
    // Don't let anything simultaneously refresh the page
    await new Promise(resolve => setTimeout(resolve, 10))
  }

  let currentBlockNumber = store.getState().currentBlockNumber
  if (!currentBlockNumber) {
    currentBlockNumber = $('[data-block-number]', $stakesTop).data('blockNumber')
  }

  await new Promise(resolve => {
    store.dispatch({
      type: 'PAGE_REFRESHED',
      refreshBlockNumber: currentBlockNumber,
      finishRequestResolve: resolve
    })
    $refreshInformer.hide()
    refreshPage(store)
  })
}

async function reloadPoolList (msg, store) {
  store.dispatch({
    type: 'RECEIVED_UPDATE',
    lastEpochNumber: msg.epoch_number,
    stakingAllowed: msg.staking_allowed,
    stakingTokenDefined: msg.staking_token_defined,
    validatorSetApplyBlock: msg.validator_set_apply_block
  })
  await refreshPageWrapper(store)
}

function resetFilterMy (store) {
  $stakesPage.find('[pool-filter-my]').prop('checked', false)
  store.dispatch({ type: 'FILTERS_UPDATED', filterMy: false })
}

function setAccount (account, store) {
  return new Promise(resolve => {
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
      if (account) {
        $addressField.html(`
          <div data-placement="bottom" data-toggle="tooltip" title="${account}">
            ${account}
          </div>
        `)
      }
      hideCurrentModal()
      resolve(true)
    }).receive('error', () => {
      openErrorModal('Change account', errorMsg, true)
      resolve(false)
    }).receive('timeout', () => {
      openErrorModal('Change account', errorMsg, true)
      resolve(false)
    })
  })
}

function setNetwork (networkId, store, checkSupportedNetwork) {
  hideCurrentModal()

  const network = {
    id: networkId,
    authorized: false
  }

  if (allowedNetworkIds.includes(networkId)) {
    network.authorized = true
  }

  store.dispatch({ type: 'NETWORK_UPDATED', network })

  if (checkSupportedNetwork) {
    isSupportedNetwork(store)
  }
}

function updateFilters (store, filterType) {
  const filterBanned = $stakesPage.find('[pool-filter-banned]')
  const filterMy = $stakesPage.find('[pool-filter-my]')
  const state = store.getState()

  if (state.finishRequestResolve) {
    if (filterType === 'my') {
      filterMy.prop('checked', !filterMy.prop('checked'))
    } else {
      filterBanned.prop('checked', !filterBanned.prop('checked'))
    }
    openWarningModal('Still loading', 'The previous request to load pool list is not yet finished. Please, wait...')
    return
  }

  if (filterType === 'my' && !state.account) {
    filterMy.prop('checked', false)
    openWarningModal('Unauthorized', constants.METAMASK_PLEASE_LOGIN)
    return
  }
  store.dispatch({
    type: 'FILTERS_UPDATED',
    filterBanned: filterBanned.prop('checked'),
    filterMy: filterMy.prop('checked')
  })
  refreshPageWrapper(store)
}
