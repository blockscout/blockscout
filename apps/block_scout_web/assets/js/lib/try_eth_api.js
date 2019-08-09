import $ from 'jquery'

function composeCurlCommand (data) {
  return `curl -H "content-type: application/json" -X POST --data '${JSON.stringify(data)}'`
}

function handleResponse (data, xhr, clickedButton) {
  const module = clickedButton.attr('data-module')
  const action = clickedButton.attr('data-action')
  const curl = $(`[data-selector="${module}-${action}-curl"]`)[0]
  const code = $(`[data-selector="${module}-${action}-server-response-code"]`)[0]
  const body = $(`[data-selector="${module}-${action}-server-response-body"]`)[0]

  curl.innerHTML = composeCurlCommand(data)
  code.innerHTML = xhr.status
  body.innerHTML = JSON.stringify(xhr.responseJSON, undefined, 2)
  $(`[data-selector="${module}-${action}-try-api-ui-result"]`).show()
  $(`[data-selector="${module}-${action}-btn-try-api-clear"]`).show()
  clickedButton.html(clickedButton.data('original-text'))
  clickedButton.prop('disabled', false)
}

function wrapJsonRpc (method, params) {
  return {
    id: 0,
    jsonrpc: '2.0',
    method: method,
    params: params
  }
}

function parseInput (input) {
  const type = $(input).attr('data-parameter-type')
  const value = $(input).val()

  switch (type) {
    case 'string':
      return value
    case 'json':
      return JSON.parse(value)
    default:
      return value
  }
}

$('button[data-try-eth-api-ui-button-type="execute"]').click(event => {
  const clickedButton = $(event.target)
  const module = clickedButton.attr('data-module')
  const action = clickedButton.attr('data-action')
  const inputs = $(`input[data-selector="${module}-${action}-try-api-ui"]`)
  const params = $.map(inputs, parseInput)
  const formData = wrapJsonRpc(action, params)
  console.log(formData)
  const loadingText = '<span class="loading-spinner-small mr-2"><span class="loading-spinner-block-1"></span><span class="loading-spinner-block-2"></span></span> Loading...'

  clickedButton.prop('disabled', true)
  clickedButton.data('original-text', clickedButton.html())

  if (clickedButton.html() !== loadingText) {
    clickedButton.html(loadingText)
  }

  $.ajax({
    url: '/api/eth_rpc',
    type: 'POST',
    data: JSON.stringify(formData),
    dataType: 'json',
    contentType: 'application/json; charset=utf-8'
  }).then((_data, _status, xhr) => handleResponse(formData, xhr, clickedButton))
})
