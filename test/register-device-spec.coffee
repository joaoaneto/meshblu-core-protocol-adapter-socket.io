async   = require 'async'
_       = require 'lodash'
Connect = require './connect'
redis   = require 'redis'
RedisNS = require '@octoblu/redis-ns'

describe 'emit: register', ->
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
      @connection.socket.emit 'register', {type:"yo"}, @onResponse = sinon.spy()

    describe 'when it has created a request', ->
      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, @request) =>
          expect(@request).to.exist
          done error

      it 'should create an GetStatus request', ->
        expect(@request).to.containSubset
          metadata:
            jobType: 'RegisterDevice'
          rawData: '{"type":"yo","discoverWhitelist":["*"],"configureWhitelist":["*"],"sendWhitelist":["*"],"receiveWhitelist":["*"]}'

      describe 'when the job responds with success', ->
        beforeEach (done) ->
          response =
            metadata:
              responseId: @request.metadata.responseId
              code: 200
              status: 'OK'
            data:
              uuid: 'hello'
              token: 'secret-greeting'
              type: 'yo'

          @jobManager.createResponse 'response', response, done

        it 'should call the callback with the response', (done) ->
          onResponseCalled = => @onResponse.called
          wait = (callback) => _.delay callback, 10

          async.until onResponseCalled, wait, =>
            [response] = @onResponse.firstCall.args
            expect(response).to.deep.equal
              uuid: 'hello'
              token: 'secret-greeting'
              type: 'yo'
            done()

  describe 'when called with a owner', ->
    beforeEach ->
      @connection.socket.emit 'register', {owner:"yo-uuid"}, @onResponse = sinon.spy()

    describe 'when it has created a request', ->
      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, @request) =>
          expect(@request).to.exist
          done error

      it 'should create an GetStatus request', ->
        expect(@request).to.containSubset
          metadata:
            jobType: 'RegisterDevice'
          rawData: '{"owner":"yo-uuid","discoverWhitelist":["yo-uuid"],"configureWhitelist":["yo-uuid"],"sendWhitelist":["*"],"receiveWhitelist":["*"]}'

      describe 'when the job responds with success', ->
        beforeEach (done) ->
          response =
            metadata:
              responseId: @request.metadata.responseId
              code: 200
              status: 'OK'
            data:
              uuid: 'hello'
              token: 'secret-greeting'
              owner: 'yo-uuid'
              discoverWhitelist: ['yo-uuid']
              configureWhitelist: ['yo-uuid']

          @jobManager.createResponse 'response', response, done

        it 'should call the callback with the response', (done) ->
          onResponseCalled = => @onResponse.called
          wait = (callback) => _.delay callback, 10

          async.until onResponseCalled, wait, =>
            [response] = @onResponse.firstCall.args
            expect(response).to.deep.equal
              uuid: 'hello'
              token: 'secret-greeting'
              owner: 'yo-uuid'
              discoverWhitelist: ['yo-uuid']
              configureWhitelist: ['yo-uuid']
            done()
