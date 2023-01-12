import $ from 'jquery'
import { addChainToMM } from '../lib/add_chain_to_mm'
import * as analytics from '../lib/analytics'

analytics.init()

const simpleEvents = {
  '.profile-button': 'Profile click',
  '.watchlist-button': 'Watch list click',
  '.address-tags-button': 'Address tags click',
  '.transaction-tags-button': 'Transaction tags click',
  '.api-keys-button': 'API keys click',
  '.custom-abi-button': 'Custom ABI click',
  '.public-tags-button': 'Public tags click',
  '.sign-out-button': 'Sign out click',
  '.sign-in-button': 'Sign in click',
  '.add-address-button': 'Add address to watch list click',
  '.add-address-tag-button': 'Add address tag click',
  '.add-transaction-tag-button': 'Add transaction tag click',
  '.add-api-key-button': 'Add API key click',
  '.add-custom-abi-button': 'Add custom ABI click',
  '.add-public-tag-button': 'Request to add public tag click'
}

if (analytics.mixpanelInitialized || analytics.amplitudeInitialized) {
  for (const elementClass in simpleEvents) {
    $(elementClass).click((_event) => {
      analytics.trackEvent(simpleEvents[elementClass])
    })
  }
}

$('.save-address-button').click((_event) => {
  const eventProperties = {
    address_hash: $('#watchlist_address_address_hash').val(),
    private_tag: $('#watchlist_address_name').val(),
    eth_incoming: $('#watchlist_address_watch_coin_input').prop('checked'),
    eth_outgoing: $('#watchlist_address_watch_coin_output').prop('checked'),
    erc_20_incoming: $('#watchlist_address_watch_erc_20_input').prop('checked'),
    erc_20_outgoing: $('#watchlist_address_watch_erc_20_output').prop('checked'),
    erc_721_1155_incoming: $('#watchlist_address_watch_erc_721_input').prop('checked'),
    erc_721_1155_outgoing: $('#watchlist_address_watch_erc_721_output').prop('checked'),
    email_notifications: $('#watchlist_address_notify_email').prop('checked')
  }
  const eventName = 'New address to watchlist completed'

  analytics.trackEvent(eventName, eventProperties)
})

$('.save-address-tag-button').click((_event) => {
  const eventName = 'Add address tag completed'
  const eventProperties = {
    address_hash: $('#tag_address_address_hash').val(),
    private_tag: $('#tag_address_name').val()
  }

  analytics.trackEvent(eventName, eventProperties)
})

$('.save-transaction-tag-button').click((_event) => {
  const eventName = 'Add transaction tag completed'
  const eventProperties = {
    address_hash: $('#tag_transaction_tx_hash').val(),
    private_tag: $('#tag_transaction_name').val()
  }

  analytics.trackEvent(eventName, eventProperties)
})

$('.save-api-key-button').click((_event) => {
  const eventName = 'Generate API key completed'
  const eventProperties = {
    application_name: $('#key_name').val()
  }

  analytics.trackEvent(eventName, eventProperties)
})

$('.save-custom-abi-button').click((_event) => {
  const eventName = 'Custom ABI completed'
  const eventProperties = {
    smart_contract_address: $('#custom_abi_address_hash').val(),
    project_name: $('#custom_abi_name').val(),
    custom_abi: $('#custom_abi_abi').val()
  }

  analytics.trackEvent(eventName, eventProperties)
})

$('.send-public-tag-request-button').click((_event) => {
  const eventName = 'Request a public tag completed'
  const eventProperties = {
    name: $('#public_tags_request_full_name').val(),
    email: $('#public_tags_request_email').val(),
    company_name: $('#public_tags_request_company').val(),
    company_website: $('#public_tags_request_website').val(),
    goal: $('#public_tags_request_is_owner_true').prop('checked') ? 'Add tags' : 'Incorrect public tag',
    public_tag: $('#public_tags_request_tags').val(),
    smart_contracts: $('*[id=public_tags_request_addresses]').map((_i, el) => {
      return el.value
    }).get(),
    reason: $('#public_tags_request_additional_comment').val()
  }

  analytics.trackEvent(eventName, eventProperties)
})

$(document).ready(() => {
  let timer
  const waitTime = 500
  const observer = new MutationObserver((mutations) => {
    if (mutations[0].target.hidden) {
      return
    }

    const $results = $('li[id^="autoComplete_result_"]')

    clearTimeout(timer)
    timer = setTimeout(() => {
      let eventName = 'Occurs searching according to substring at the nav bar'
      let eventProperties = {
        search: $('.main-search-autocomplete').val() || $('.main-search-autocomplete-mobile').val()
      }

      analytics.trackEvent(eventName, eventProperties)

      eventName = 'Search list displays at the nav bar'
      eventProperties = {
        resultsNumber: $results.length,
        results: $results.map((_i, el) => {
          return el.children[1].innerText
        })
      }

      analytics.trackEvent(eventName, eventProperties)
    }, waitTime)

    $results.click((event) => {
      const eventName = 'Search item click at the nav bar'
      const eventProperties = {
        item: event.currentTarget.innerText
      }

      analytics.trackEvent(eventName, eventProperties)
    })
  })
  observer.observe($('#autoComplete_list_1')[0], {
    attributeFilter: ['hidden'],
    childList: true
  })
  observer.observe($('#autoComplete_list_2')[0], {
    attributeFilter: ['hidden']
  })
})

$(document).click(function (event) {
  const clickover = $(event.target)
  const _opened = $('.navbar-collapse').hasClass('show')
  if (_opened === true && $('.navbar').find(clickover).length < 1) {
    $('.navbar-toggler').click()
  }
})

const search = (value) => {
  const eventName = 'Occurs searching according to substring at the nav bar'
  const eventProperties = {
    search: value
  }

  analytics.trackEvent(eventName, eventProperties)

  if (value) {
    window.location.href = `/search?q=${value}`
  }
}

$(document)
  .on('keyup', function (event) {
    if (event.key === '/') {
      $('.main-search-autocomplete').trigger('focus')
    }
  })
  .on('click', '.js-btn-add-chain-to-mm', event => {
    const $btn = $(event.target)
    addChainToMM({ btn: $btn })
  })

$('.main-search-autocomplete').on('keyup', function (event) {
  if (event.key === 'Enter') {
    let selected = false
    $('li[id^="autoComplete_result_"]').each(function () {
      if ($(this).attr('aria-selected')) {
        selected = true
      }
    })
    if (!selected) {
      search(event.target.value)
    }
  }
})

$('#search-icon').on('click', function (event) {
  const value = $('.main-search-autocomplete').val() || $('.main-search-autocomplete-mobile').val()
  search(value)
})

$('.main-search-autocomplete').on('focus', function (_event) {
  $('#slash-icon').hide()
  $('.search-control').addClass('focused-field')
})

$('.main-search-autocomplete').on('focusout', function (_event) {
  $('#slash-icon').show()
  $('.search-control').removeClass('focused-field')
})
