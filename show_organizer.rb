#!/usr/bin/ruby -w

require 'rubygems'
require 'english/style'
require 'pathname'
require 'pp'

Paths = {
  :library   => Pathname.new("/home/ohad/torrents/library"),
  :inbox     => Pathname.new("/home/ohad/torrents"),
  :unwatched => Pathname.new("/home/ohad/torrents/unwatched"),
}

VideoExtensions = [ ".avi", ".mpg", ".xvid", ".mkv" ]

class ShowPathname < Pathname
  def initialize path
    if path.is_a? Pathname
      super path.to_s
    else
      super path
    end
    @show_name = nil
  end

  def episode; figure_proper_name; @episode; end
  def season; figure_proper_name; @season; end
  def show_name; figure_proper_name; @show_name; end

  def formatted_filename
    figure_proper_name
    sprintf "%s S%02dE%02d%s", @show_name, @season, @episode, self.extname
  end

  private

  SeasonEpisodeRegex = [ /S(\d+)\.?E(\d+)/i, /(\d+)x(\d+)/ ]

  def figure_proper_name
    return unless @show_name.nil?

    basic_filename = self.basename(self.extname).to_s

    SeasonEpisodeRegex.each do |regex|
      match_obj = regex.match(basic_filename)
      if match_obj
        @season = match_obj[1].to_i
        @episode = match_obj[2].to_i
        @show_name = match_obj.pre_match
        clean_show_name
        return
      end
    end

    # Guess a unified season/episode number (304 => S03E04)
    match_obj = /\d{3,4}/.match(basic_filename)
    if match_obj
      unified_episode = match_obj[0].to_i
      @season = unified_episode / 100
      @episode = unified_episode % 100
      @show_name = match_obj.pre_match
      clean_show_name
      return
    end

    raise Exception.new("Could not figure out filename #{self.basename}")
  end

  def clean_show_name
    @show_name = @show_name.gsub(/[\.\-_]/," ").gsub(/[\s+]/," ").strip.\
      titlecase
  end

end

def organize_library
  duplicate_test_hash = {}

  Paths[:library].find do |p|
    if p.file? and VideoExtensions.include?(p.extname.downcase)
      sp = ShowPathname.new(p)

      if sp.basename.to_s != sp.formatted_filename
        dest = Paths[:library] + sp.show_name + sp.formatted_filename

        if dest.exist?
          raise Exception.new("Duplicate: #{sp} would overwrite #{dest}")
        end

        puts "#{sp} -> #{dest}"
        sp.rename(dest)
      else
        dest = sp
      end

      episode_identifier = [sp.show_name, sp.season, sp.episode]

      duplicate_test_hash[episode_identifier] ||= []
      duplicate_test_hash[episode_identifier] << dest
    end
  end

  duplicate_test_hash.each do |k, v|
    if v.length > 1
      puts "These look like duplicates to me:"
      pp v
    end
  end
end

organize_library
