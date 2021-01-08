import $ from 'jquery'
import omit from 'lodash/omit'
import { createStore, connectElements } from '../lib/redux_helpers.js'

export const initialState = {
  showBanner: true
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'DISMISS_BANNER': {
      return Object.assign({}, state, { showBanner: false })
    }
    default:
      return state
  }
}

const elements = {
  '[data-selector="survey-banner"]': {
    render ($el, state) {
      if (!state.showBanner) $el.hide()
    }
  }
}

const $app = $('[data-page="app-container"]')
if ($app.length) {
  console.log('app exists')
  const store = createStore(reducer)
  connectElements({ store, elements })
}

$('.survey-banner-dismiss').on('click', () => {
  console.log('goodbye banner')
  store.dispatch({
    type: 'DISMISS_BANNER'
  })
})
