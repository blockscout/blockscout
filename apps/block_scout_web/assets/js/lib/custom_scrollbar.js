import $ from 'jquery'
import 'malihu-custom-scrollbar-plugin/jquery.mCustomScrollbar.concat.min'

$(function() {
  $(".mCustomScrollbar").mCustomScrollbar({
    callbacks: {
      onOverflowY: () => {
        $("#txActionsTitle .note").css("display", "block");
      },
      onOverflowYNone: () => {
        $("#txActionsTitle .note").css("display", "none");
      }
    },
    theme: "dark",
    autoHideScrollbar: true,
    scrollButtons: {enable: false},
    scrollbarPosition: "outside"
  });
});
