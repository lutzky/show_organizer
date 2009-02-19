#!/usr/bin/ruby -w

require 'rubygems'
require 'english/style'
require 'pathname'

VideoExtensions = [ ".avi", ".mpg", ".xvid" ]

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

Pathname.new(".").find do |p|
  if p.file? and VideoExtensions.include?(p.extname.downcase)
    show_path = ShowPathname.new(p)
    puts "#{p.basename.to_s} => " + show_path.formatted_filename
  end
end
