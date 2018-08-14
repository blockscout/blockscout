import $ from 'jquery'

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

$('[data-function]').each((_, element) => {
  readFunction(element)
})
