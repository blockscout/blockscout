import $ from 'jquery'
import omit from 'lodash.omit'
import { connectElements } from '../../lib/redux_helpers.js'
import { createAsyncLoadStore, loadPage } from '../../lib/async_listing_load'
import '../address'
import { utils } from 'web3'

export const initialState = {
  addressHash: null,
  isSearch: false
}

export function reducer (state, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'START_SEARCH': {
      return Object.assign({}, state, { pagesStack: [], isSearch: true })
    }
    default:
      return state
  }
}

const elements = {
  '[data-search-field]': {
    render ($el, state) {
      return $el
    }
  },
  '[data-search-button]': {
    render ($el, state) {
      return $el
    }
  },
  '[data-cancel-search-button]': {
    render ($el, state) {
      if (!state.isSearch) {
        return $el.hide()
      }

      return $el.show()
    }
  },
  '[data-search]': {
    render ($el, state) {
      if (state.emptyResponse && !state.isSearch) {
        return $el.hide()
      }

      return $el.show()
    }
  }
}

if ($('[data-page="address-logs"]').length) {
  let timer
  const waitTime = 500

  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierLog')
  const addressHash = $('[data-page="address-details"]')[0].dataset.pageAddressHash
  const $element = $('[data-async-listing]')

  connectElements({ store, elements })

  const searchFunc = (_event) => {
    store.dispatch({
      type: 'START_SEARCH',
      addressHash
    })
    const topic = $('[data-search-field]').val()
    const addressHashPlain = store.getState().addressHash
    const addressHashChecksum = addressHashPlain && utils.toChecksumAddress(addressHashPlain)
    const path = `${process.env.NETWORK_PATH}/search-logs?topic=${topic}&address_id=${addressHashChecksum}`
    loadPage(store, path)
  }

  store.dispatch({
    type: 'PAGE_LOAD',
    addressHash
  })

  $element.on('click', '[data-search-button]', searchFunc)

  $element.on('click', '[data-cancel-search-button]', (_event) => {
    $('[data-search-field]').val('')
    loadPage(store, window.location.pathname)
  })

  $element.on('input keyup', '[data-search-field]', (event) => {
    if (event.type === 'input') {
      clearTimeout(timer)
      timer = setTimeout(() => {
        searchFunc(event)
      }, waitTime)
    }
    if (event.type === 'keyup' && event.keyCode === 13) {
      clearTimeout(timer)
      searchFunc(event)
    }
  })
}
