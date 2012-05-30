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
end
