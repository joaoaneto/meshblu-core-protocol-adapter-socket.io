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
    @requestQueueName = "test:request:queue:#{queueId}"
    @responseQueueName = "test:response:queue:#{queueId}"
    @jobManager = new JobManagerResponder {
      client: new RedisNS 'ns', new Redis 'localhost', dropBufferSupport: true
      queueClient: new RedisNS 'ns', new Redis 'localhost', dropBufferSupport: true
      jobTimeoutSeconds: 10
      queueTimeoutSeconds: 10
      jobLogSampleRate: 0
      @requestQueueName
      @responseQueueName
    }

  beforeEach (done) ->
    @sut = new Server {
      namespace: 'ns'
      port: 0xcafe
      jobTimeoutSeconds: 10
      jobLogRedisUri: 'redis://localhost'
      redisUri: 'redis://localhost'
      cacheRedisUri: 'redis://localhost'
      firehoseRedisUri: 'redis://localhost'
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
