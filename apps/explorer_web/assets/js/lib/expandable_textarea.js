import $ from 'jquery'

$('[data-is-expandable]').on( 'change keyup keydown paste cut', 'textarea', function (){
  $(this).height(0).height(this.scrollHeight);
}).find( 'textarea' ).change();
