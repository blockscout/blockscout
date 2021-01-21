import { createStore } from './redux_helpers.js'

import $ from 'jquery'
import Analytics from 'analytics'
import segmentPlugin from '@analytics/segment'
import omit from 'lodash/omit'
import uniqid from 'uniqid'

const analytics = Analytics({
  app: 'Blockscout',
  plugins: [
    segmentPlugin({
      writeKey: process.env.SEGMENT_KEY
    })
  ]
})

export const initialState = {
  userID: localStorage.getItem('userID')
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'SET_USER_ID': {
      const id = uniqid()
      localStorage.setItem('userID', id)
      return Object.assign({}, state, { userID: id })
    }
    default:
      return state
  }
}

$(function () {
  const store = createStore(reducer)
  if (!store.getState().userID) {
    store.dispatch({ type: 'SET_USER_ID' })
  }
  analytics.identify(store.getState().userID)
  analytics.page()
  trackEvents()
})

function trackEvents () {
  // Page navigation
  window.addEventListener('locationchange', function () {
    analytics.page()
  })

  // Search box click
  $('[data-selector="search-bar"]').on('click', function () {
    analytics.track('Search bar clicked')
  })

  // Search submit
  $('[data-selector="search-form"]').on('submit', function (e) {
    e.preventDefault() // prevent form from submitting
    analytics.track('Search submit', {
      value: e.value
    })
  })

  // Click on Balance Card Caret
  $('[data-selector="balance-card"]').on('click', function () {
    analytics.track('Address balance caret clicked')
  })

  // Copy address
  $('[data-selector="copy-address"]').on('click', function () {
    analytics.track('Copy address clicked')
  })

  // QR code
  $('[data-selector="qr-code"]').on('click', function () {
    analytics.track('QR code clicked')
  })

  // "view more transfers" click
  $('[data-selector="token-transfer-open"]').on('click', function () {
    analytics.track('"View more transfers" clicked')
  })
}
