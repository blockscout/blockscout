import { connectElements, createStore } from '../lib/redux_helpers.js'

import $ from 'jquery'
import omit from 'lodash/omit'

export const initialState = {
  showBanner: !(localStorage.getItem('showSurveyBanner') === 'false')
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'DISMISS_BANNER': {
      localStorage.setItem('showSurveyBanner', false)
      return Object.assign({}, state, { showBanner: false })
    }
    default:
      return state
  }
}

const elements = {
  '[data-selector="survey-banner"]': {
    render ($el, state) {
      if (state.showBanner) {
        $el.removeAttr('hidden')
      } else {
        $el.attr('hidden', true)
      }
    }
  }
}

const $app = $('[data-page="app-container"]')
if ($app.length) {
  const store = createStore(reducer)
  connectElements({ store, elements })
  bindCloseButton(store)
}

function bindCloseButton (store) {
  $('.survey-banner-dismiss').on('click', () => {
    store.dispatch({
      type: 'DISMISS_BANNER'
    })
  })
}
