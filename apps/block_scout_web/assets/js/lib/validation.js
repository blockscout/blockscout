import $ from 'jquery'

export function setupValidation ($form, validators, $submit) {
  const errors = {}

  updateSubmit($submit, errors)

  for (const [key, callback] of Object.entries(validators)) {
    const $input = $form.find('[' + key + ']')
    errors[key] = null

    $input
      .ready(() => {
        validateInput($input, callback, errors)
        updateSubmit($submit, errors)
        if (errors[key]) {
          displayInputError($input, errors[key])
        }
      })
      .blur(() => {
        if (errors[key]) {
          displayInputError($input, errors[key])
        }
      })
      .on('input', () => {
        hideInputError($input)
        validateInput($input, callback, errors)
        updateSubmit($submit, errors)
      })
  }
}

function validateInput ($input, callback, errors) {
  if (!$input.val()) {
    errors[$input.prop('id')] = null
    return
  }

  const validation = callback($input.val())
  if (validation === true) {
    delete errors[$input.prop('id')]
    return
  }

  errors[$input.prop('id')] = validation
}

function updateSubmit ($submit, errors) {
  $submit.prop('disabled', !$.isEmptyObject(errors))
}

export function displayInputError ($input, message) {
  const group = $input.parent('.input-group')

  group.addClass('input-status-error')
  group.find('.input-group-message').html(message)
}

export function hideInputError ($input) {
  const group = $input.parent('.input-group')

  group.removeClass('input-status-error')
  group.find('.input-group-message').html('')
}
