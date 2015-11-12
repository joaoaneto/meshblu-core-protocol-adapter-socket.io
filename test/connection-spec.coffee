_ = require 'lodash'
meshblu = require 'meshblu'
async = require 'async'
uuid    = require 'uuid'
redis = require 'fakeredis'
RedisNS = require '@octoblu/redis-ns'
Server = require '../src/server'
JobManager = require 'meshblu-core-job-manager'
UpstreamMeshbluServer = require './upstream-meshblu-server'

describe 'Socket.io v1', ->
  beforeEach (done) ->
    @redisId = uuid.v1()

    @jobManager = new JobManager
      client: new RedisNS 'ns', redis.createClient(@redisId)
      timeoutSeconds: 1

    @sut = new Server
      port: 0xcafe
      client: new RedisNS 'ns', redis.createClient(@redisId)
      timeoutSeconds: 1
      meshbluConfig:
        server: 'localhost'
        port:   0xbabe

    @sut.start done

  beforeEach (done) ->
    @onUpstreamConnection = sinon.spy()
    @upstreamMeshblu = new UpstreamMeshbluServer onConnection: @onUpstreamConnection, port: 0xbabe
    @upstreamMeshblu.start done

  afterEach (done) ->
    @sut.stop done

  afterEach (done) ->
    @upstreamMeshblu.stop done

  it 'should listen on port 0xcafe', ->
    expect(@sut.address().port).to.deep.equal 0xcafe

  it 'should create a job in the job queue', (done) ->
    jobManager = new JobManager
      client: new RedisNS 'ns', redis.createClient(@redisId)
      timeoutSeconds: 1

    jobManager.getRequest ['request'], (error, request) =>
      return done error if error?
      expect(request).not.to.exist
      done()

  describe 'when the client connects to the server', ->
    beforeEach ->
      @conn = meshblu.createConnection
        server: 'localhost'
        port: 0xcafe
        uuid: 'masseuse'
        token: 'assassin'

      @conn.on 'ready', @onReady = sinon.spy()
      @conn.on 'notReady', @onNotReady = sinon.spy()

    afterEach ->
      @conn.close()

    describe 'when we have the request from the request queue', ->
      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, @request) =>
          done error

      it 'should have created an Authenticate request', ->
        expect(@request).to.containSubset
          metadata:
            jobType: 'Authenticate'
            auth:
              uuid: 'masseuse'
              token: 'assassin'

      describe 'when the Authenticate request gets a success response', ->
        beforeEach (done) ->
          response =
            metadata:
              responseId: @request.metadata.responseId
              code: 204

          @jobManager.createResponse 'response', response, done

        describe 'when connected to upstream meshblu', ->
          beforeEach (done)->
            onUpstreamConnectionCalled = => @onUpstreamConnection.called
            wait = (callback) => _.delay callback, 10
            async.until onUpstreamConnectionCalled, wait, done

          it 'should establish a connection to upstream meshblu', ->
            expect(@onUpstreamConnection).to.have.been.called

          describe 'when upstream emits a ready', ->
            beforeEach ->
              [socket] = @onUpstreamConnection.firstCall.args
              socket.emit 'ready',
                api: 'connect'
                status: 201
                uuid: 'masseuse'
                token: 'assassin'

            it 'should emit "ready" to the client connection', (done) ->
              onReadyCalled = => @onReady.called
              wait = (callback) => _.delay callback, 10

              async.until onReadyCalled, wait, =>
                expect(@onReady).to.have.been.calledWith
                  api: 'connect'
                  status: 201
                  uuid: 'masseuse'
                  token: 'assassin'
                done()

          describe 'when upstream emits a notReady', ->
            beforeEach ->
              [socket] = @onUpstreamConnection.firstCall.args
              socket.emit 'notReady',
                api: 'connect'
                status: 401
                uuid: 'masseuse'
                token: 'assassin'

            it 'should emit "notReady" to the client connection', (done) ->
              onNotReadyCalled = => @onNotReady.called
              wait = (callback) => _.delay callback, 10

              async.until onNotReadyCalled, wait, =>
                expect(@onNotReady).to.have.been.calledWith
                  api: 'connect'
                  status: 401
                  uuid: 'masseuse'
                  token: 'assassin'
                done()

      describe 'when the Authenticate request gets a failure response', ->
        beforeEach (done) ->
          response =
            metadata:
              responseId: @request.metadata.responseId
              code: 403

          @jobManager.createResponse 'response', response, done

        it 'should emit "notReady" to the client connection', (done) ->
          onNotReadyCalled = => @onNotReady.called
          wait = (callback) => _.delay callback, 10

          async.until onNotReadyCalled, wait, =>
            expect(@onNotReady).to.have.been.calledWith
              api: 'connect'
              status: 401
              uuid: 'masseuse'
              token: 'assassin'
            done()

      describe 'when the Authenticate request never responds', ->
        it 'should emit "notReady" to the client connection', (done) ->
          onNotReadyCalled = => @onNotReady.called
          wait = (callback) => _.delay callback, 10

          async.until onNotReadyCalled, wait, =>
            expect(@onNotReady).to.have.been.calledWith
              api: 'connect'
              status: 504
              uuid: 'masseuse'
              token: 'assassin'
            done()
