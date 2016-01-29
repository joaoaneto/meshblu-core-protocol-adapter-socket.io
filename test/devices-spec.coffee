Connect = require './connect'
async = require 'async'
_ = require 'lodash'
redis = require 'redis'
RedisNS = require '@octoblu/redis-ns'

describe 'Socket.io v1', ->
  beforeEach (done) ->
    client = new RedisNS 'ns', redis.createClient()
    client.del 'request:queue', done

  beforeEach (done) ->
    @connect = new Connect
    @connect.connect (error, things)=>
      return done error if error?
      {@sut,@connection,@upstreamSocket} = things
      done()

  afterEach (done) ->
    @connect.shutItDown done

  describe '->devices', ->
    beforeEach ->
      @upstreamSocket.on 'devices', @onDevices = sinon.spy()
      @callback = sinon.spy()
      @connection.devices {uuid: 'hi'}, @callback

    describe 'when devices has been received by the upstream server', ->
      beforeEach (done) ->
        onDevicesCalled = => @onDevices.called
        wait = (callback) => _.delay callback, 10
        async.until onDevicesCalled, wait, done

      it 'should emit devices on the upstream server', ->
        expect(@onDevices).to.have.been.calledWith uuid: 'hi'

      describe 'when the upstream server replies to the devices call', ->
        beforeEach ->
          @onDevices.yield {devices: [{}, {}]}

        it 'should call the callback with the response', (done) ->
          callbackCalled = => @callback.called
          wait = (callback) => _.delay callback, 10

          async.until callbackCalled, wait, =>
            expect(@callback).to.have.been.calledWith {devices: [{}, {}]}
            done()
