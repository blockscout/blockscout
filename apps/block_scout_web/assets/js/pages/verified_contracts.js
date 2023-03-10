import $ from 'jquery'
import omit from 'lodash.omit'
import { loadPage, createAsyncLoadStore } from '../lib/async_listing_load'
import { connectElements } from '../lib/redux_helpers.js'
import { formatUsdValue } from '../lib/currency'

export const initialState = {
  isSearch: false
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
  },
  '[data-usd-value]': {
    render ($el, state) {
      $el.each((i, el) => {
        el.innerHTML = formatUsdValue(el.dataset.usdValue)
      })
      // @ts-ignore
      if (state.channelDisconnected && !window.loading) $el.show()
    }
  }
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

if ($('[data-page="verified-contracts-list"]').length) {
  let timer
  const waitTime = 500

  const $element = $('[data-async-listing]')

  $element.on('click', '[data-next-page-button], [data-prev-page-button]', (event) => {
    const obj = document.getElementById('verified-contracts-list')
    if (obj) {
      obj.scrollIntoView()
    }
  })

  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierHash')

  connectElements({ store, elements })

  const searchFunc = (_event) => {
    store.dispatch({ type: 'START_SEARCH' })
    const searchInput = $('[data-search-field]').val()
    const pathHaveNoParams = window.location.pathname + '?search=' + searchInput
    const pathHaveParams = window.location.pathname + window.location.search + '&search=' + searchInput
    const path = window.location.href.includes('?') ? pathHaveParams : pathHaveNoParams
    loadPage(store, path)
  }

  store.dispatch({
    type: 'PAGE_LOAD'
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
