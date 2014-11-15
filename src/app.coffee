# @cjsx React.DOM

$ = require "jquery"
esprima = require "esprima"
mod = require "./section/mod"

document.addEventListener 'DOMContentLoaded', ->
  console.log "Hello World"
  document.body.appendChild document.createTextNode new Date()
  $('body').css({ background: 'pink' })



Car = React.createClass
  render: ->
    <Vehicle doors={4} locked={isLocked()}  data-colour="red" on>
      <Parts.FrontSeat />
      <Parts.BackSeat />
      <p className="kickin">Which seat can I take? {@props?.seat or 'none'}</p>
    </Vehicle>
