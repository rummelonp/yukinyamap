# -*- coding: utf-8 -*-

module Yukinyamap
  class Malkov
    MARKER_BEGIN = '__BEGIN__'
    MARKER_END   = '__END__'
    ALPHA        = /^[\w ]+$/
    NUMBER       = /^[\d ]+$/
    HIRAGANA     = /^[ぁ-ゞ]+$/
    BRANCKETS    = /[「」『』（）\(\)]/
    SIGN         = /^([,.?!、。？！‸…ー〜]|#{BRANCKETS})+$/

    attr_reader :table

    def initialize
      @table = Table.from_db
    end

    def rotate(node)
      @table.rotate(node)

      self
    end

    def generate
      send [:random_generate, :popular_generate].sample
    end

    def random_generate(start_node = @table.first)
      node = start_node
      text = node[1] + node[2]
      loop do
        node = @table.next_node(node)
        break unless node
        break if node[2] == MARKER_END
        break if clean(text + node[2]).size > 140
        text += node[2]
      end

      clean(text)
    end

    def popular_generate
      word = popular_words.map(&:first).first(6).sample

      node = @table.find_node(word)
      text = node[0] + random_generate(node)
      loop do
        node = @table.prev_node(node)
        break unless node
        break if node[0] == MARKER_BEGIN
        break if clean(text + node[0]).size > 140
        text = node[0] + text
      end

      clean(text)
    end

    def popular_words
      YM.malkov.table.nodes.last(32).flatten.reduce(Hash.new(0)) { |r, n|
        if n != MARKER_BEGIN &&
            n != MARKER_END &&
            !n.match(NUMBER) &&
            !n.match(HIRAGANA) &&
            !n.match(SIGN) &&
          r[n] += 1
        end
        r
      }.sort_by { |r, n| -n }
    end

    private
    def clean(text)
      text.
        gsub(MARKER_BEGIN, '').
        gsub(MARKER_END, '').
        gsub(BRANCKETS, '').
        gsub(/ +/, ' ').
        strip
    end

    class Table
      DB_SELECTOR = {
        'text' => {'$exists' => true},
        'user.protected' => false,
        'user.screen_name' => {'$ne' => YM.screen_name}
      }.freeze
      DB_OPTIONS = {
        :limit => 3200,
        :sort => ['_id', :desc]
      }.freeze

      attr_reader :nodes

      def self.from_db
        new YM.collection('status').
          find(DB_SELECTOR, DB_OPTIONS).
          to_a.map {|s| s['text']}
      end

      def initialize(nodes = [])
        @nodes = nodes.map {|n| normalize(n)}
      end

      def rotate(node)
        return self unless node

        @nodes.pop
        @nodes.unshift normalize(node)

        self
      end

      def first
        @nodes.flatten(1).select { |n| n[0] == MARKER_BEGIN }.sample
      end

      def prev_node(node)
        @nodes.flatten(1).select { |n|
          n[1] == node[0] && n[2] == node[1]
        }.sample
      end

      def next_node(node)
        @nodes.flatten(1).select { |n|
          n[0] == node[1] && n[1] == node[2]
        }.sample
      end

      def find_node(word)
        @nodes.flatten(1).select { |n| n.include?(word) }.sample
      end

      private
      def normalize(node)
        if node.is_a?(String)
          node = Cleaner.clean(node)
          node = YM.tagger.parse(node).split(' ')
        end
        node = node.map do |n|
          if n.match(ALPHA) || n.match(NUMBER)
            n = ' ' + n + ' '
          end
          n
        end
        unless node.first == MARKER_BEGIN
          node.unshift MARKER_BEGIN
        end
        unless node.last == MARKER_END
          node.push MARKER_END
        end
        node.each_cons(3).to_a
      end
    end

    module Cleaner
      USER_PATTERN    = /@[\w_]+/
      RT_PATTERN      = /(RT|QT):? #{USER_PATTERN}.*(\n|$)/
      HASHTAG_PATTERN = /#[\wＡ-Ｚａ-ｚ０-９ぁ-ヶ亜-黑]+/
      URL_PATTERN     = URI.regexp

      def self.clean(text)
        text.gsub(RT_PATTERN, '').
          gsub(USER_PATTERN, '').
          gsub(HASHTAG_PATTERN, '').
          gsub(URL_PATTERN, '')
      end
    end
  end
end
