import $ from 'jquery'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import Web3 from 'web3'

export const initialState = {
  web3: null,
  user: null,
  controllerPath: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'WEB3_DETECTED': {
      return Object.assign({}, state, { web3: action.web3 })
    }
    case 'UPDATE_USER': {
      return Object.assign({}, state, { user: action.user })
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
      $el.unbind('click')
      $el.on('click', state.web3 ? loginByMetamask : redirectToMetamask)
    }
  },
  '[data-async-load]': {
    load ($el) {
      return {
        controllerPath: $el.data('async-listing')
      }
    }
  },
  '[data-selector="stakes-top"]': {
    render ($el, state, oldState) {
      if (state.user === oldState.user) return
      $.getJSON(state.controllerPath, {type: 'JSON', template: 'top'})
        .done(response => {
          $el.html(response.content)
          if (!state.user) {
            $('[data-selector="login-button"]')
              .on('click', state.web3 ? loginByMetamask : redirectToMetamask)
          }
        })
    }
  }
}

export var store

const $stakesPage = $('[data-page="stakes"]')
if ($stakesPage.length) {
  store = createStore(reducer)
  connectElements({ store, elements })

  initializeWeb3()
}

function initializeWeb3 () {
  if (window.ethereum) {
    let web3 = new Web3(window.ethereum)
    console.log('Injected web3 detected.')

    setInterval(function () {
      web3.eth.getAccounts()
        .then(accounts => {
          var defaultAccount = accounts[0] || ''
          var currentUser = store.getState().user ? store.getState().user.address : ''
          if (defaultAccount.toLowerCase() !== currentUser.toLowerCase()) {
            login(defaultAccount)
          }
        })
    }, 100)

    store.dispatch({ type: 'WEB3_DETECTED', web3: web3 })

    const sessionAcc = $('.stakes-top-stats-item-address').data('user-address')
    if (sessionAcc) {
      login(sessionAcc)
    }
  }
}

async function login (address) {
  let response = await $.getJSON('/set_session', { address: address })
  store.dispatch({
    type: 'UPDATE_USER',
    user: response.user
  })
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
    login(defaultAccount)
  } catch (e) {
    console.log(e)
    console.error('User denied account access')
  }
}
