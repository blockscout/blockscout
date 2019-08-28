import $ from 'jquery'

export function updateValidation (validation, errors, input) {
  if (validation.state === false) {
    errors.set($(input).prop('id'), input)
    displayInputError(input, validation.message)
    return errors
  }

  if (validation.state !== null) {
    errors.delete($(input).prop('id'))
  }

  hideInputError(input)
  return errors
}

export function displayInputError (input, message) {
  const group = $(input).parent('.input-group')

  group.addClass('input-status-error')
  group.find('.input-group-message').html(message)
}

export function hideInputError (input) {
  const group = $(input).parent('.input-group')

  group.removeClass('input-status-error')
  group.find('.input-group-message').html('')
}

export function updateSubmit ($form, errors) {
  if (errors.size) {
    disableSubmit($form, true)
  } else {
    disableSubmit($form, false)
  }
}

export function disableSubmit ($form, disabled) {
  $form.find('button').prop('disabled', disabled)
}
