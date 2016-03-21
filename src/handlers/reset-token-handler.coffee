_    = require 'lodash'
http = require 'http'

class ResetTokenHandler
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
        jobType: 'ResetToken'
        auth: auth
        toUuid: data.uuid
        fromUuid: auth.uuid

    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback error: error.message if error?
      return callback error: http.STATUS_CODES[response.metadata.code] unless response.metadata.code == 200
      device = JSON.parse response.rawData
      return callback {device}

module.exports = ResetTokenHandler
