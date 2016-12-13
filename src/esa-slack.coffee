# Descriptipn
#   Hubot script decorated message from webhook of https://esa.io
#
# Dependencies:
#   hubot-esa
#   hubot-slack
#
# Commands:
#   None
#
# Configuration:
#   HUBOT_ESA_SLACK_DECORATOR
#
# Author:
#   hmsk <k.hamasaki@gmail.com>
#

module.exports = (robot) ->
  options =
    enabled: process.env.HUBOT_ESA_SLACK_DECORATOR == 'true'
    default_room: process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM
    slack_token: process.env.HUBOT_SLACK_TOKEN

  if options.enabled
    robot.emit 'esa.debug', 'Slack decorator enabled'
    # https://api.slack.com/docs/attachments
    buildContent = (message) ->
      content =
        color: '#13958D' # Theme color from esa icon
        fields: []
        pretext: message
        fallback: ''
        thumb_url: 'https://img.esa.io/uploads/production/pictures/105/6161/image/425c3b1e777d356c34973e818543420e.gif'

    robot.on 'esa.slack.attachment', (content, channels) ->
      robot.emit 'esa.debug', "emit slack.attachment with\n#{content}"
      for channel in channels
        robot.messageRoom channel, attachments: [content]

    channelsByPost = (content, callback) ->
      defaultChannels = [options.default_room]

      if content.title and process.env.HUBOT_ESA_SLACK_ROOM_SELECTOR == 'true'
        channels = []
        robot.http('https://slack.com/api/channels.list')
          .query({token: options.slack_token, exclude_archived: '1'})
          .header('Accept', 'application/json')
          .get() (error, response, body) ->
            if response.statusCode is 200
              availableChannels = []
              for availableChannel in JSON.parse(body).channels
                if availableChannel.is_member
                  availableChannels.push availableChannel.name

              tagsPattern = /#(\w+)/g
              while (matches = tagsPattern.exec(content.title))
                channels.push matches[1]

              channels = channels.filter (channel) ->
                availableChannels.indexOf(channel) > -1

              if channels.length == 0
                dirsPattern = /\/{0,1}(\w+)\//g
                while (matches = dirsPattern.exec(content.title))
                  channels = [matches[1]] if availableChannels.indexOf(matches[1]) > -1

              channels = defaultChannels if channels.length == 0
              callback(channels)
      else
        callback(defaultChannels)

    robot.on 'esa.webhook', (kind, data) ->
      putUserAndPostToContent = (content, user, post) ->
        content.author_name = user.screen_name
        content.author_icon = user.icon.url
        content.title = post.name
        content.title_link = post.url

      message_by_kind =
        'post_create': 'New post created'
        'post_update': 'The post updated'
        'post_archive': 'The post archived'
        'comment_create': 'The comment posted'
        'member_join': 'New member joined'

      content = buildContent message_by_kind[kind]
      putUserAndPostToContent content, data.user, data.post unless kind is 'member_join'

      switch kind
        when 'post_create', 'post_update'
          content.text = data.post.message
        when 'comment_create'
          content.text = data.comment.body_md
        when 'member_join'
          content.text = data.user.screen_name

      channelsByPost content, (channels) ->
        robot.emit 'esa.slack.attachment', content, channels

    robot.on 'esa.hear.stats', (res, stats) ->
      content = buildContent 'The stats of esa'
      fields = [
        { title: 'Posts', value: stats.posts }
        { title: 'Comments', value: stats.comments }
        { title: 'Stars', value: stats.stars }
        { title: 'Daily Active Users', value: stats.daily_active_users }
        { title: 'Weekly Active Users', value: stats.weekly_active_users }
        { title: 'Monthly Active Users', value: stats.monthly_active_users }
      ]
      content.fields = fields.map (item, i) ->
        item.short = true
        item

      robot.emit 'esa.slack.attachment', content, [res.envelope.room]

    robot.on 'esa.hear.post', (res, post) ->
      content = buildContent ''
      content.title = post.full_name
      content.title_link = post.url
      content.text = post.body_md
      robot.emit 'esa.slack.attachment', content, [res.envelope.room]

    robot.on 'esa.hear.comment', (res, comment, post) ->
      content = buildContent ''
      content.title = 'Comment for ' + post.full_name
      content.title_link = comment.url
      content.text = comment.body_md
      content.author_name = comment.created_by.screen_name
      content.author_icon = comment.created_by.icon
      robot.emit 'esa.slack.attachment', content, [res.envelope.room]
