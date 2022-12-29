import $ from 'jquery'
import { addChainToMM } from '../lib/add_chain_to_mm'

$(document).click(function (event) {
  const clickover = $(event.target)
  const _opened = $('.navbar-collapse').hasClass('show')
  if (_opened === true && $('.navbar').find(clickover).length < 1) {
    $('.navbar-toggler').click()
  }
})

const search = (value) => {
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
$('#search-btn').on('click', function (event) {
  const value = $('.main-search-autocomplete').val() || $('.main-search-autocomplete-mobile').val()
  search(value)
})
if(window.innerWidth <= 992){
  if(document.getElementsByClassName('search-btn-cls') && document.getElementsByClassName('search-btn-cls').length > 1){
    document.getElementsByClassName('search-btn-cls')[1].addEventListener('click', function (){
      const els = document.getElementsByClassName('main-search-autocomplete');
      if(els && els.length > 1){
        let value = els[1].value
        if(value){
          search(value)
        }
      }
    })
  }
}

if(window.innerWidth <= 992){
  if(document.getElementsByClassName('search-icon-cls') && document.getElementsByClassName('search-icon-cls').length > 1){
    document.getElementsByClassName('search-icon-cls')[1].addEventListener('click', function (){
      const els = document.getElementsByClassName('main-search-autocomplete');
      if(els && els.length > 1){
        let value = els[1].value
        if(value){
          search(value)
        }
      }
    })
  }
}

$('.main-search-autocomplete').on('focus', function (_event) {
  $('#slash-icon').hide()
  //$('.search-control').addClass('focused-field')
})

$('.main-search-autocomplete').on('focusout', function (_event) {
  $('#slash-icon').show()
  //$('.search-control').removeClass('focused-field')
})
