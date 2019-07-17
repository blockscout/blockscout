import $ from 'jquery'
import _ from 'lodash'
import humps from 'humps'
import socket from '../socket'
import { connectElements } from '../lib/redux_helpers.js'
import { createAsyncLoadStore } from '../lib/async_listing_load'
import Web3 from 'web3'
// import { stat } from 'fs';

export const initialState = {
  web3: null,
  blocksCount: null,
  tokenSymbol: null
}

let mkAction = (type, payload = {}) => ({type, ...payload})

let pageLoad = () => mkAction('PAGE_LOAD')
// let elementsLoad = (payload) => mkAction('ELEMENTS_LOAD', payload)
let web3Detected = (web3) => mkAction('WEB3_DETECTED', {web3})
let updateContract = (abi, address) => mkAction('UPDATE_CONTRACT', {abi, address})
let authorised = (account) => mkAction('AUTHORIZED', {account})
let updateUser = (user) => mkAction('UPDATE_USER', {user})
let initCounters = (payload) => mkAction('INIT_COUNTERS', payload)
let receivedNewBlock = (msg) => mkAction('RECEIVED_NEW_BLOCK', {msg})
let receivedNewEpoch = (msg) => mkAction('RECEIVED_NEW_EPOCH', {msg})
let itemsFetched = (response) => mkAction('ITEMS_FETCHED', {response})
let requestError = () => mkAction('REQUEST_ERROR')
let finishRequest = () => mkAction('FINISH_REQUEST')

let detectedWeb3 = async (web3) => {
  store.dispatch(web3Detected(web3))
  let response = await $.getJSON('/staking_contract')
  store.dispatch(updateContract(response.abi, response.address))
}

let afterAuthorise = async (address) => {
  const current = store.getState().account

  if (current !== address) {
    store.dispatch(authorised(address))

    let response = await $.getJSON('/set_session', {address})
    if (response.success) {
      getUser()
    }
  }
}

let getUser = async () => {
  let address = store.getState().account
  let response = await $.getJSON('/delegator', {address})

  store.dispatch(updateUser(response.delegator))
}

let initialiseCounters = () => {
  const epochNumber = parseInt($('[data-selector="epoch-number"]').text())
  const epochEndIn = parseInt($('[data-selector="epoch-end-in"]').text())
  const blocksCount = parseInt($('[data-selector="block-number"]').text())

  store.dispatch(initCounters({epochNumber, epochEndIn, blocksCount}))
}

let reloadPoolsList = async () => {
  let path = store.getState().path
  try {
    let response = await $.getJSON(path, {type: 'JSON'})
    store.dispatch(itemsFetched(humps.camelizeKeys(response)))
  } catch (_) {
    store.dispatch(requestError())
  } finally {
    store.dispatch(finishRequest())
  }
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
      return state

    case 'ELEMENTS_LOAD':
      return Object.assign({}, state, _.omit(action, 'type'))

    case 'WEB3_DETECTED':
      return Object.assign({}, state, { web3: action.web3 })

    case 'UPDATE_CONTRACT':
      const stakingContract = new state.web3.eth.Contract(action.abi, action.address)
      return Object.assign({}, state, { stakingContract: stakingContract })

    case 'AUTHORIZED':
      return Object.assign({}, state, { account: action.account })

    case 'UPDATE_USER':
      return Object.assign({}, state, { user: action.user })

    case 'INIT_COUNTERS':
      return Object.assign({}, state, {
        epochNumber: action.epochNumber,
        epochEndIn: action.epochEndIn,
        blocksCount: action.blocksCount
      })

    case 'RECEIVED_NEW_BLOCK': {
      const blocksCount = action.msg.blockNumber
      const epochEndBlock = state.blocksCount + state.epochEndIn
      const epochEndIn = epochEndBlock - blocksCount

      return Object.assign({}, state, {blocksCount, epochEndIn})
    }

    case 'RECEIVED_NEW_EPOCH': {
      const epochNumber = action.msg.epochNumber
      const epochEndBlock = action.msg.epochEndBlock
      const epochEndIn = epochEndBlock - state.blocksCount

      return Object.assign({}, state, {epochNumber, epochEndIn})
    }

    default:
      console.error(`Unknown message type sent to reducer: ${action && action.type}`)
      return state
  }
}

