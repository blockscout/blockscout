import $ from 'jquery'

$('[delete-item]').on('click', (event) => {
  event.preventDefault()
  console.log(event)
  if (confirm('Are you sure you want to delete item?')) {
    $(event.currentTarget.parentElement).find('form').trigger('submit')
  }
})
