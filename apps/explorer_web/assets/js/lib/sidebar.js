import $ from 'jquery'

$('#sidebarCollapse').on('click', function () {
  $('#sidebar--container').toggleClass('active')
  $(this).toggleClass('active')
})
