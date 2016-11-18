_ = require 'lodash'
http = require 'http'

class ClaimDeviceHandler
  constructor: ({@jobManager,@auth}) ->

  do: (data, callback=->) =>
    unless _.isPlainObject data
      return callback new Error('invalid update')

    {uuid} = data
    data = _.omit data, ['uuid', 'token']

    request =
      metadata:
        jobType: 'UpdateDevice'
        toUuid: uuid
        auth: @auth
      data:
        $set:
          owner: @auth.uuid
        $addToSet:
          discoverWhitelist: @auth.uuid
          configureWhitelist: @auth.uuid

    @jobManager.do request, (error, response) =>
      return callback error: error.message if error?
      callback uuid: uuid, status: 200

module.exports = ClaimDeviceHandler
