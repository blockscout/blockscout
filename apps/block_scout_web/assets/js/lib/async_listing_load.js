import $ from 'jquery'
/**
 * This script is a generic function to load list within a tab async. See token transfers tab at Token's page as example.
 *
 * To get it working the markup must follow the pattern below:
 *
 * <div data-async-listing="path">
 *   <div data-loading-message> message </div>
 *   <div data-empty-response-message style="display: none;"> message </div>
 *   <div data-error-message style="display: none;"> message </div>
 *   <div data-items></div>
 *   <a data-next-page-button style="display: none;"> button text </a>
 *   <div data-loading-button style="display: none;"> loading text </div>
 * </div>
 *
 */
const $element = $('[data-async-listing]')

function asyncListing (element, path) {
  const $mainElement = $(element)
  const $items = $mainElement.find('[data-items]')
  const $loading = $mainElement.find('[data-loading-message]')
  const $nextPageButton = $mainElement.find('[data-next-page-button]')
  const $loadingButton = $mainElement.find('[data-loading-button]')
  const $errorMessage = $mainElement.find('[data-error-message]')
  const $emptyResponseMessage = $mainElement.find('[data-empty-response-message]')

  $.getJSON(path, {type: 'JSON'})
    .done(response => {
      if (!response.items || response.items.length === 0) {
        $emptyResponseMessage.show()
        $items.empty()
      } else {
        $items.html(response.items)
      }
      if (response.next_page_path) {
        $nextPageButton.attr('href', response.next_page_path)
        $nextPageButton.show()
      } else {
        $nextPageButton.hide()
      }
    })
    .fail(() => $errorMessage.show())
    .always(() => {
      $loading.hide()
      $loadingButton.hide()
    })
}

if ($element.length === 1) {
  $element.on('click', '[data-next-page-button]', (event) => {
    event.preventDefault()

    const $button = $(event.target)
    const path = $button.attr('href')
    const $loadingButton = $element.find('[data-loading-button]')

    // change url to the next page link before loading the next page
    history.pushState({}, null, path)
    $button.hide()
    $loadingButton.show()

    asyncListing($element, path)
  })

  $element.on('click', '[data-error-message]', (event) => {
    event.preventDefault()

    // event.target had a weird behavior here
    // it hid the <a> tag but left the red div showing
    const $link = $element.find('[data-error-message]')
    const $loading = $element.find('[data-loading-message]')
    const path = $element.data('async-listing')

    $link.hide()
    $loading.show()

    asyncListing($element, path)
  })

  // force browser to reload when the user goes back a page
  $(window).on('popstate', () => location.reload())

  asyncListing($element, $element.data('async-listing'))
}
