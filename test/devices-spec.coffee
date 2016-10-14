async   = require 'async'
_       = require 'lodash'
Connect = require './connect'
redis   = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'

describe 'emit: devices', ->
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
      @connection.socket.emit 'devices', {type:'google-it'}, @onResponse = sinon.spy()

    describe 'when it has created a request', ->
      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, @request) =>
          expect(@request).to.exist
          done error

      it 'should create an SearchDevices request', ->
        expect(@request).to.containSubset
          metadata:
            auth:
              uuid: @device.uuid
              token: @device.token
            jobType: 'SearchDevices'
            fromUuid: 'masseuse'
          rawData: '{"type":"google-it"}'

      describe 'when the job responds with success', ->
        beforeEach (done) ->
          response =
            metadata:
              responseId: @request.metadata.responseId
              code: 200
              status: 'OK'
            data: [
              {uuid: '1'}
              {uuid: '2'}
              {uuid: '3'}
            ]

          @jobManager.createResponse 'response', response, done

        it 'should call the callback with the response', (done) ->
          onResponseCalled = => @onResponse.called
          wait = (callback) => _.delay callback, 10

          async.until onResponseCalled, wait, =>
            [response] = @onResponse.firstCall.args
            expect(response.devices).to.deep.equal [
              {uuid: '1'}
              {uuid: '2'}
              {uuid: '3'}
            ]
            done()

  describe 'when called with uuid and token', ->
    beforeEach ->
      @connection.socket.emit 'devices', {uuid: 'great-scott', token: 'great-token'}, @onResponse = sinon.spy()

    describe 'when it has created a request', ->
      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, @request) =>
          expect(@request).to.exist
          done error

      it 'should create an SearchDevices request', ->
        expect(@request).to.containSubset
          metadata:
            auth:
              uuid: 'great-scott'
              token: 'great-token'
            jobType: 'SearchDevices'
            fromUuid: 'great-scott'
          rawData: '{"uuid":"great-scott"}'

      describe 'when the job responds with success', ->
        beforeEach (done) ->
          response =
            metadata:
              responseId: @request.metadata.responseId
              code: 200
              status: 'OK'
            data: [
              {uuid: '1'}
              {uuid: '2'}
              {uuid: '3'}
            ]

          @jobManager.createResponse 'response', response, done

        it 'should call the callback with the response', (done) ->
          onResponseCalled = => @onResponse.called
          wait = (callback) => _.delay callback, 10

          async.until onResponseCalled, wait, =>
            [response] = @onResponse.firstCall.args
            expect(response.devices).to.deep.equal [
              {uuid: '1'}
              {uuid: '2'}
              {uuid: '3'}
            ]
            done()
