import $ from 'jquery'

let $currentModal = null
let modalLocked = false

const spinner =
  `
    <span class="loading-spinner-small mr-2">
      <span class="loading-spinner-block-1"></span>
      <span class="loading-spinner-block-2"></span>
    </span>
  `

$(document.body).on('hide.bs.modal', e => {
  if (modalLocked) {
    e.preventDefault()
    e.stopPropagation()
    return false
  }

  $currentModal = null
})

export function openModal ($modal) {
  // Hide all tooltips before showing a modal,
  // since they are sticking on top of modal
  $('.tooltip').tooltip('hide')
  if ($currentModal) {
    modalLocked = false

    $currentModal
      .one('hidden.bs.modal', () => {
        $modal.modal('show')
        $currentModal = $modal
      })
      .modal('hide')
  } else {
    $modal.modal('show')
    $currentModal = $modal
  }
}

export function lockModal ($modal, $submitButton = null) {
  $modal.find('.close-modal').attr('disabled', true)

  const $button = $submitButton || $modal.find('.btn-add-full')

  $button
    .attr('data-text', $button.text())
    .attr('disabled', true)
    .html(spinner)

  modalLocked = true
}

export function unlockModal ($modal, $submitButton = null) {
  $modal.find('.close-modal').attr('disabled', false)

  const $button = $submitButton || $modal.find('.btn-add-full')

  $button
    .text($button.attr('data-text'))
    .attr('disabled', false)

  modalLocked = false
}

export function openErrorModal (title, text) {
  const $modal = $('#errorStatusModal')
  $modal.find('.modal-status-title').text(title)
  $modal.find('.modal-status-text').html(text)
  openModal($modal)
}

export function openWarningModal (title, text) {
  const $modal = $('#warningStatusModal')
  $modal.find('.modal-status-title').text(title)
  $modal.find('.modal-status-text').html(text)
  openModal($modal)
}

export function openSuccessModal (title, text) {
  const $modal = $('#successStatusModal')
  $modal.find('.modal-status-title').text(title)
  $modal.find('.modal-status-text').text(text)
  openModal($modal)
}

export function openQuestionModal (title, text, acceptCallback = null, exceptCallback = null, acceptText = 'Yes', exceptText = 'No') {
  const $modal = $('#questionStatusModal')

  $modal.find('.modal-status-title').text(title)
  $modal.find('.modal-status-text').text(text)

  const $accept = $modal.find('.btn-line.accept')
  const $except = $modal.find('.btn-line.except')

  $accept
    .removeAttr('data-dismiss')
    .unbind('click')
    .find('.btn-line-text').text(acceptText)

  $except.removeAttr('data-dismiss')
    .removeAttr('data-dismiss')
    .unbind('click')
    .find('.btn-line-text').text(exceptText)

  if (acceptCallback) {
    $accept.on('click', event => {
      $accept
        .unbind('click')
        .find('.btn-line-text').html(spinner)
      $except
        .unbind('click')
        .removeAttr('data-dismiss')

      modalLocked = true
      acceptCallback($modal, event)
    })
  } else {
    $accept.attr('data-dismiss', 'modal')
  }

  if (exceptCallback) {
    $except.on('click', event => {
      $modal.find('.close-modal').attr('disabled', true)

      $except
        .unbind('click')
        .find('.btn-line-text').html(spinner)
      $accept
        .unbind('click')
        .removeAttr('data-dismiss')

      modalLocked = true
      exceptCallback($modal, event)
    })
  } else {
    $except.attr('data-dismiss', 'modal')
  }

  openModal($modal)
}
