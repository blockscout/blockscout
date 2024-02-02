import $ from 'jquery'

const $removeButton = $('.remove-form-field')[0]
const $container = $('#' + $removeButton.dataset.container)
// @ts-ignore
const index = parseInt($container[0].dataset.index)

if (index <= 1) {
  $('.remove-form-field').hide()
}

$('.add-form-field').on('click', (event) => {
  event.preventDefault()
  const $container = $('#' + event.currentTarget.dataset.container)
  // @ts-ignore
  const index = parseInt($container[0].dataset.index)
  if (index < 10) {
    // @ts-ignore
    $container.append($.parseHTML(event.currentTarget.dataset.prototype))
    // @ts-ignore
    $container[0].dataset.index = index + 1
  }
  if (index >= 9) {
    $('.add-form-field').hide()
  }
  if (index <= 1) {
    $('.remove-form-field').show()
  }
})

$('[data-multiple-input-field-container]').on('click', '.remove-form-field', (event) => {
  event.preventDefault()
  console.log(event)
  const $container = $('#' + event.currentTarget.dataset.container)
  // @ts-ignore
  const index = parseInt($container[0].dataset.index)
  if (index > 1) {
    // @ts-ignore
    $container[0].dataset.index = index - 1
    event.currentTarget.parentElement.remove()
  }
  if (index >= 10) {
    $('.add-form-field').show()
  }
  if (index <= 2) {
    $('.remove-form-field').hide()
  }
})
