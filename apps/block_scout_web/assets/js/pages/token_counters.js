import $ from 'jquery'
import omit from 'lodash.omit'
import humps from 'humps'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import { createAsyncLoadStore } from '../lib/async_listing_load'
import '../app'
import {
  openQrModal
} from '../lib/modals'

import './token/add_to_mm'
import './token/swap'

export const initialState = {
  channelDisconnected: false,
  transferCount: null,
  tokenHolderCount: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'COUNTERS_FETCHED': {
      return Object.assign({}, state, {
        transferCount: action.transferCount,
        tokenHolderCount: action.tokenHolderCount
      })
    }
    default:
      return state
  }
}

const elements = {
  '[data-page="counters"]': {
    render ($el, state) {
      if (state.counters) {
        return $el
      }
      return $el
    }
  },
  '[token-transfer-count]': {
    render ($el, state) {
      if (state.transferCount) {
        $el.empty().text(state.transferCount + ' Transfers')
        return $el.show()
      }
    }
  },
  '[token-holder-count]': {
    render ($el, state) {
      if (state.tokenHolderCount) {
        $el.empty().text(state.tokenHolderCount + ' Addresses')
        return $el.show()
      }
    }
  }
}

function loadCounters (store) {
  const $element = $('[data-async-counters]')
  const path = $element.data() && $element.data().asyncCounters
  function fetchCounters () {
    store.dispatch({ type: 'START_REQUEST' })
    $.getJSON(path)
      .done(response => store.dispatch(Object.assign({ type: 'COUNTERS_FETCHED' }, humps.camelizeKeys(response))))
      .fail(() => store.dispatch({ type: 'REQUEST_ERROR' }))
      .always(() => store.dispatch({ type: 'FINISH_REQUEST' }))
  }

  fetchCounters()
}

const $tokenPage = $('[token-page]')

if ($tokenPage.length) {
  updateCounters()
}

function updateCounters () {
  const store = createStore(reducer)
  connectElements({ store, elements })
  loadCounters(store)
}

if ($('[data-page="token-holders-list"]').length) {
  window.onbeforeunload = () => {
    // @ts-ignore
    window.loading = true
  }

  createAsyncLoadStore(reducer, initialState, null)
}

$('.btn-qr-icon').click(_event => {
  openQrModal()
})
