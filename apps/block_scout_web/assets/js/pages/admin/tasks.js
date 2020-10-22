import $ from 'jquery'
import '../../app'

const runTask = (event) => {
  const element = event.currentTarget
  const $element = $(element)
  const $loading = $element.find('[data-loading-message]')
  const $errorMessage = $element.find('[data-error-message]')
  const $successMessage = $element.find('[data-success-message]')
  const apiPath = element.dataset.api_path

  $errorMessage.hide()
  $successMessage.hide()
  $loading.show()

  $.get(apiPath)
    .done(_response => {
      $successMessage.show()
      $loading.hide()
    })
    .fail(() => {
      $loading.hide()
      $errorMessage.show()
    })
}

$('#run-create-contract-methods').click(runTask)
