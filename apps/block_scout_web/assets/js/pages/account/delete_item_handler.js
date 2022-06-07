import $ from 'jquery'

$('[delete-item]').on('click', (event) => {
  event.preventDefault()

  if (confirm('Are you sure you want to delete item?')) {
    $(event.currentTarget.parentElement).find('form').trigger('submit')
  }
})

$('[delete-request]').on('click', (event) => {
  event.preventDefault()
  const result = prompt('Why do you want to remove tags?')
  if (result) {
    $(event.currentTarget.parentElement).find('[name="remove_reason"]').val(result)
    $(event.currentTarget.parentElement).find('form').trigger('submit')
  }
})
