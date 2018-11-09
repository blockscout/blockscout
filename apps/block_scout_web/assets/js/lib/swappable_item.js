import $ from 'jquery'

const swapItems = (element, event) => {
  const $element = $(element)
  const item = $element.parent().closest('[swappable-item]')
  const next = item.nextAll('[swappable-item]:first')

  item.hide()

  if (next.length) {
    next.show()
  } else {
    item.parent().find('[swappable-item]:first').show()
  }

  return false
}

$('[swappable-item] [swapper]').on('click', function (event) {
  swapItems(this, event)
})
