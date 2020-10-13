import $ from 'jquery'
import omit from 'lodash/omit'
import humps from 'humps'
import { connectElements } from '../../lib/redux_helpers.js'
import { createAsyncLoadStore } from '../../lib/async_listing_load'
import '../address'

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
  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierLog')
  const addressHash = $('[data-page="address-details"]')[0].dataset.pageAddressHash
  const $element = $('[data-async-listing]')

  connectElements({ store, elements })

  store.dispatch({
    type: 'PAGE_LOAD',
    addressHash: addressHash
  })

  $element.on('click', '[data-search-button]', (_event) => {
    store.dispatch({
      type: 'START_SEARCH',
      addressHash: addressHash
    })
    const topic = $('[data-search-field]').val()
    const addressHashPlain = store.getState().addressHash
    const addressHashChecksum = addressHashPlain && window.web3.toChecksumAddress(addressHashPlain)
    const path = '/search-logs?topic=' + topic + '&address_id=' + addressHashChecksum
    store.dispatch({ type: 'START_REQUEST' })
    $.getJSON(path, { type: 'JSON' })
      .done(response => store.dispatch(Object.assign({ type: 'ITEMS_FETCHED' }, humps.camelizeKeys(response))))
      .fail(() => store.dispatch({ type: 'REQUEST_ERROR' }))
      .always(() => store.dispatch({ type: 'FINISH_REQUEST' }))
  })

  $element.on('click', '[data-cancel-search-button]', (_event) => {
    window.location.replace(window.location.href.split('?')[0])
  })
}
