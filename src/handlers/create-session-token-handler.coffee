_    = require 'lodash'
http = require 'http'

class CreateSessionTokenHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (data={}, callback=->) =>
    {uuid,token} = data
    auth = _.cloneDeep @auth
    if uuid? and token?
      auth =
        uuid: uuid
        token: token
      delete data.token
    request =
      metadata:
        jobType: 'CreateSessionToken'
        auth: auth
        toUuid: data.uuid
        fromUuid: auth.uuid
      data: data

    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback error: error.message if error?
      return callback error: http.STATUS_CODES[response.metadata.code] unless response.metadata.code == 200
      return callback JSON.parse response.rawData

module.exports = CreateSessionTokenHandler
