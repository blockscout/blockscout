import $ from 'jquery'
import '../app'

// This file adds event handlers responsible for the 'Try it out' UI in the
// Etherscan-compatible API documentation page.

function composeQuery (module, action, inputs) {
  const parameters = queryParametersFromInputs(inputs)
  return `?module=${module}&action=${action}` + parameters.join('')
}

function queryParametersFromInputs (inputs) {
  return $.map(inputs, queryParameterFromInput)
}

function queryParameterFromInput (input) {
  const key = $(input).attr('data-parameter-key')
  const value = $(input).val()

  if (value === '') {
    return ''
  } else {
    return `&${key}=${value}`
  }
}

function composeRequestUrl (query) {
  const url = $('[data-endpoint-url]').attr('data-endpoint-url')
  return `${url}${query}`
}

function composeCurlCommand (requestUrl) {
  return `curl -X GET "${requestUrl}" -H "accept: application/json"`
}

function isResultVisible (module, action) {
  return $(`[data-selector="${module}-${action}-try-api-ui-result"]`).is(':visible')
}

function handleSuccess (query, xhr, clickedButton) {
  const module = clickedButton.attr('data-module')
  const action = clickedButton.attr('data-action')
  const curl = $(`[data-selector="${module}-${action}-curl"]`)[0]
  const requestUrl = $(`[data-selector="${module}-${action}-request-url"]`)[0]
  const code = $(`[data-selector="${module}-${action}-server-response-code"]`)[0]
  const body = $(`[data-selector="${module}-${action}-server-response-body"]`)[0]
  const url = composeRequestUrl(escapeHtml(query))

  curl.innerHTML = composeCurlCommand(url)
  requestUrl.innerHTML = url
  code.innerHTML = xhr.status
  body.innerHTML = JSON.stringify(xhr.responseJSON, undefined, 2)
  $(`[data-selector="${module}-${action}-try-api-ui-result"]`).show()
  $(`[data-selector="${module}-${action}-btn-try-api-clear"]`).show()
  clickedButton.html(clickedButton.data('original-text'))
  clickedButton.prop('disabled', false)
}

function escapeHtml (text) {
  var map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  }

  return text.replace(/[&<>"']/g, function (m) { return map[m] })
}

// Show 'Try it out' UI for a module/action.
$('button[data-selector*="btn-try-api"]').click(event => {
  const clickedButton = $(event.target)
  const module = clickedButton.attr('data-module')
  const action = clickedButton.attr('data-action')
  clickedButton.hide()
  $(`button[data-selector="${module}-${action}-btn-try-api-cancel"]`).show()
  $(`[data-selector="${module}-${action}-try-api-ui"]`).show()

  if (isResultVisible(module, action)) {
    $(`[data-selector="${module}-${action}-btn-try-api-clear"]`).show()
  }
})

// Hide 'Try it out' UI for a module/action.
$('button[data-selector*="btn-try-api-cancel"]').click(event => {
  const clickedButton = $(event.target)
  const module = clickedButton.attr('data-module')
  const action = clickedButton.attr('data-action')
  clickedButton.hide()
  $(`[data-selector="${module}-${action}-try-api-ui"]`).hide()
  $(`[data-selector="${module}-${action}-btn-try-api-clear"]`).hide()
  $(`button[data-selector="${module}-${action}-btn-try-api"]`).show()
})

// Clear API server response/result, curl command, and request URL
$('button[data-selector*="btn-try-api-clear"]').click(event => {
  const clickedButton = $(event.target)
  const module = clickedButton.attr('data-module')
  const action = clickedButton.attr('data-action')
  clickedButton.hide()
  $(`[data-selector="${module}-${action}-try-api-ui-result"]`).hide()
})

// Remove invalid class from required fields if not empty
$('input[data-selector*="try-api-ui"][data-required="true"]').on('keyup', (event) => {
  if (event.target.value !== '') {
    event.target.classList.remove('is-invalid')
  } else {
    event.target.classList.add('is-invalid')
  }
})

// Execute API call
//
// Makes a request to the Explorer API with a given set of user defined
// parameters. The following related information is subsequently rendered below
// the execute button:
//
//   * curl command
//   * request URL
//   * server response
//
$('button[data-try-api-ui-button-type="execute"]').click(event => {
  const clickedButton = $(event.target)
  const module = clickedButton.attr('data-module')
  const action = clickedButton.attr('data-action')
  const inputs = $(`input[data-selector="${module}-${action}-try-api-ui"]`)
  const query = composeQuery(module, action, inputs)
  const loadingText = '<span class="loading-spinner-small mr-2"><span class="loading-spinner-block-1"></span><span class="loading-spinner-block-2"></span></span> Loading...'

  clickedButton.prop('disabled', true)
  clickedButton.data('original-text', clickedButton.html())

  if (clickedButton.html() !== loadingText) {
    clickedButton.html(loadingText)
  }

  $.ajax({
    url: composeRequestUrl(query),
    success: (_data, _status, xhr) => {
      handleSuccess(query, xhr, clickedButton)
    },
    error: (xhr) => {
      handleSuccess(query, xhr, clickedButton)
    }
  })
})
