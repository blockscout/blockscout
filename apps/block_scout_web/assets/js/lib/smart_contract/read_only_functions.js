import $ from 'jquery'

const loadFunctions = (element) => {
  const $element = $(element)
  const url = $element.data('url')
  const hash = $element.data('hash')
  const type = $element.data('type')

  $.get(
    url,
    { hash: hash, type: type },
    response => $element.html(response)
  )
    .done(function () {
      $('[data-function]').each((_, element) => {
        readFunction(element)
      })
    })
    .fail(function (response) {
      $element.html(response.statusText)
    })
}

const readFunction = (element) => {
  const $element = $(element)
  const $form = $element.find('[data-function-form]')

  const $responseContainer = $element.find('[data-function-response]')

  $form.on('submit', (event) => {
    event.preventDefault()

    const url = $form.data('url')
    const $functionName = $form.find('input[name=function_name]')
    const $functionInputs = $form.find('input[name=function_input]')

    const args = $.map($functionInputs, element => {
      return $(element).val()
    })

    const data = {
      function_name: $functionName.val(),
      args
    }

    $.get(url, data, response => $responseContainer.html(response))
  })
}

const container = $('[data-smart-contract-functions]')

if (container.length) {
  loadFunctions(container)
}
