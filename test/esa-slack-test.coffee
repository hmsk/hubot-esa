Helper = require 'hubot-test-helper'
chai = require 'chai'
fs = require 'fs'
nock = require 'nock'

expect = chai.expect

helper = new Helper '../src/esa-slack.coffee'

describe 'esa-slack', ->
  room = null
  response = null
  fetchingSlackChannelsOnLoad = null
  slackChannelsCacheKey = 'esaWebhookSlackChannels'

  initializingKeyword = 'esa mock response object'
  initializingMessage = '@hubot' + initializingKeyword

  lastSentAttachment = ()->
    room.messages[room.messages.length - 1][1].attachments[0]

  initializeRoom = ->
    room = helper.createRoom()
    # Build response object manually
    response = null
    room.robot.respond initializingKeyword, (res) -> response = res
    room.user.say 'gingy', initializingMessage

    room.robot.brain.set slackChannelsCacheKey,
      channels: ['dev'],
      savedAt: new Date().getTime()

  mockFetchingChannelList = ->
    nock('https://slack.com')
      .get("/api/channels.list")
      .query(token: process.env.HUBOT_SLACK_TOKEN, exclude_archived: '1')
      .once()
      .replyWithFile(200, "#{__dirname}/fixtures/channels.json")

  beforeEach ->
    process.env.HUBOT_ESA_ACCESS_TOKEN = 'dummy'
    process.env.HUBOT_ESA_TEAM = 'ginger'
    process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM = 'general'
    process.env.HUBOT_ESA_WEBHOOK_ENDPOINT = '/hubot/ginger'
    process.env.HUBOT_ESA_WEBHOOK_SECRET_TOKEN = 'purrs'
    process.env.HUBOT_ESA_JUST_EMIT = 'true'
    process.env.HUBOT_SLACK_TOKEN = 'xoxo-'

    nock.disableNetConnect()
    fetchingSlackChannelsOnLoad = mockFetchingChannelList()

  afterEach ->
    nock.cleanAll()

  context 'disabled by env value', ->
    beforeEach ->
      process.env.HUBOT_ESA_SLACK_DECORATOR = 'false'
      initializeRoom()

    afterEach ->
      room.destroy()

    it 'should not try to restore cache of slack channels', ->
      expect(fetchingSlackChannelsOnLoad.isDone()).to.be.false

    context 'emit esa.hear.stats event', ->
      beforeEach (done)->
        @stats = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/stats.json")
        room.robot.emit 'esa.hear.stats', response, @stats
        setTimeout done, 200

      it 'not send attachment event', ->
        expect(room.messages[room.messages.length - 1][1]).to.equal initializingMessage

  context 'enabled by env value', ->
    beforeEach ->
      process.env.HUBOT_ESA_SLACK_DECORATOR = 'true'
      initializeRoom()

    afterEach ->
      room.destroy()

    it 'should try to restore cache of slack channels', ->
      expect(fetchingSlackChannelsOnLoad.isDone()).to.be.true

    context 'emit esa.hear.stats event', ->
      beforeEach (done)->
        @stats = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/stats.json")
        room.robot.emit 'esa.hear.stats', response, @stats
        setTimeout done, 200

      it 'send attachment with base information', ->
        expect(lastSentAttachment().color).to.equal '#13958D'
        expect(lastSentAttachment().thumb_url).to.equal 'https://img.esa.io/uploads/production/pictures/105/6161/image/425c3b1e777d356c34973e818543420e.gif'

      it 'send attachment with stats', ->
        expect(lastSentAttachment().pretext).to.equal 'The stats of esa'
        expect(lastSentAttachment().fields).to.include {
          title: 'Daily Active Users'
          value: @stats.daily_active_users
          short: true
        }

    context 'emit esa.hear.post event', ->
      beforeEach (done)->
        @post = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/post.json")
        room.robot.emit 'esa.hear.post', response, @post
        setTimeout done, 200

      it 'send attachment with post', ->
        att = lastSentAttachment()
        expect(att.pretext).to.equal ''
        expect(att.title).to.equal @post.full_name
        expect(att.title_link).to.equal @post.url
        expect(att.text).to.equal @post.body_md

    context 'emit esa.hear.comment event', ->
      beforeEach (done)->
        @comment = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/comment.json")
        @post = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/post.json")
        room.robot.emit 'esa.hear.comment', response, @comment, @post
        setTimeout done, 200

      it 'send attachment with post', ->
        att = lastSentAttachment()
        expect(att.pretext).to.equal ''
        expect(att.title).to.equal ('Comment for ' + @post.full_name)
        expect(att.title_link).to.equal @comment.url
        expect(att.text).to.equal @comment.body_md
        expect(att.author_name).to.equal @comment.created_by.screen_name
        expect(att.author_icon).to.equal @comment.created_by.icon

    context 'emit esa.webhook event', ->
      buildWebhookArgs = (fixture) ->
        webhook = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/webhook_#{fixture}.json")
        data =
          team: webhook.team
          user: webhook.user
          post: webhook.post
          comment: webhook.comment || null
        return [webhook.kind, data]

      expectCommonFields = (att, actual) ->
        expect(att.author_name).to.equal actual.user.screen_name
        expect(att.author_icon).to.equal actual.user.icon.url
        expect(att.title).to.equal actual.post.name
        expect(att.title_link).to.equal actual.post.url

      it 'send attachment for post_create', ->
        [kind, data] = buildWebhookArgs('post_create')
        room.robot.emit 'esa.webhook', kind, data
        att = lastSentAttachment()
        expectCommonFields(att, data)
        expect(att.pretext).to.equal 'New post created'
        expect(att.text).to.equal data.post.message

      it 'send attachment for post_update', ->
        [kind, data] = buildWebhookArgs('post_update')
        room.robot.emit 'esa.webhook', kind, data
        att = lastSentAttachment()
        expectCommonFields(att, data)
        expect(att.pretext).to.equal 'The post updated'
        expect(att.text).to.equal data.post.message

      it 'send attachment for post_archive', ->
        [kind, data] = buildWebhookArgs('post_archive')
        room.robot.emit 'esa.webhook', kind, data
        att = lastSentAttachment()
        expectCommonFields(att, data)
        expect(att.pretext).to.equal 'The post archived'
        expect(att.text).to.be.undefined

      it 'send attachment for comment_create', ->
        [kind, data] = buildWebhookArgs('comment_create')
        room.robot.emit 'esa.webhook', kind, data
        att = lastSentAttachment()
        expectCommonFields(att, data)
        expect(att.pretext).to.equal 'The comment posted'
        expect(att.text).to.equal data.comment.body_md

      it 'send attachment for member_join', ->
        [kind, data] = buildWebhookArgs('member_join')
        room.robot.emit 'esa.webhook', kind, data
        att = lastSentAttachment()
        expect(att.pretext).to.equal 'New member joined'
        expect(att.text).to.equal data.user.screen_name

      describe 'emit messaging event with', ->
        selectedChannels = null
        beforeEach ->
          room.robot.on 'esa.slack.attachment', (content, channels) ->
            selectedChannels = channels

        context 'enabled selector', ->
          beforeEach ->
            process.env.HUBOT_ESA_SLACK_ROOM_SELECTOR = 'true'

          # title[] -> notify to [default]
          it 'default channel for the post without any tag asynchronously', ->
            [kind, data] = buildWebhookArgs('post_update')
            room.robot.emit 'esa.webhook', kind, data
            expect(selectedChannels).to.have.members [process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM]

          # title[#api, #dev, #fun] && available+is_member[#dev] -> notify to [#dev]
          it 'channels which are appeared as tags on title asynchronously', ->
            [kind, data] = buildWebhookArgs('post_update_with_tags')
            room.robot.emit 'esa.webhook', kind, data
            expect(selectedChannels).to.have.members ['dev']

          # title: /dev/some-title && available[#dev] -> notify to [#dev]
          it 'channels which are appeared as dirname on title asynchronously', ->
            [kind, data] = buildWebhookArgs('post_update_with_dirname')
            room.robot.emit 'esa.webhook', kind, data
            expect(selectedChannels).to.have.members ['dev']

          it 'should not restore cache of channel list if that is not stale', (done) ->
            refetchingCacheForStale = mockFetchingChannelList()

            [kind, data] = buildWebhookArgs('post_update')
            room.robot.emit 'esa.webhook', kind, data

            brain = room.robot.brain
            cache = brain.get slackChannelsCacheKey
            lastSavedTime = cache.savedAt

            setTimeout ->
              expect(refetchingCacheForStale.isDone()).to.be.false
              cache = brain.get slackChannelsCacheKey
              expect(cache.savedAt).to.eql lastSavedTime
              done()
            , 200

          it 'should restore cache of channel list if that is stale', (done) ->
            refetchingCacheForStale = mockFetchingChannelList()

            [kind, data] = buildWebhookArgs('post_update')
            room.robot.emit 'esa.webhook', kind, data

            brain = room.robot.brain
            cache = brain.get slackChannelsCacheKey
            oldTime = new Date().getTime() - 3600 * 1000 * 24 * 2
            cache.savedAt = oldTime
            brain.set slackChannelsCacheKey, cache

            [kind, data] = buildWebhookArgs('post_update')
            room.robot.emit 'esa.webhook', kind, data

            setTimeout ->
              expect(refetchingCacheForStale.isDone()).to.be.true
              cache = brain.get slackChannelsCacheKey
              expect(cache.savedAt).not.to.eql oldTime
              done()
            , 200

        context 'disabled selector', ->
          beforeEach ->
            process.env.HUBOT_ESA_SLACK_ROOM_SELECTOR = ''

          it 'notify to default channel', ->
            [kind, data] = buildWebhookArgs('post_update_with_tags')
            room.robot.emit 'esa.webhook', kind, data
            expect(selectedChannels).to.have.members [process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM]
