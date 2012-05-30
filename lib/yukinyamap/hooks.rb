# -*- coding: utf-8 -*-

module Yukinyamap
  class MongoHook
    def call(status)
      if status.text
        status.keywords = YM.tagger.parse(status.text).split(' ')
      end
      YM.collection(YM.col_key_from_status(status)).insert(status)
    end
  end

  class LogHook
    def call(status)
      YM.say status
    end
  end

  class StoreHook
    def call(status)
      YM.malkov.rotate(status.text)
    end
  end

  class TweetHook
    def initialize
      @tweet_count = 0
      @update_time = Time.now

      @count = YM.config[:tweet][:count]
      @min   = YM.config[:tweet][:min]
      @max   = YM.config[:tweet][:max]
    end

    def call(status)
      return if status.in_reply_to_screen_name == YM.screen_name
      return if status.user!.screen_name == YM.screen_name

      @tweet_count += 1
      diff = Time.now.to_i - @update_time.to_i
      if diff > @max.minutes ||
          (@tweet_count > @count && diff > @min.minutes)
        @tweet_count = 0
        @update_time = Time.now
        YM.twitter.update(YM.malkov.generate)
      end
    end
  end

  class ReplyHook
    def call(status)
      return if status.in_reply_to_screen_name != YM.screen_name

      options = {:in_reply_to_status_id => status.id}
      tweet = "@#{status.user.screen_name} #{YM.malkov.generate}"
      YM.twitter.update(tweet, options)
    end
  end

  class FollowHook
    def call(status)
      return unless status.event == 'follow'
      return if status.source.screen_name == YM.screen_name

      YM.twitter.follow(status.source.screen_name)
      tweet = "@#{status.source.screen_name} #{YM.malkov.generate}"
      YM.twitter.update(tweet)
    end
  end
end
