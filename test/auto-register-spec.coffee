_       = require 'lodash'
meshblu = require 'meshblu'
Redis   = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'
Server  = require '../src/server'
UUID    = require 'uuid'
{ JobManagerResponder } = require 'meshblu-core-job-manager'

describe 'Auto Register', ->
  beforeEach ->
    queueId = UUID.v4()
    @namespace = 'ns'
    @redisUri = 'redis://localhost'
    @requestQueueName = "test:request:queue:#{queueId}"
    @responseQueueName = "test:response:queue:#{queueId}"

  beforeEach (done) ->
    @jobManager = new JobManagerResponder {
      @redisUri
      @namespace
      maxConnections: 1
      jobTimeoutSeconds: 10
      queueTimeoutSeconds: 10
      jobLogSampleRate: 0
      @requestQueueName
      @responseQueueName
    }
    @jobManager.start done

  afterEach (done) ->
    @jobManager.stop done

  beforeEach (done) ->
    @sut = new Server {
      namespace: @namespace
      port: 0xcafe
      jobTimeoutSeconds: 10
      jobLogRedisUri: @redisUri
      redisUri: @redisUri
      cacheRedisUri: @redisUri
      firehoseRedisUri: @redisUri
      jobLogQueue: 'jobz'
      jobLogSampleRate: 0
      maxConnections: 10
      @requestQueueName
      @responseQueueName
    }

    @sut.run done

  afterEach (done) ->
    @sut.stop done

  describe 'when an unauthenticated client connects', ->
    @timeout 5000
    beforeEach (done) ->
      doneOnce = _.once done
      @conn = meshblu.createConnection({server: 'localhost', port: 0xcafe})
      @jobManager.do (@request, callback) =>
        response =
          metadata:
            responseId: @request.metadata.responseId
            code: 204
          data:
            uuid: 'new-uuid'
            token: 'new-token'

        callback null, response

      setTimeout doneOnce, 4000
      @conn.once 'ready', (@device) =>
        doneOnce()

    afterEach (done) ->
      @conn.close done

    it 'should create a device', ->
      expect(@device.uuid).to.exist
      expect(@device.token).to.exist
