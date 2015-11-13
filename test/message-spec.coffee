async   = require 'async'
_       = require 'lodash'
Connect = require './connect'

describe 'message', ->
  beforeEach (done) ->
    @connect = new Connect
    @connect.connect (error, things) =>
      return done error if error?
      {@sut,@connection,@device,@upstreamSocket} = things
      done()

  afterEach (done) ->
    @connect.shutItDown done

  describe 'receiving messages', ->
    describe 'when the upstream meshblu emits a message', ->
      beforeEach ->
        @connection.on 'message', @onMessage = sinon.spy()
        @upstreamSocket.emit 'message', topic: 'smelter'

      it 'should re-emit the message on the client', (done) ->
        onMessageCalled = => @onMessage.called
        wait = (callback) => _.delay callback, 10
        async.until onMessageCalled, wait, =>
          expect(@onMessage).to.have.been.calledWith topic: 'smelter'
          done()

  describe 'receiving configs', ->
    describe 'when the upstream meshblu emits a config', ->
      beforeEach ->
        @connection.on 'config', @onConfig = sinon.spy()
        @upstreamSocket.emit 'config', error: 'unable to take criticism'

      it 'should re-emit the config on the client', (done) ->
        onConfigCalled = => @onConfig.called
        wait = (callback) => _.delay callback, 10
        async.until onConfigCalled, wait, =>
          expect(@onConfig).to.have.been.calledWith error: 'unable to take criticism'
          done()

  describe 'receiving datas', ->
    describe 'when the upstream meshblu emits a data', ->
      beforeEach ->
        @connection.socket.on 'data', @onData = sinon.spy() # data is not proxied by meshblu-npm
        @upstreamSocket.emit 'data', error: 'unable to take criticism'

      it 'should re-emit the data on the client', (done) ->
        onDataCalled = => @onData.called
        wait = (callback) => _.delay callback, 10

        async.until onDataCalled, wait, =>
          expect(@onData).to.have.been.calledWith error: 'unable to take criticism'
          done()
