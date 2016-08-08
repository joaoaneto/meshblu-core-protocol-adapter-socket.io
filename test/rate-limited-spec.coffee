async   = require 'async'
_       = require 'lodash'
Connect = require './connect'
redis = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'
RateLimitChecker = require 'meshblu-core-rate-limit-checker'

describe 'when rate limited', ->
  beforeEach (done) ->
    client = new RedisNS 'ns', redis.createClient(dropBufferSupport: true)
    client.del 'request:queue', done

  beforeEach (done) ->
    @client = new RedisNS 'meshblu-count', redis.createClient(dropBufferSupport: true)
    @client.once 'ready', done

  beforeEach (done) ->
    @connect = new Connect
    @connect.connect (error, things) =>
      return done error if error?
      {@sut,@connection,@device,@jobManager} = things
      rateLimitChecker = new RateLimitChecker {@client}
      @client.hset rateLimitChecker.getMinuteKey(), 'masseuse', rateLimitChecker.msgRateLimit, done

  afterEach (done) ->
    rateLimitChecker = new RateLimitChecker {@client}
    @client.del rateLimitChecker.getMinuteKey(), done

  afterEach (done) ->
    @connect.shutItDown done

  describe 'when called', ->
    beforeEach (done) ->
      @connection.socket.emit 'whoami', {}, @onResponse = sinon.spy()
      @connection.socket.on 'ratelimited', (@message) =>
        done()

    it 'should fail', ->
      expect(@message.code).to.equal 429
