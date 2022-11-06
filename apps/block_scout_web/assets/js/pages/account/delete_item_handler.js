import $ from 'jquery'

$('[data-delete-item]').on('click', (event) => {
  event.preventDefault()

  if (confirm('Are you sure you want to delete item?')) {
    $(event.currentTarget.parentElement).find('form').trigger('submit')
  }
})

$('[data-delete-request]').on('click', (event) => {
  event.preventDefault()

  const result = prompt('Public tags: "' + event.currentTarget.dataset.tags.replace(';', '" and "') + '" will be removed.\nWhy do you want to remove tags?')
  if (result) {
    $(event.currentTarget.parentElement).find('[name="remove_reason"]').val(result)
    $(event.currentTarget.parentElement).find('form').trigger('submit')
  }
})
