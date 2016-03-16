_                           = require 'lodash'
http                        = require 'http'
meshblu                     = require 'meshblu'
AuthenticateHandler         = require './handlers/authenticate-handler'
IdentityAuthenticateHandler = require './handlers/identity-authenticate-handler'
RevokeTokenByQuery          = require './handlers/revoke-token-by-query-handler'
UpdateAsHandler             = require './handlers/update-as-handler'
UpdateHandler               = require './handlers/update-handler'
RegisterDeviceHandler       = require './handlers/register-device-handler'
SendMessageHandler          = require './handlers/send-message-handler'
StatusHandler               = require './handlers/status-handler'
WhoamiHandler               = require './handlers/whoami-handler'

class SocketIOHandler
  constructor: ({@socket,@jobManager,@meshbluConfig}) ->

  handlerHandler: (handlerClass) =>
    (data, callback) =>
      requestQueue = 'request'
      responseQueue = 'response'
      handler = new handlerClass {@jobManager, @auth, requestQueue, responseQueue}
      handler.do data, callback

  initialize: =>
    @socket.on 'identity', @onIdentity
    @socket.on 'disconnect', @onDisconnect
    @socket.emit 'identify'

  onDisconnect: =>
    @upstream?.close()

  onIdentity: (auth) =>
    @auth = _.pick auth, 'uuid', 'token', 'auto_set_online'
    authenticate = @handlerHandler IdentityAuthenticateHandler
    authenticate @auth, (error, response) =>
      return @_emitNotReady 504, @auth if error?
      return @_emitNotReady 401, @auth unless response.metadata.code == 204

      auto_set_online = @auth.auto_set_online ? @meshbluConfig.auto_set_online
      @upstream = meshblu.createConnection
        auto_set_online: auto_set_online
        bufferRate: 0
        skip_resubscribe_on_reconnect: true
        server: @meshbluConfig.server
        port: @meshbluConfig.port
        uuid: @auth.uuid
        token: @auth.token
        options: transports: ['websocket']

      @upstream = _.bindAll @upstream, _.functionsIn(@upstream)

      @upstream.once 'ready', @setupUpstream
      @upstream.on 'ready', @onUpstreamReady
      @upstream.on 'notReady', (response) =>
        @socket.emit 'notReady', response
      @upstream.on 'connect_error', @onUpstreamConnectError
      @upstream.on 'config', @onUpstreamConfig
      @upstream.socket.on 'data', @onUpstreamData # data is not proxied by meshblu-npm
      @upstream.on 'message', @onUpstreamMessage

  onUpstreamConfig: (message) =>
    @socket.emit 'config', message

  onUpstreamConnectError: (message) =>
    @socket.emit 'connect_error', message

  onUpstreamData: (message) =>
    @socket.emit 'data', message

  onUpstreamMessage: (message) =>
    @socket.emit 'message', message

  onUpstreamReady: (response) =>
    @auth.uuid  = response.uuid
    @auth.token = response.token

    @socket.emit 'ready', response

  setupUpstream: (response) =>
    @auth.uuid  = response.uuid
    @auth.token = response.token

    @socket.on 'authenticate', @handlerHandler AuthenticateHandler
    @socket.on 'message', @handlerHandler SendMessageHandler
    @socket.on 'revokeTokenByQuery', @handlerHandler RevokeTokenByQuery
    @socket.on 'update', @handlerHandler UpdateHandler
    @socket.on 'updateas', @handlerHandler UpdateAsHandler
    @socket.on 'whoami', @handlerHandler WhoamiHandler
    @socket.on 'status', @handlerHandler StatusHandler
    @socket.on 'register', @handlerHandler RegisterDeviceHandler

    @socket.on 'claimdevice', @upstream.claimdevice
    @socket.on 'data', @upstream.data
    @socket.on 'device', @upstream.device
    @socket.on 'devices', @upstream.devices
    @socket.on 'events', @upstream.events
    @socket.on 'generateAndStoreToken', @upstream.generateAndStoreToken
    @socket.on 'getdata', @upstream.getdata
    @socket.on 'getPublicKey', @upstream.getPublicKey
    @socket.on 'localdevices', @upstream.localdevices
    @socket.on 'mydevices', @upstream.mydevices
    @socket.on 'resetToken', @upstream.resetToken
    @socket.on 'revokeToken', @upstream.revokeToken
    @socket.on 'subscribe', @upstream.subscribe
    @socket.on 'unclaimeddevices', @upstream.unclaimeddevices
    @socket.on 'unregister', @upstream.unregister
    @socket.on 'unsubscribe', @upstream.unsubscribe
    @socket.on 'update', @upstream.update

  _emitNotReady: (code, auth) =>
    @socket.emit 'notReady',
      uuid:  auth.uuid
      token: auth.token
      api: 'connect'
      status: code

module.exports = SocketIOHandler
