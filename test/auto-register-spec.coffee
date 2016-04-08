async                 = require 'async'
_                     = require 'lodash'
meshblu               = require 'meshblu'
redis                 = require 'ioredis'
RedisNS               = require '@octoblu/redis-ns'
Server                = require '../src/server'
UpstreamMeshbluServer = require './upstream-meshblu-server'
JobManager            = require 'meshblu-core-job-manager'

describe 'Auto Register', ->
  beforeEach (done) ->
    client = new RedisNS 'ns', redis.createClient()
    client.del 'request:queue', done

  beforeEach ->
    @jobManager = new JobManager
      client: new RedisNS 'ns', redis.createClient()
      timeoutSeconds: 10

  beforeEach (done) ->
    @sut = new Server
      namespace: 'ns'
      port: 0xcafe
      jobTimeoutSeconds: 10
      jobLogRedisUri: 'redis://localhost'
      redisUri: 'redis://localhost'
      jobLogQueue: 'jobz'
      jobLogSampleRate: 0
      maxConnections: 10

    @sut.run done

  afterEach (done) ->
    @sut.stop done

  describe 'when an unauthenticated client connects', ->
    @timeout 5000
    beforeEach (done) ->
      doneOnce = _.once done
      @conn = meshblu.createConnection({server: 'localhost', port: 0xcafe})
      @jobManager.getRequest ['request'], (error, @request) =>
        return done error if error?

        response =
          metadata:
            responseId: @request.metadata.responseId
            code: 204
          data:
            uuid: 'new-uuid'
            token: 'new-token'

        @jobManager.createResponse 'response', response, ->

      setTimeout doneOnce, 4000
      @conn.once 'ready', (@device) =>
        doneOnce()

    afterEach ->
      @conn.close()

    it 'should create a device', ->
      expect(@device.uuid).to.exist
      expect(@device.token).to.exist