const elements = {
  '[data-selector="login-button"]': {
    load ($el) {
      $el.on('click', redirectToMetamask)
    },

    render ($el, state, oldState) {
      if (oldState.web3 === state.web3) return
      if (state.web3) {
        $el.unbind('click')
        $el.on('click', loginByMetamask)
      } else {
        $el.unbind('click')
        $el.on('click', redirectToMetamask)
      }
    }
  },

  '[data-async-load]': {
    load ($el) {
      return {
        path: $el.data('async-listing')
      }
    }
  },

  '[data-selector="stakes-top"]': {
    load (_el) {
      initialiseCounters()
    },

    render: async ($el, state, oldState) => {
      if (state.user === oldState.user) return

      let response = await $.getJSON(state.path, {type: 'JSON', template: 'top'})

      $el.html(response.content)

      $('.js-become-candidate').on('click', window.openBecomeCandidateModal)
      $('.js-remove-pool').on('click', window.openRemovePoolModal)

      if (state.web3) {
        if (!state.user) {
          $('[data-selector="login-button"]').on('click', loginByMetamask)
        }
      } else {
        $('[data-selector="login-button"]').on('click', redirectToMetamask)
      }

      initialiseCounters()
    }
  },

  '[data-selector="block-number"]': {
    render ($el, state, oldState) {
      if (state.blocksCount === oldState.blocksCount) return
      $el.text(state.blocksCount)
    }
  },

  '[data-selector="epoch-number"]': {
    render ($el, state, oldState) {
      if (state.epochNumber === oldState.epochNumber) return
      $el.text(state.epochNumber)
    }
  },

  '[data-selector="epoch-end-in"]': {
    render ($el, state, oldState) {
      if (state.epochEndIn === oldState.epochEndIn) return
      $el.text(`${state.epochEndIn}`)
    }
  },

  '[data-page="stakes"]': {
    load ($el) {
      return { tokenSymbol: $el.data('token-symbol') }
    }
  }
}

export var store

const $stakesPage = $('[data-page="stakes"]')

if ($stakesPage.length) {
  store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierPool')
  connectElements({ store, elements })

  store.dispatch(pageLoad())

  const blocksChannel = socket.channel(`blocks:new_block`)

  blocksChannel.join()
  blocksChannel.on('new_block', msg => {
    store.dispatch(receivedNewBlock(humps.camelizeKeys(msg)))
  })

  const epochChannel = socket.channel(`staking_epoch:new_epoch`)

  epochChannel.join()
  epochChannel.on('new_epoch', msg => {
    store.dispatch(receivedNewEpoch(humps.camelizeKeys(msg)))
  })

  getWeb3()
}

function getWeb3 () {
  if (window.ethereum) {
    let web3 = new Web3(window.ethereum)

    console.log('Injected web3 detected.')

    setInterval(async function () {
      let accounts = await web3.eth.getAccounts()

      var defaultAccount = accounts[0]
      if (defaultAccount !== store.getState().account) {
        afterAuthorise(defaultAccount)
      }
    }, 100)

    detectedWeb3(web3)

    const sessionAcc = $('[data-page="stakes"]').data('user-address')

    if (sessionAcc) {
      afterAuthorise(sessionAcc)
    }
  }
}

function redirectToMetamask () {
  var win = window.open('https://metamask.io', '_blank')
  win.focus()
}

async function loginByMetamask () {
  try {
    await window.ethereum.enable()

    const accounts = await store.getState().web3.eth.getAccounts()
    const defaultAccount = accounts[0]

    afterAuthorise(defaultAccount)
  } catch (e) {
    console.log(e)
    console.error('User denied account access')
  }
}
