# -*- coding: utf-8 -*-

module Yukinyamap
  class Malkov
    MARKER_BEGIN = '__BEGIN__'
    MARKER_END   = '__END__'
    ALPHA        = /^[\w ]+$/
    NUMBER       = /^[\d ]+$/
    HIRAGANA     = /^[ぁ-ゞ]+$/
    BRANCKETS    = /[「」『』]/
    SIGN         = /^([,.?!、。？！‸…ー〜]|#{BRANCKETS})+$/

    attr_reader :table

    def initialize(texts = nil)
      @table = texts ? Table.new(texts) : Table.from_db
    end

    def rotate(text)
      @table.rotate(text)

      self
    end

    def generate
      send [:generate_random, :generate_popular].sample
    end

    def generate_random
      generate_from_first_node(@table.first_node)
    end

    def generate_popular
      generate_from_word(popular_word)
    end

    def generate_from_word(word)
      node = @table.find_node(word)
      generate_from_last_node(node) + generate_from_first_node(node)
    end

    def generate_from_first_node(node)
      text = node.join
      loop do
        node = @table.next_node(node)
        break unless node
        break if clean(text + node[2]).size > 140
        text += node[2]
        break if node[2] == MARKER_END
      end

      clean(text)
    end

    def generate_from_last_node(node)
      text = ''
      loop do
        node = @table.prev_node(node)
        break unless node
        break if node[0] == MARKER_BEGIN
        break if clean(node[0] + text).size > 140
        text = node[0] + text
      end

      clean(text)
    end

    def popular_word(nodes = nil)
      ranking = YM.config[:malkov][:popular][:ranking]
      popular_words(nodes).first(ranking).map(&:first).sample
    end

    def popular_words(nodes = nil)
      recent = YM.config[:malkov][:popular][:recent]
      nodes = nodes ? nodes : YM.malkov.table.nodes.last(recent).flatten
      nodes.reduce(Hash.new(0)) { |r, n|
        if n != MARKER_BEGIN &&
            n != MARKER_END &&
            !n.match(NUMBER) &&
            !n.match(HIRAGANA) &&
            !n.match(SIGN) &&
            r[n] += 1
        end
        r
      }.select { |r, n| n > 1 } .sort_by { |r, n| -n }
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

      def initialize(texts = [])
        @nodes = texts.map {|n| normalize(n)}
      end

      def flat_nodes
        nodes.flatten(1)
      end

      def rotate(text)
        return self unless text

        nodes.pop
        nodes.unshift normalize(text)

        self
      end

      def first_nodes
        flat_nodes.select { |n| n[0] == MARKER_BEGIN }
      end

      def prev_nodes(node)
        flat_nodes.select { |n| n[1] == node[0] && n[2] == node[1] }
      end

      def next_nodes(node)
        flat_nodes.select { |n| n[0] == node[1] && n[1] == node[2] }
      end

      def find_nodes(word)
        flat_nodes.select { |n| n.include?(word) }
      end

      def first_node
        first_nodes.sample
      end

      def prev_node(node)
        prev_nodes(node).sample
      end

      def next_node(node)
        next_nodes(node).sample
      end

      def find_node(word)
        find_nodes(word).sample
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

      PATTERNS = [
        RT_PATTERN,
        USER_PATTERN,
        HASHTAG_PATTERN,
        URL_PATTERN
      ].freeze

      CHARACTER_REFERENCES = [
        {from: '&amp;', to: '&'},
        {from: '&lt;',  to: '<'},
        {from: '&gt;',  to: '>'},
      ].freeze

      def self.clean(text)
        PATTERNS.each do |p|
          text = text.gsub(p, '')
        end

        CHARACTER_REFERENCES.each do |r|
          text = text.gsub(r[:from], r[:to])
        end

        text
      end
    end
  end
end
