async   = require 'async'
_       = require 'lodash'
Connect = require './connect'
redis = require 'redis'
RedisNS = require '@octoblu/redis-ns'

describe 'emit: whoami', ->
  beforeEach (done) ->
    client = new RedisNS 'ns', redis.createClient()
    client.del 'request:queue', done

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
      @connection.socket.emit 'whoami', {}, @onResponse = sinon.spy()

    describe 'when it has created a request', ->
      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, @request) =>
          expect(@request).to.exist
          done error

      it 'should create an GetDevice request', ->
        expect(@request).to.containSubset
          metadata:
            auth:
              uuid: @device.uuid
              token: @device.token
            jobType: 'GetDevice'
            fromUuid: @device.uuid
            toUuid: @device.uuid

      describe 'when the job responds with success', ->
        beforeEach (done) ->
          response =
            metadata:
              responseId: @request.metadata.responseId
              code: 200
              status: 'OK'
            data:
              uuid: @device.uuid

          @jobManager.createResponse 'response', response, done

        it 'should call the callback with the response', (done) ->
          onResponseCalled = => @onResponse.called
          wait = (callback) => _.delay callback, 10

          async.until onResponseCalled, wait, =>
            [response] = @onResponse.firstCall.args
            expect(response).to.containSubset
              uuid: @device.uuid
            done()

      describe 'when the job responds with failure', ->
        beforeEach (done) ->
          response =
            metadata:
              responseId: @request.metadata.responseId
              code: 422
              status: 'No Content'

          @jobManager.createResponse 'response', response, done

        it 'should call the callback with the response', (done) ->
          onResponseCalled = => @onResponse.called
          wait = (callback) => _.delay callback, 10

          async.until onResponseCalled, wait, =>
            [response] = @onResponse.firstCall.args
            expect(response).to.be.null
            done()

      describe 'when the job never responds', ->
        it 'should call the callback with the response', (done) ->
          onResponseCalled = => @onResponse.called
          wait = (callback) => _.delay callback, 10

          async.until onResponseCalled, wait, =>
            [response] = @onResponse.firstCall.args
            expect(response).to.be.null
            done()
