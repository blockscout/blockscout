import $ from 'jquery'

var favoritesContainer = $('.js-favorites-tab')
var favoritesNetworksUrls = []

if (localStorage.getItem('favoritesNetworksUrls') === null) {
  localStorage.setItem('favoritesNetworksUrls', JSON.stringify(favoritesNetworksUrls))
} else {
  favoritesNetworksUrls = JSON.parse(localStorage.getItem('favoritesNetworksUrls'))
}

$(document).on('change', ".network-selector-item-favorite input[type='checkbox']", function () {
  var networkUrl = $(this).attr('data-url')
  var thisStatus = $(this).is(':checked')
  var workWith = $(".network-selector-item[data-url='" + networkUrl + "'")

  // Add new checkbox status to same network in another tabs
  $(".network-selector-item-favorite input[data-url='" + networkUrl + "']").prop('checked', thisStatus)

  // Clone
  var parent = $(".network-selector-item[data-url='" + networkUrl + "'").clone()

  // Push or remove favorite networks to array
  var found = $.inArray(networkUrl, favoritesNetworksUrls)
  if (found < 0 && thisStatus === true) {
    favoritesNetworksUrls.push(networkUrl)
  } else {
    var index = favoritesNetworksUrls.indexOf(networkUrl)
    if (index !== -1) {
      favoritesNetworksUrls.splice(index, 1)
    }
  }

  // Push to localstorage
  var willBePushed = JSON.stringify(favoritesNetworksUrls)
  localStorage.setItem('favoritesNetworksUrls', willBePushed)

  // Append or remove item from 'favorites' tab
  if (thisStatus === true) {
    favoritesContainer.append(parent[0])
    $('.js-favorites-tab .network-selector-tab-content-empty').hide()
  } else {
    var willRemoved = favoritesContainer.find(workWith)
    willRemoved.remove()
    if (favoritesNetworksUrls.length === 0) {
      $('.js-favorites-tab .network-selector-tab-content-empty').show()
    }
  }
})

if (favoritesNetworksUrls.length > 0) {
  $('.js-favorites-tab .network-selector-tab-content-empty').hide()
  for (var i = 0; i < favoritesNetworksUrls.length + 1; i++) {
    $(".network-selector-item[data-url='" + favoritesNetworksUrls[i] + "'").find('input[data-url]').prop('checked', true)
    var parent = $(".network-selector-item[data-url='" + favoritesNetworksUrls[i] + "'").clone()
    favoritesContainer.append(parent[0])
  }
}
