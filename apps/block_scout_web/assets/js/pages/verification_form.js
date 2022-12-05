import $ from 'jquery'
import omit from 'lodash.omit'
import humps from 'humps'
import { subscribeChannel } from '../socket'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import { fullPath } from '../lib/utils'
import '../app'
import Dropzone from 'dropzone'

export const initialState = {
  channelDisconnected: false,
  addressHash: null,
  validationErrors: null,
  newForm: null
}

export function reducer (state = initialState, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, {
        channelDisconnected: true
      })
    }
    case 'RECEIVED_VERIFICATION_RESULT': {
      if (action.msg.verificationResult === 'ok') {
        return window.location.replace(window.location.href.split('/contract-verifications')[0].split('/verify')[0] + '/contracts')
      } else {
        try {
          const result = JSON.parse(action.msg.verificationResult)

          return Object.assign({}, state, {
            validationErrors: result.errors
          })
        } catch (e) {
          console.error('Unexpected verification response', e)
          return state
        }
      }
    }
    default:
      return state
  }
}

function resetForm () {
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

    $('body').on('click', '.js-btn-add-contract-library', (event) => {
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

function clearValidationErrors () {
  $('.form-error').remove()
}

function renderValidationErrors (errors) {
  clearValidationErrors()

  errors.forEach((error) => {
    const { field, message } = error
    const fieldName = field.replaceAll('_', '-')

    const $errorMessageNode = $(`<span class="text-danger form-error" data-test="${fieldName}-error" id="${fieldName}-help-block">${message}</span>`)

    const erroredFieldNode = document.querySelector(`[name="smart_contract[${field}]"]`)
    const groupNodes = document.querySelectorAll('.smart-contract-form-group')

    if (erroredFieldNode) {
      $errorMessageNode.insertAfter(`[name="smart_contract[${field}]"]`)
    } else if (groupNodes.length > 0) {
      // dropzone doesn't have an input, needs to be handled differently
      groupNodes[groupNodes.length - 1].appendChild($errorMessageNode.get('0'))
    }
  })
}

function updateFormState (locked) {
  if (locked) {
    document.getElementById('loading').classList.remove('d-none')
  } else {
    document.getElementById('loading').classList.add('d-none')
  }

  const controls = document.getElementsByClassName('form-control')
  controls.forEach((control) => { control.disabled = locked })
}

const elements = {
  '[data-selector="channel-disconnected-message"]': {
    render ($el, state) {
      if (state.channelDisconnected && !window.loading) $el.show()
    }
  },
  '[data-page="contract-verification"]': {
    render ($el, state) {
      if (state.validationErrors) {
        updateFormState(false)
        renderValidationErrors(state.validationErrors)
      } else if (state.newForm) {
        $el.replaceWith(state.newForm)
        initializeDropzone()
        state.newForm = null

        resetForm()
      }

      return $el
    }
  }
}

const $contractVerificationPage = $('[data-page="contract-verification"]')
const $contractVerificationChooseTypePage = $('[data-page="contract-verification-choose-type"]')

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

let dropzone

if ($contractVerificationPage.length) {
  window.onbeforeunload = () => {
    window.loading = true
  }

  window.onbeforeunload = () => {
    window.loading = true
  }

  const store = createStore(reducer)
  const addressHash = $('#smart_contract_address_hash').val()
  const $form = $contractVerificationPage.find('form')

  $form.on('submit', (event) => {
    event.preventDefault() // avoid to execute the actual submit of the form.

    if ($form.get(0).checkValidity() === false) {
      return false
    }

    $.ajax({
      type: 'POST',
      url: $form.attr('action'),
      data: $form.serialize()
    })

    updateFormState(true)
  })

  store.dispatch({
    type: 'PAGE_LOAD',
    addressHash
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

  $(function () {
    initializeDropzone()

    setTimeout(function () {
      $('.nightly-builds-false').trigger('click')
    }, 10)

    $('body').on('click', '.js-btn-add-contract-libraries', function () {
      $('.js-smart-contract-libraries-wrapper').show()
      $(this).hide()
    })

    $('body').on('click', '.autodetectfalse', function () {
      if ($(this).prop('checked')) { $('.constructor-arguments').show() }
    })

    $('body').on('click', '.autodetecttrue', function () {
      if ($(this).prop('checked')) { $('.constructor-arguments').hide() }
    })

    $('body').on('click', '.nightly-builds-true', function () {
      if ($(this).prop('checked')) { filterNightlyBuilds(false) }
    })

    $('body').on('click', '.nightly-builds-false', function () {
      if ($(this).prop('checked')) { filterNightlyBuilds(true) }
    })

    $('body').on('click', '.optimization-false', function () {
      if ($(this).prop('checked')) { $('.optimization-runs').hide() }
    })

    $('body').on('click', '.optimization-true', function () {
      if ($(this).prop('checked')) { $('.optimization-runs').show() }
    })

    $('body').on('click', '.js-smart-contract-form-reset', function () {
      $('.js-contract-library-form-group').removeClass('active')
      $('.js-contract-library-form-group').first().addClass('active')
      $('.js-smart-contract-libraries-wrapper').hide()
      $('.js-btn-add-contract-libraries').show()
      $('.js-add-contract-library-wrapper').show()
    })

    $('body').on('click', '.js-btn-add-contract-library', (event) => {
      const nextContractLibrary = $('.js-contract-library-form-group.active').next('.js-contract-library-form-group')

      if (nextContractLibrary) {
        nextContractLibrary.addClass('active')
      }

      if ($('.js-contract-library-form-group.active').length === $('.js-contract-library-form-group').length) {
        $('.js-add-contract-library-wrapper').hide()
      }
    })

    $('body').on('click', '#verify-via-standard-json-input-submit', (event) => {
      event.preventDefault()
      if (dropzone.files.length > 0) {
        dropzone.processQueue()
      } else {
        $('#loading').addClass('d-none')
      }
    })

    $('body').on('click', '[data-submit-button]', (event) => {
      // submit form without page updating in order to avoid websocket reconnecting
      event.preventDefault()
      const $form = $('form')[0]
      $.post($form.action, convertFormToJSON($form))
    })

    $('body').on('click', '#verify-via-metadata-json-submit', (event) => {
      event.preventDefault()
      if (dropzone.files.length > 0) {
        dropzone.processQueue()
      } else {
        $('#loading').addClass('d-none')
      }
    })
  })
} else if ($contractVerificationChooseTypePage.length) {
  $('#smart_contract_address_hash').on('change load input ready', function () {
    const address = ($('#smart_contract_address_hash').val())

    const onContractUnverified = () => {
      document.getElementById('message-address-verified').hidden = true
      document.getElementById('message-link').removeAttribute('href')
      document.getElementById('data-button').disabled = false
    }

    const onContractVerified = (address) => {
      document.getElementById('message-address-verified').hidden = false
      document.getElementById('message-link').setAttribute('href', fullPath(`/address/${address}/contracts`))
      document.getElementById('data-button').disabled = true
    }

    const isContractVerified = (result) => {
      return result &&
        result[0].ABI !== undefined &&
        result[0].ABI !== 'Contract source code not verified'
    }

    $.get(fullPath(`/api/?module=contract&action=getsourcecode&address=${address}`)).done(
      response => {
        if (isContractVerified(response.result)) {
          onContractVerified(address)
        } else {
          onContractUnverified()
        }
      }).fail(onContractUnverified)
  })

  $('.verify-via-flattened-code').on('click', function () {
    if ($(this).prop('checked')) {
      $('#verify_via_flattened_code_button').show()
      $('#verify_via_sourcify_button').hide()
      $('#verify_vyper_contract_button').hide()
      $('#verify_via_standard_json_input_button').hide()
      $('#verify_via_multi_part_files_button').hide()
    }
  })

  $('.verify-via-sourcify').on('click', function () {
    if ($(this).prop('checked')) {
      $('#verify_via_flattened_code_button').hide()
      $('#verify_via_sourcify_button').show()
      $('#verify_vyper_contract_button').hide()
      $('#verify_via_standard_json_input_button').hide()
      $('#verify_via_multi_part_files_button').hide()
    }
  })

  $('.verify-vyper-contract').on('click', function () {
    if ($(this).prop('checked')) {
      $('#verify_via_flattened_code_button').hide()
      $('#verify_via_sourcify_button').hide()
      $('#verify_vyper_contract_button').show()
      $('#verify_via_standard_json_input_button').hide()
      $('#verify_via_multi_part_files_button').hide()
    }
  })

  $('.verify-via-standard-json-input').on('click', function () {
    if ($(this).prop('checked')) {
      $('#verify_via_flattened_code_button').hide()
      $('#verify_via_sourcify_button').hide()
      $('#verify_vyper_contract_button').hide()
      $('#verify_via_standard_json_input_button').show()
      $('#verify_via_multi_part_files_button').hide()
    }
  })

  $('.verify-via-multi-part-files').on('click', function () {
    if ($(this).prop('checked')) {
      $('#verify_via_flattened_code_button').hide()
      $('#verify_via_sourcify_button').hide()
      $('#verify_vyper_contract_button').hide()
      $('#verify_via_standard_json_input_button').hide()
      $('#verify_via_multi_part_files_button').show()
    }
  })
}

function convertFormToJSON (form) {
  const array = $(form).serializeArray()
  const json = {}
  $.each(array, function () {
    json[this.name] = this.value || ''
  })
  return json
}

function changeVisibilityOfVerifyButton (filesLength) {
  if (filesLength > 0) {
    $('#verify-via-metadata-json-submit').prop('disabled', false)
  } else {
    $('#verify-via-metadata-json-submit').prop('disabled', true)
  }
}

function standardJSONBehavior () {
  $('#standard-json-dropzone-form').removeClass('dz-clickable')
  this.on('addedfile', function (_file) {
    $('#verify-via-standard-json-input-submit').prop('disabled', false)
    $('#file-help-block').text('')
    $('#dropzone-previews').addClass('dz-started')
  })

  this.on('removedfile', function (_file) {
    if (this.files.length === 0) {
      $('#verify-via-standard-json-input-submit').prop('disabled', true)
      $('#dropzone-previews').removeClass('dz-started')
    }
  })
}

function metadataJSONBehavior () {
  $('#metadata-json-dropzone-form').removeClass('dz-clickable')
  this.on('addedfile', function (_file) {
    changeVisibilityOfVerifyButton(this.files.length)
    $('#file-help-block').text('')
    $('#dropzone-previews').addClass('dz-started')
  })

  this.on('removedfile', function (_file) {
    changeVisibilityOfVerifyButton(this.files.length)
    if (this.files.length === 0) {
      $('#dropzone-previews').removeClass('dz-started')
    }
  })
}

function multiPartFilesBehavior () {
  $('#metadata-json-dropzone-form').removeClass('dz-clickable')
  this.on('addedfile', function (_file) {
    changeVisibilityOfVerifyButton(this.files.length)
    $('#file-help-block').text('')
    $('#dropzone-previews').addClass('dz-started')
  })

  this.on('removedfile', function (_file) {
    changeVisibilityOfVerifyButton(this.files.length)
    if (this.files.length === 0) {
      $('#dropzone-previews').removeClass('dz-started')
    }
  })
}

function initializeDropzone () {
  const $jsonDropzoneMetadata = $('#metadata-json-dropzone-form')
  const $jsonDropzoneStandardInput = $('#standard-json-dropzone-form')

  if ($jsonDropzoneMetadata.length || $jsonDropzoneStandardInput.length) {
    const func = $jsonDropzoneMetadata.length ? metadataJSONBehavior : standardJSONBehavior
    const maxFiles = $jsonDropzoneMetadata.length ? 100 : 1
    const acceptedFiles = $jsonDropzoneMetadata.length ? 'text/plain,application/json,.sol,.json' : 'text/plain,application/json,.json'
    const tag = $jsonDropzoneMetadata.length ? '#metadata-json-dropzone-form' : '#standard-json-dropzone-form'
    const jsonVerificationType = $jsonDropzoneMetadata.length ? 'json:metadata' : 'json:standard'

    dropzone = new Dropzone(tag, {
      autoProcessQueue: false,
      acceptedFiles,
      parallelUploads: 100,
      uploadMultiple: true,
      addRemoveLinks: true,
      maxFilesize: 10,
      maxFiles,
      previewsContainer: '#dropzone-previews',
      params: { address_hash: $('#smart_contract_address_hash').val(), verification_type: jsonVerificationType },
      init: func
    })
  }

  const $dropzoneMultiPartFiles = $('#multi-part-dropzone-form')

  if ($dropzoneMultiPartFiles.length) {
    const func = multiPartFilesBehavior
    const maxFiles = 100
    const acceptedFiles = 'text/plain,.sol'
    const tag = '#multi-part-dropzone-form'
    const jsonVerificationType = 'multi-part-files'

    dropzone = new Dropzone(tag, {
      autoProcessQueue: false,
      acceptedFiles,
      parallelUploads: 100,
      uploadMultiple: true,
      addRemoveLinks: true,
      maxFilesize: 10,
      maxFiles,
      headers: {
        Accept: '*/*'
      },
      previewsContainer: '#dropzone-previews',
      params: { address_hash: $('#smart_contract_address_hash').val(), verification_type: jsonVerificationType },
      init: func
    })
  }
}
