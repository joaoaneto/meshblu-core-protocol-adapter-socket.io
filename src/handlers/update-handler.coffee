_ = require 'lodash'
http = require 'http'

class UpdateHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (data, callback=->) =>
    unless _.isPlainObject data
      return callback new Error('invalid update')

    auth = _.cloneDeep @auth
    {uuid,token} = data
    data = _.omit data, ['uuid', 'token']

    request =
      metadata:
        jobType: 'UpdateDevice'
        toUuid: uuid
        auth: auth
      data: $set: data

    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback error: error.message if error?
      callback uuid: uuid, status: 200

module.exports = UpdateHandler
