import $ from 'jquery'
import humps from 'humps'
import socket from '../socket'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import Web3 from 'web3'

export const initialState = {
  web3: null,
  blocksCount: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'WEB3_DETECTED': {
      return Object.assign({}, state, { web3: action.web3 })
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
        accountPath: $el.data('async-listing')
      }
    }
  },
  '[data-selector="stakes-top"]': {
    render ($el, state, oldState) {
      if (state.user === oldState.user) return
      $.getJSON(state.accountPath, {type: 'JSON', template: 'top'})
        .done(response => {
          $el.html(response.content)
          if (!state.user && state.web3) {
            $('[data-selector="login-button"]').on('click', loginByMetamask)
          }
          if (!state.web3) {
            $('[data-selector="login-button"]').on('click', redirectToMetamask)
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
