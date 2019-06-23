import $ from 'jquery'
import _ from 'lodash'
import humps from 'humps'
import socket from '../socket'
import { connectElements } from '../lib/redux_helpers.js'
import { createAsyncLoadStore } from '../lib/async_listing_load'
import Web3 from 'web3'

export const initialState = {
  web3: null,
  blocksCount: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, _.omit(action, 'type'))
    }
    case 'WEB3_DETECTED': {
      $.getJSON('/staking_contract')
        .done(response => {
          store.dispatch({
            type: 'UPDATE_CONTRACT',
            abi: response.abi,
            address: response.address
          })
        })

      return Object.assign({}, state, { web3: action.web3 })
    }
    case 'UPDATE_CONTRACT': {
      const stakingContract = new state.web3.eth.Contract(action.abi, action.address)
      return Object.assign({}, state, { stakingContract: stakingContract })
    }
    case 'AUTHORIZED': {
      const a = state.account || null
      if ((a !== action.account)) {
        $.getJSON('/set_session', { address: action.account })
          .done(response => {
            if (response.success === true) {
              store.dispatch({ type: 'GET_USER' })
            }
          })
      }
      return Object.assign({}, state, { account: action.account })
    }
    case 'GET_USER': {
      $.getJSON('/delegator', {address: state.account})
        .done(response => {
          store.dispatch({ type: 'UPDATE_USER', user: response.delegator })
        })

      return state
    }
    case 'UPDATE_USER': {
      return Object.assign({}, state, { user: action.user })
    }
    case 'INIT_COUNTERS': {
      const epochNumber = parseInt($('[data-selector="epoch-number"]').text())
      const epochEndIn = parseInt($('[data-selector="epoch-end-in"]').text())
      const blocksCount = parseInt($('[data-selector="block-number"]').text())
      return Object.assign({}, state, {
        epochNumber: epochNumber,
        epochEndIn: epochEndIn,
        blocksCount: blocksCount
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      const blocksCount = action.msg.blockNumber
      const epochEndBlock = state.blocksCount + state.epochEndIn
      const newEpochEndIn = epochEndBlock - blocksCount
      return Object.assign({}, state, {
        blocksCount: blocksCount,
        epochEndIn: newEpochEndIn
      })
    }
    case 'RECEIVED_NEW_EPOCH': {
      const epochNumber = action.msg.epochNumber
      const epochEndBlock = action.msg.epochEndBlock
      const epochEndIn = epochEndBlock - state.blocksCount
      return Object.assign({}, state, {
        epochNumber: epochNumber,
        epochEndIn: epochEndIn
      })
    }
    case 'RELOAD_POOLS_LIST': {
      $.getJSON(state.path, {type: 'JSON'})
        .done(response => store.dispatch(Object.assign({type: 'ITEMS_FETCHED'}, humps.camelizeKeys(response))))
        .fail(() => store.dispatch({type: 'REQUEST_ERROR'}))
        .always(() => store.dispatch({type: 'FINISH_REQUEST'}))

      return state
    }
    default:
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
      store.dispatch({ type: 'INIT_COUNTERS' })
    },
    render ($el, state, oldState) {
      if (state.user === oldState.user) return
      $.getJSON(state.path, {type: 'JSON', template: 'top'})
        .done(response => {
          $el.html(response.content)
          $('.js-become-candidate').on('click', window.openBecomeCandidateModal)
          if (!state.user && state.web3) {
            $('[data-selector="login-button"]').on('click', loginByMetamask)
          }
          if (!state.web3) {
            $('[data-selector="login-button"]').on('click', redirectToMetamask)
          }
          store.dispatch({ type: 'INIT_COUNTERS' })
        })
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
  }
}

export var store

const $stakesPage = $('[data-page="stakes"]')
if ($stakesPage.length) {
  store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierPool')
  connectElements({ store, elements })

  store.dispatch({ type: 'PAGE_LOAD' })

  const blocksChannel = socket.channel(`blocks:new_block`)
  blocksChannel.join()
  blocksChannel.on('new_block', msg => {
    store.dispatch({
      type: 'RECEIVED_NEW_BLOCK',
      msg: humps.camelizeKeys(msg)
    })
  })

  const epochChannel = socket.channel(`staking_epoch:new_epoch`)
  epochChannel.join()
  epochChannel.on('new_epoch', msg => {
    store.dispatch({
      type: 'RECEIVED_NEW_EPOCH',
      msg: humps.camelizeKeys(msg)
    })
  })

  getWeb3()
}

function getWeb3 () {
  if (window.ethereum) {
    let web3 = new Web3(window.ethereum)
    console.log('Injected web3 detected.')

    setInterval(function () {
      web3.eth.getAccounts()
        .then(accounts => {
          var defaultAccount = accounts[0] || null
          if (defaultAccount !== store.getState().account) {
            store.dispatch({ type: 'AUTHORIZED', account: defaultAccount })
          }
        })
    }, 100)

    store.dispatch({ type: 'WEB3_DETECTED', web3: web3 })

    const sessionAcc = $('[data-page="stakes"]').data('user-address')
    if (sessionAcc) {
      store.dispatch({ type: 'AUTHORIZED', account: sessionAcc })
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

    const defaultAccount = accounts[0] || null
    store.dispatch({ type: 'AUTHORIZED', account: defaultAccount })
  } catch (e) {
    console.log(e)
    console.error('User denied account access')
  }
}
