import 'viewerjs/dist/viewer.min.css'
import Viewer from 'viewerjs'
import $ from 'jquery'
import { createStore, connectElements } from '../lib/redux_helpers.js'

export const initialState = {
  contract_svg: null,
  visualize_error: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'SVG_FETCHED': {
      return Object.assign({}, state, {
        contract_svg: action.contract_svg,
        visualize_error: action.error
      })
    }
    default:
      return state
  }
}

const elements = {
  '[data-selector="contract-image"]': {
    render ($el, state, oldState) {
      if (state.contract_svg) {
        console.log('Got svg from server')
        $('#spinner').hide()
        $('#gallery img').attr('src', 'data:image/svg+xml;base64,' + state.contract_svg)
        const gallery = document.getElementById('gallery')
        const viewer = new Viewer(gallery, {
          inline: false,
          toolbar: {
            zoomIn: 2,
            zoomOut: 4,
            oneToOne: 4,
            reset: 4,
            play: {
              show: 4,
              size: 'large'
            },
            rotateLeft: 4,
            rotateRight: 4,
            flipHorizontal: 4,
            flipVertical: 4
          }
        })
        viewer.update()
        $el.show()
      } else if (state.visualize_error) {
        console.log('Got error from server')

        $('#spinner').hide()
        $el.empty().text('Cannot visalize contract: ' + state.visualize_error)
        $el.show()
      } else {
        $('#spinner').show()
        $el.hide()
      }
    }
  }
}

function loadSvg (store) {
  const $element = $('[data-async-contract-svg]')
  const path = $element.data().asyncContractSvg

  function fetchSvg () {
    $.getJSON(path)
      .done((response) => {
        store.dispatch(Object.assign({ type: 'SVG_FETCHED' }, response))
      })
  }

  fetchSvg()
}

function main () {
  const store = createStore(reducer)
  connectElements({ store, elements })
  loadSvg(store)
}

main()
