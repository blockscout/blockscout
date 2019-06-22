import $ from 'jquery'
import humps from 'humps'
import socket from '../socket'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import Web3 from 'web3'

export const initialState = {
  web3: null,
  user: null,
  blocksCount: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'WEB3_DETECTED': {
      return Object.assign({}, state, { web3: action.web3 })
    }
    case 'UPDATE_USER': {
      return Object.assign({}, state, { user: action.user })
    }
    case 'RECEIVED_NEW_BLOCK': {
      const blocksCount = action.msg.blockNumber
      return Object.assign({}, state, { blocksCount: blocksCount })
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
  '[data-selector="stakes-top"]': {
    render ($el, state, oldState) {
      if (state.user === oldState.user) return

      let controllerPath = $('[data-async-load]').data('async-listing')
      $.getJSON(controllerPath, {type: 'JSON', template: 'top'})
        .done(response => {
          $el.html(response.content)
          if (!state.user) {
            $('[data-selector="login-button"]')
              .on('click', state.web3 ? loginByMetamask : redirectToMetamask)
          }
        })
    }
  },
  '[data-selector="block-number"]': {
    render ($el, state, oldState) {
      if (state.blocksCount === oldState.blocksCount) return
      $el.text(state.blocksCount)
    }
  }
}

export var store

const $stakesPage = $('[data-page="stakes"]')
if ($stakesPage.length) {
  store = createStore(reducer)
  connectElements({ store, elements })

  const blocksChannel = socket.channel(`blocks:new_block`)
  blocksChannel.join()
  blocksChannel.on('new_block', msg => {
    store.dispatch({ 
      type: 'RECEIVED_NEW_BLOCK',
      msg: humps.camelizeKeys(msg)
    })
  })

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
  let response = await $.post('/set_session', {
    address: address,
    _csrf_token: $('meta[name="csrf-token"]').attr('content')
  })

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

    const defaultAccount = accounts[0]
    login(defaultAccount)
  } catch (e) {
    console.log(e)
    console.error('User denied account access')
  }
}
