_ = require 'lodash'

# bdd
chai = require 'chai'
chai.should()

describe 'argv', ->

  describe 'when credentials are not provided', ->
    @timeout 10000

    it 'throws with neither username nor password', ->
      yargs [], true
      _.partial(require, '..').should.Throw()

    it 'throws without username', ->
      yargs ['-p', 'password'], true
      _.partial(require, '..').should.Throw()

    it 'throws without password', ->
      yargs ['-u', 'tester@testing.org'], true
      _.partial(require, '..').should.Throw()

describe 'inflate', ->
  inflate = null

  before ->
    yargs '-u tester@testing.org -p password'.split ' '
    {inflate} = require '..'

  it 'should be instantiated', ->
    inflate.should.not.be.null

yargs = (args=[], graceful) ->
  argv = require('yargs')(args)
  argv.exitProcess not graceful
  argv.showHelpOnFail not graceful
