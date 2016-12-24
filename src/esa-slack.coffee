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

class ChannelSelector
  slackChannelsCacheKey = 'esaWebhookSlackChannels'

  constructor: (@robot) ->
    @kvs = @robot.brain

  @fetchSlackChannels: (robot, slack_token) ->
    kvs = robot.brain
    robot.http('https://slack.com/api/channels.list')
      .query({token: slack_token, exclude_archived: '1'})
      .header('Accept', 'application/json')
      .get() (error, response, body) ->
        if response.statusCode is 200
          availableChannels = []
          for availableChannel in JSON.parse(body).channels
            if availableChannel.is_member
              availableChannels.push availableChannel.name

          cache =
            channels: availableChannels
            savedAt: new Date().getTime()

          kvs.set slackChannelsCacheKey, cache

  @refetchSlackChannelCacheIfNeeded: (robot, slack_token) ->
    cache = robot.brain.get(slackChannelsCacheKey) or {}
    if 'savedAt' of cache and (cache.savedAt  < new Date().getTime() - 3600 * 1000 * 24)
      ChannelSelector.fetchSlackChannels(robot, slack_token)

  _getCachedAvailableChannels = ->
    cache = @kvs.get(slackChannelsCacheKey) or {}
    unless 'channels' of cache
      cache =
        channels: []
        savedAt: null
    cache.channels

  selectByTitle: (entry_title, default_channels) ->
    selectedChannels = []
    availableChannels = _getCachedAvailableChannels.call @

    tagsPattern = /#(\w+)/g
    while (matches = tagsPattern.exec(entry_title))
      selectedChannels.push matches[1]

    selectedChannels = selectedChannels.filter (channel) ->
      availableChannels.indexOf(channel) > -1

    if selectedChannels.length == 0
      dirsPattern = /\/{0,1}(\w+)\//g
      while (matches = dirsPattern.exec(entry_title))
        selectedChannels = [matches[1]] if availableChannels.indexOf(matches[1]) > -1

    selectedChannels = default_channels if selectedChannels.length == 0
    selectedChannels

module.exports = (robot) ->
  options =
    enabled: process.env.HUBOT_ESA_SLACK_DECORATOR == 'true'
    default_room: process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM
    slack_token: process.env.HUBOT_SLACK_TOKEN

  if options.enabled
    robot.emit 'esa.debug', 'Slack decorator enabled'

    if options.slack_token
      ChannelSelector.fetchSlackChannels(robot, options.slack_token)

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

    channelsByWebhookContent = (content) ->
      defaultChannels = [options.default_room]
      if content.title and process.env.HUBOT_ESA_SLACK_ROOM_SELECTOR == 'true'
        selector = new ChannelSelector(robot)
        return selector.selectByTitle(content.title, defaultChannels)
      else
        return defaultChannels

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

      robot.emit 'esa.slack.attachment', content, channelsByWebhookContent(content)
      if options.slack_token
        ChannelSelector.refetchSlackChannelCacheIfNeeded(robot, options.slack_token)

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
