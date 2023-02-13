import $ from 'jquery'
import 'malihu-custom-scrollbar-plugin/jquery.mCustomScrollbar.concat.min'

$(function () {
  const scrollBar = $('.mCustomScrollbar')
  scrollBar.mCustomScrollbar({
    callbacks: {
      onOverflowY: () => {
        $('#actions-list-scroll-note').css('display', 'block')
        scrollBar.removeClass('mCS_no_scrollbar_y')
      },
      onOverflowYNone: () => {
        $('#actions-list-scroll-note').css('display', 'none')
        scrollBar.addClass('mCS_no_scrollbar_y')
      }
    },
    theme: 'dark',
    autoHideScrollbar: true,
    scrollButtons: { enable: false },
    scrollbarPosition: 'outside'
  })
})
