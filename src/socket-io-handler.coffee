_                                     = require 'lodash'
async                                 = require 'async'
http                                  = require 'http'
meshblu                               = require 'meshblu'
AuthenticateHandler                   = require './handlers/authenticate-handler'
ClaimDeviceHandler                    = require './handlers/claimdevice-handler'
GetDeviceHandler                      = require './handlers/get-device-handler'
GetDevicePublicKeyHandler             = require './handlers/get-device-public-key-handler'
ResetTokenHandler                     = require './handlers/reset-token-handler'
DevicesHandler                        = require './handlers/devices-handler'
IdentityAuthenticateHandler           = require './handlers/identity-authenticate-handler'
GetAuthorizedSubscriptionTypesHandler = require './handlers/get-authorized-subscription-types-handler'
MyDevicesHandler                      = require './handlers/mydevices-handler'
RegisterDeviceHandler                 = require './handlers/register-device-handler'
RevokeTokenByQuery                    = require './handlers/revoke-token-by-query-handler'
SendMessageHandler                    = require './handlers/send-message-handler'
StatusHandler                         = require './handlers/status-handler'
UnregisterDeviceHandler               = require './handlers/unregister-device-handler'
UpdateAsHandler                       = require './handlers/update-as-handler'
UpdateHandler                         = require './handlers/update-handler'
WhoamiHandler                         = require './handlers/whoami-handler'

class SocketIOHandler
  constructor: ({@socket,@jobManager,@meshbluConfig,@messengerFactory}) ->

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
    @messenger = @messengerFactory.build()

    @messenger.on 'message', (channel, message) =>
      @socket.emit 'message', message

    @messenger.on 'config', (channel, message) =>
      @socket.emit 'config', message

    @messenger.on 'data', (channel, message) =>
      @socket.emit 'data', message

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

  onSubscribe: (data) =>
    data.types ?= ['broadcast', 'received', 'sent']
    data.types.push 'data'
    data.types.push 'config'
    requestQueue = 'request'
    responseQueue = 'response'
    auth = _.cloneDeep @auth
    if data.token?
      auth =
        uuid: data.uuid
        token: data.token
      delete data.token

    handler = new GetAuthorizedSubscriptionTypesHandler {@jobManager, auth, requestQueue, responseQueue}
    handler.do data, (response) =>
      async.each response.types, (type, next) =>
        @messenger.subscribe {type, uuid: data.uuid}, next

  onUnsubscribe: (data) =>
    data.types ?= ['broadcast', 'received', 'sent']
    requestQueue = 'request'
    responseQueue = 'response'
    auth = _.cloneDeep @auth
    if data.token?
      auth =
        uuid: data.uuid
        token: data.token
      delete data.token

    handler = new GetAuthorizedSubscriptionTypesHandler {@jobManager, auth, requestQueue, responseQueue}
    handler.do data, (response) =>
      async.each response.types, (type, next) =>
        @messenger.unsubscribe {type, uuid: data.uuid}, next

  onUpstreamConnectError: (message) =>
    @socket.emit 'connect_error', message

  onUpstreamReady: (response) =>
    @auth.uuid  = response.uuid
    @auth.token = response.token

    async.each ['received', 'config', 'data'], (type, next) =>
      @messenger.subscribe {type, uuid: @auth.uuid}, next

    @socket.emit 'ready', response

  setupUpstream: (response) =>
    @auth.uuid  = response.uuid
    @auth.token = response.token

    @socket.on 'authenticate', @handlerHandler AuthenticateHandler
    @socket.on 'claimdevice', @handlerHandler ClaimDeviceHandler
    @socket.on 'device', @handlerHandler GetDeviceHandler
    @socket.on 'devices', @handlerHandler DevicesHandler
    @socket.on 'getPublicKey', @handlerHandler GetDevicePublicKeyHandler
    @socket.on 'message', @handlerHandler SendMessageHandler
    @socket.on 'mydevices', @handlerHandler MyDevicesHandler
    @socket.on 'register', @handlerHandler RegisterDeviceHandler
    @socket.on 'resetToken', @handlerHandler ResetTokenHandler
    @socket.on 'revokeTokenByQuery', @handlerHandler RevokeTokenByQuery
    @socket.on 'status', @handlerHandler StatusHandler
    @socket.on 'subscribe', @onSubscribe
    @socket.on 'unregister', @handlerHandler UnregisterDeviceHandler
    @socket.on 'unsubscribe', @onUnsubscribe
    @socket.on 'update', @handlerHandler UpdateHandler
    @socket.on 'updateas', @handlerHandler UpdateAsHandler
    @socket.on 'whoami', @handlerHandler WhoamiHandler

    @socket.on 'generateAndStoreToken', @upstream.generateAndStoreToken
    @socket.on 'getdata', @upstream.getdata
    @socket.on 'revokeToken', @upstream.revokeToken

  _emitNotReady: (code, auth) =>
    @socket.emit 'notReady',
      uuid:  auth.uuid
      token: auth.token
      api: 'connect'
      status: code

module.exports = SocketIOHandler
