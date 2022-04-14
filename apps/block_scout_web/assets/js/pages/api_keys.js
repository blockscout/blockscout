import $ from 'jquery'

$('[delete-api-key]').on('click', (event) => {
  event.preventDefault()
  console.log(event)
  if (confirm('Are you sure you want to delete API key?')) {
    $(event.currentTarget.parentElement).find('form').trigger('submit')
  }
})