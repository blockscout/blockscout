import $ from 'jquery'
import omit from 'lodash/omit'
import URI from 'urijs'
import humps from 'humps'
import { subscribeChannel } from '../socket'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import '../app'

export const initialState = {
  channelDisconnected: false,
  addressHash: null,
  newForm: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      if (state.beyondPageOne) return state

      return Object.assign({}, state, {
        channelDisconnected: true
      })
    }
    case 'RECEIVED_VERIFICATION_RESULT': {
      if (action.msg.verificationResult === 'ok') {
        return window.location.replace(window.location.href.split('/contract_verifications')[0] + '/contracts')
      } else {
        return Object.assign({}, state, {
          newForm: action.msg.verificationResult
        })
      }
    }
    default:
      return state
  }
}

const elements = {
  '[data-selector="channel-disconnected-message"]': {
    render ($el, state) {
      if (state.channelDisconnected) $el.show()
    }
  },
  '[data-page="contract-verification"]': {
    render ($el, state) {
      if (state.newForm) {
        $el.replaceWith(state.newForm)
        $('button[data-button-loading="animation"]').click(_event => {
          $('#loading').removeClass('d-none')
        })

        $(function () {
          $('.js-btn-add-contract-libraries').on('click', function () {
            $('.js-smart-contract-libraries-wrapper').show()
            $(this).hide()
          })

          $('.js-smart-contract-form-reset').on('click', function () {
            $('.js-contract-library-form-group').removeClass('active')
            $('.js-contract-library-form-group').first().addClass('active')
            $('.js-smart-contract-libraries-wrapper').hide()
            $('.js-btn-add-contract-libraries').show()
            $('.js-add-contract-library-wrapper').show()
          })

          $('.js-btn-add-contract-library').on('click', function () {
            const nextContractLibrary = $('.js-contract-library-form-group.active').next('.js-contract-library-form-group')

            if (nextContractLibrary) {
              nextContractLibrary.addClass('active')
            }

            if ($('.js-contract-library-form-group.active').length === $('.js-contract-library-form-group').length) {
              $('.js-add-contract-library-wrapper').hide()
            }
          })
        })

        return $el
      }
      return $el
    }
  }
}

const $contractVerificationPage = $('[data-page="contract-verification"]')

function filterNightlyBuilds (filter) {
  const select = document.getElementById('smart_contract_compiler_version')
  const options = select.getElementsByTagName('option')
  for (const option of options) {
    const txtValue = option.textContent || option.innerText
    if (filter) {
      if (txtValue.toLowerCase().indexOf('nightly') > -1) {
        option.style.display = 'none'
      } else {
        option.style.display = ''
      }
    } else {
      if (txtValue.toLowerCase().indexOf('nightly') > -1) {
        option.style.display = ''
      }
    }
  }
}

if ($contractVerificationPage.length) {
  const store = createStore(reducer)
  const addressHash = $('#smart_contract_address_hash').val()
  const { filter, blockNumber } = humps.camelizeKeys(URI(window.location).query(true))

  store.dispatch({
    type: 'PAGE_LOAD',
    addressHash,
    filter,
    beyondPageOne: !!blockNumber
  })
  connectElements({ store, elements })

  const addressChannel = subscribeChannel(`addresses:${addressHash}`)

  addressChannel.onError(() => store.dispatch({
    type: 'CHANNEL_DISCONNECTED'
  }))
  addressChannel.on('verification', (msg) => store.dispatch({
    type: 'RECEIVED_VERIFICATION_RESULT',
    msg: humps.camelizeKeys(msg)
  }))

  $('button[data-button-loading="animation"]').click(_event => {
    $('#loading').removeClass('d-none')
  })

  $(function () {
    setTimeout(function () {
      $('.nightly-builds-false').trigger('click')
    }, 10)

    $('.js-btn-add-contract-libraries').on('click', function () {
      $('.js-smart-contract-libraries-wrapper').show()
      $(this).hide()
    })

    $('.autodetectfalse').on('click', function () {
      if ($(this).prop('checked')) { $('.constructor-arguments').show() }
    })

    $('.autodetecttrue').on('click', function () {
      if ($(this).prop('checked')) { $('.constructor-arguments').hide() }
    })

    $('.nightly-builds-true').on('click', function () {
      if ($(this).prop('checked')) { filterNightlyBuilds(false) }
    })

    $('.nightly-builds-false').on('click', function () {
      if ($(this).prop('checked')) { filterNightlyBuilds(true) }
    })

    $('.optimization-false').on('click', function () {
      if ($(this).prop('checked')) { $('.optimization-runs').hide() }
    })

    $('.optimization-true').on('click', function () {
      if ($(this).prop('checked')) { $('.optimization-runs').show() }
    })

    $('.js-smart-contract-form-reset').on('click', function () {
      $('.js-contract-library-form-group').removeClass('active')
      $('.js-contract-library-form-group').first().addClass('active')
      $('.js-smart-contract-libraries-wrapper').hide()
      $('.js-btn-add-contract-libraries').show()
      $('.js-add-contract-library-wrapper').show()
    })

    $('.js-btn-add-contract-library').on('click', function () {
      const nextContractLibrary = $('.js-contract-library-form-group.active').next('.js-contract-library-form-group')

      if (nextContractLibrary) {
        nextContractLibrary.addClass('active')
      }

      if ($('.js-contract-library-form-group.active').length === $('.js-contract-library-form-group').length) {
        $('.js-add-contract-library-wrapper').hide()
      }
    })
  })
}
