async   = require 'async'
_       = require 'lodash'
Connect = require './connect'
redis   = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'

describe 'emit: unregister', ->
  beforeEach (done) ->
    client = new RedisNS 'ns', redis.createClient(dropBufferSupport: true)
    client.del 'request:queue', done
    return # promises

  beforeEach (done) ->
    @connect = new Connect
    @connect.connect (error, things) =>
      return done error if error?
      {@sut,@connection,@device,@jobManager} = things
      done()

  afterEach (done) ->
    @connect.shutItDown done

  describe 'when called', ->
    beforeEach ->
      @connection.socket.emit 'unregister', {uuid:'great-scott'}, @onResponse = sinon.spy()

    describe 'when it has created a request', ->
      beforeEach (done) ->
        @jobManager.wait (error, {@request, @callback}) =>
          done error

      it 'should create an UnregisterDevice request', ->
        expect(@request).to.containSubset
          metadata:
            auth:
              uuid: @device.uuid
              token: @device.token
            jobType: 'UnregisterDevice'
            toUuid: 'great-scott'
          rawData: '{}'

      describe 'when the job responds with success', ->
        beforeEach ->
          response =
            metadata:
              responseId: @request.metadata.responseId
              code: 204
              status: 'No Content'
            data: {}

          @callback null, response

        it 'should call the callback with the response', (done) ->
          onResponseCalled = => @onResponse.called
          wait = (callback) => _.delay callback, 10

          async.until onResponseCalled, wait, =>
            [response] = @onResponse.firstCall.args
            expect(response).to.containSubset
              uuid: 'great-scott'
            done()

      describe 'when the job responds with failure', ->
        beforeEach ->
          response =
            metadata:
              responseId: @request.metadata.responseId
              code: 422
              status: 'Unprocessable Entity'

          @callback null, response

        it 'should call the callback with the response', (done) ->
          onResponseCalled = => @onResponse.called
          wait = (callback) => _.delay callback, 10

          async.until onResponseCalled, wait, =>
            [response] = @onResponse.firstCall.args
            expect(response.error).to.equal 'Unprocessable Entity'
            done()

      describe 'when the job never responds', ->
        it 'should call the callback with the response', (done) ->
          onResponseCalled = => @onResponse.called
          wait = (callback) => _.delay callback, 10

          async.until onResponseCalled, wait, =>
            [response] = @onResponse.firstCall.args
            expect(response.error).to.equal 'Response timeout exceeded'
            done()
