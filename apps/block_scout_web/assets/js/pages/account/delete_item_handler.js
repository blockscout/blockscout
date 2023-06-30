import $ from 'jquery'

$('[data-delete-item]').on('click', (event) => {
  event.preventDefault()

  if (confirm('Are you sure you want to delete item?')) {
    // @ts-ignore
    $(event.currentTarget.parentElement).find('form').trigger('submit')
  }
})

$('[data-delete-request]').on('click', (event) => {
  event.preventDefault()

  // @ts-ignore
  const result = prompt('Public tags: "' + event.currentTarget.dataset.tags.replace(';', '" and "') + '" will be removed.\nWhy do you want to remove tags?')
  if (result) {
    // @ts-ignore
    $(event.currentTarget.parentElement).find('[name="remove_reason"]').val(result)
    // @ts-ignore
    $(event.currentTarget.parentElement).find('form').trigger('submit')
  }
})
