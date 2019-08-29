import $ from 'jquery'

export function setupValidation ($form, validators, $submit) {
  const errors = {}

  disableSubmit($submit, true)

  for (let [key, callback] of Object.entries(validators)) {
    const $input = $form.find('[' + key + ']')
    errors[key] = null

    $input
      .focus(() => {
        hideInputError($input)
      })
      .blur(() => {
        if (errors[key]) {
          displayInputError($input, errors[key])
        }
      })
      .on('input', () => {
        if (!$input.val()) {
          errors[key] = null
          return
        }

        const validation = callback($input.val())
        if (validation === true) {
          delete errors[key]
        } else {
          errors[key] = validation
        }

        updateSubmit($submit, errors)
      })
  }
}

function updateSubmit ($submit, errors) {
  if ($.isEmptyObject(errors)) {
    disableSubmit($submit, false)
    return
  }

  disableSubmit($submit, true)
}

function displayInputError ($input, message) {
  const group = $input.parent('.input-group')

  group.addClass('input-status-error')
  group.find('.input-group-message').html(message)
}

function hideInputError ($input) {
  const group = $input.parent('.input-group')

  group.removeClass('input-status-error')
  group.find('.input-group-message').html('')
}

function disableSubmit ($submit, disabled) {
  $submit.prop('disabled', disabled)
}
