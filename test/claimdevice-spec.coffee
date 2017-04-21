async   = require 'async'
_       = require 'lodash'
Connect = require './connect'
redis = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'

describe 'emit: claimdevice', ->
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
      request =
        uuid: @device.uuid

      @connection.socket.emit 'claimdevice', request, @onResponse = sinon.spy()

    describe 'when it has created a request', ->
      beforeEach 'getRequest', (done) ->
        @jobManager.wait (error, {@request, @callback}) =>
          done error

      it 'should create an UpdateDevice request', ->
        expect(@request).to.containSubset
          metadata:
            auth:
              uuid: @device.uuid
              token: @device.token
            jobType: 'UpdateDevice'
            toUuid: @device.uuid
          rawData: '{"$set":{"owner":"masseuse"},"$addToSet":{"discoverWhitelist":"masseuse","configureWhitelist":"masseuse"}}'

      describe 'when the job responds with success', ->
        beforeEach ->
          response =
            metadata:
              responseId: @request.metadata.responseId
              code: 204
              status: 'No Content'
            rawData: '{"metadata":{"code":204,"status":"No Content"}}'

          @callback null, response

        it 'should call the callback with the response', (done) ->
          onResponseCalled = => @onResponse.called
          wait = (callback) => _.delay callback, 10

          async.until onResponseCalled, wait, =>
            [response] = @onResponse.firstCall.args
            expect(response).to.containSubset
              status: 200
              uuid: 'masseuse'
            done()
