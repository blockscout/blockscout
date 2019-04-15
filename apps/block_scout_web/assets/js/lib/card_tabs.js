import $ from 'jquery'

$(function () {
  const activeTabCard = $('.card-tab.active')

  if (!activeTabCard.siblings().length) {
    activeTabCard.addClass('noCaret')
  }

  activeTabCard.on('click', function (e) {
    e.preventDefault()

    const siblings = $(this).siblings()

    if (siblings.is(':hidden')) {
      siblings.show()
    } else {
      siblings.hide()
    }
  })
})
