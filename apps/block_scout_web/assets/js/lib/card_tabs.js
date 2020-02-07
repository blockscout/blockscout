import $ from 'jquery'

$(function () {
  const tabCards = $('.js-card-tabs')
  const activeTabCard = tabCards.find('.active')
  const isMobileCardTabs = tabCards.children(':hidden').length
  const isOnlyChild = !activeTabCard.siblings().length

  if (isOnlyChild) {
    activeTabCard.addClass('noCaret')
  }

  activeTabCard.on('click', function (e) {
    e.preventDefault()

    if (isMobileCardTabs) {
      const siblings = $(this).siblings()

      if (siblings.is(':hidden')) {
        siblings.css({ display: 'flex' })
      } else {
        siblings.hide()
      }
    }
  })
})
