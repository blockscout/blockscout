import $ from 'jquery'

$(function () {
  const mainBody = $('body')
  const showNetworkSelector = $('.js-show-network-selector')
  const hideNetworkSelector = $('.js-network-selector-close')
  const hideNetworkSelectorOverlay = $('.js-network-selector-overlay-close')
  const networkSelector = $('.js-network-selector')
  const networkSelectorOverlay = $('.js-network-selector-overlay')
  const networkSelectorTab = $('.js-network-selector-tab')
  const networkSelectorTabContent = $('.js-network-selector-tab-content')
  const networkSelectorItemURL = $('.js-network-selector-item-url')
  const FADE_IN_DELAY = 250

  showNetworkSelector.on('click', (e) => {
    e.preventDefault()
    openNetworkSelector()
  })

  hideNetworkSelector.on('click', (e) => {
    e.preventDefault()
    closeNetworkSelector()
  })

  hideNetworkSelectorOverlay.on('click', (e) => {
    e.preventDefault()
    closeNetworkSelector()
  })

  networkSelectorTab.on('click', function (e) {
    e.preventDefault()
    setNetworkTab($(this))
  })

  networkSelectorItemURL.on('click', function (e) {
    window.location = $(this).attr('network-selector-item-url')
  })

  const setNetworkTab = (currentTab) => {
    if (currentTab.hasClass('active')) return

    networkSelectorTab.removeClass('active')
    currentTab.addClass('active')
    networkSelectorTabContent.removeClass('active')
    $(`[network-selector-tab="${currentTab.attr('network-selector-tab-filter')}"]`).addClass('active')
  }

  const openNetworkSelector = () => {
    mainBody.addClass('network-selector-visible')
    networkSelectorOverlay.fadeIn(FADE_IN_DELAY)
    setNetworkSelectorVisiblePosition()
  }

  const closeNetworkSelector = () => {
    mainBody.removeClass('network-selector-visible')
    networkSelectorOverlay.fadeOut(FADE_IN_DELAY)
    setNetworkSelectorHiddenPosition()
  }

  const getNetworkSelectorWidth = () => {
    return parseInt(networkSelector.css('width')) || parseInt(networkSelector.css('max-width'))
  }

  const setNetworkSelectorHiddenPosition = () => {
    return networkSelector.css({ right: `-${getNetworkSelectorWidth()}px` })
  }

  const setNetworkSelectorVisiblePosition = () => {
    return networkSelector.css({ right: '0' })
  }

  const init = () => {
    setNetworkSelectorHiddenPosition()
  }

  init()
})
