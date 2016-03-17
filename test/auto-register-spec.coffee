async                 = require 'async'
_                     = require 'lodash'
meshblu               = require 'meshblu'
redis                 = require 'redis'
RedisNS               = require '@octoblu/redis-ns'
Server                = require '../src/server'
UpstreamMeshbluServer = require './upstream-meshblu-server'

describe 'Auto Register', ->
  beforeEach (done) ->
    client = new RedisNS 'ns', redis.createClient()
    client.del 'request:queue', done

  beforeEach (done) ->
    @onIdentity = sinon.spy()

    @upstreamServer = new UpstreamMeshbluServer
      port: 0xbabe
      onConnection: (socket) =>
        socket.on 'identity', @onIdentity
        socket.emit 'identify'
    @upstreamServer.start done

  beforeEach (done) ->
    @sut = new Server
      port: 0xcafe
      jobTimeoutSeconds: 1
      meshbluConfig:
        server: 'localhost'
        port:   0xbabe
      jobLogRedisUri: 'redis://localhost'
      redisUri: 'redis://localhost'
      jobLogQueue: 'jobz'

    @sut.run done

  afterEach (done) ->
    @sut.stop done

  afterEach (done) ->
    @upstreamServer.stop done

  describe 'when an unauthenticated client connects', ->
    beforeEach ->
      @conn = meshblu.createConnection({server: 'localhost', port: 0xcafe})

    afterEach ->
      @conn.close()

    describe 'when connected to upstream meshblu', ->
      beforeEach (done)->
        onIdentityCalled = => @onIdentity.called
        wait = (callback) => _.delay callback, 10
        async.until onIdentityCalled, wait, done

      it 'should have called identity on the upstreamServer with no uuid or token', ->
        expect(@onIdentity).to.have.been.called
