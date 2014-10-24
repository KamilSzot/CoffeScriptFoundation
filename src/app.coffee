document.addEventListener 'DOMContentLoaded', ->
  console.log "Hello World"
  document.body.appendChild document.createTextNode new Date()
