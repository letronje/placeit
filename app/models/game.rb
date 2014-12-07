module Game
  extend self

  CLUES = [
    :flag,
    :capital,
    :currency,
    :languages,
    :peak,
    :anthem,
    :heads_of_state
  ]

  MIN_CLUES = 5
  
  def create(players)
    locations = Rails.configuration.locations

    location_name, clues = pick_location_with_clues(locations)

    game_key = ["game", *players.sort].join("_")
    game = Redis::HashKey.new(game_key, :marshal => true)
    game_info = {
      'players' => players,
      'location' => location_name,
      'clues' => clues
    }
    
    game.bulk_set(game_info)
    
    game_info.merge(:key => game_key)
  end

  def pick_location_with_clues(locations)
    chosen_location = nil
    location_clues = nil
    
    locations.keys.shuffle.each do |location_name|
      clues = clues_for_location(location_name)
      if clues.size < MIN_CLUES
        Rails.logger.ap "Location #{location_name} rejected, only found #{clues.size} clues"
        Rails.logger.ap clues
        next
      else
        chosen_location = location_name
        location_clues = clues
        break
      end
    end
    
    [chosen_location, location_clues]
  end
  
  def clues_for_location(location_name)
    location = Rails.configuration.locations.fetch(location_name)
    ap location
    ap "generating clue for #{location_name}"
    CLUES.map do |clue|
      begin
        clue = send("generate_#{clue}_clue", location).merge(:key => SecureRandom.hex(3))

        Rails.logger.ap clue
        
        clue
      #if clue.values.any?(&:blank?)
      #  ap clue
      #  raise "Invalid Clue"
      #end
      rescue => e
        Rails.logger.ap e.message
        Rails.logger.ap e.class
        Rails.logger.ap e.backtrace
        nil
      end
    end.select{ |clue| clue.keys.size >= 2 }
  end

  def generate_flag_clue(location)
    url = location["The National Flag"]
    return {} if url.blank?
    {
      :type => :image,
      :text => "The National Flag",
      :url => url
    }
  end

  def generate_heads_of_state_clue(location)
    text = Array.wrap(location["heads_of_state"]).
           select(&:present?).
           uniq.
           join(", ")
    return {} if text.blank?
    
    {
      :type => :text,
      :text => text
    }
  end

  def generate_capital_clue(location)
    capital = location["capital"]
    return {} if capital.blank?

    name = capital['name']
    return {} if name.blank?

    name = hide_location_name(name, location)
    
    {
      :type => :text,
      :text => "The Capital is #{name}",
    }
  end

  def generate_currency_clue(location)
    currency = location["currency"]["name"] rescue ""
    return {} if currency.blank?

    location_name = location["name"]
    location_name_prefix = location_name[0,4]

    words = currency.split(/\s+/)

    currency = if words.size <= 2
                 hide_location_name(currency, location)
               else
                 [
                   hide_location_name(words[0] + words[1], location),
                   words[2]
                 ].join(" ")
               end

    {
      :type => :text,
      :text => "National Currency is #{currency}",
    }
  end

  def generate_languages_clue(location)
    langs = location["official_languages"]
    return {} if langs.blank?

    langs = hide_location_name(langs, location)

    return {} if langs.gsub("_", "").blank?

    {
      :type => :text,
      :text => "Official Languages : #{langs}"
    }
  end

  def generate_peak_clue(location)
    peak = location["highest_peak"]
    return {} if peak.blank?
    
    note, rank, name = peak.values_at("note",
                                      "rank_in_world",
                                      "name")
    
    return {} if name.blank?

    rank = rank.to_i
    prefix = rank.ordinalize if rank > 1
    rank_text = rank.zero? ? nil : ["The", prefix, "highest peak in the world."].compact.join(" ")
    
    text = [
      name,
      rank_text
    ].compact.join(", ") + (note.present? ? " ( #{note} )" : "")
    
    {
      :type => :text,
      :text => text
    }
  end

  def hide_location_name(text, location)
    regex_str = location["name"].split(/\s+/).map do |w|
      w[0,4] + "\\w*"
    end.join("\\s*")

    regex_str = "(\\s+|^)" + regex_str

    regex = Regexp.new(regex_str, Regexp::IGNORECASE)
    
    ap regex

    text.gsub(regex) do |w| 
      "_" * w.size
    end
  end
  
  def generate_anthem_clue(location)
    anthem = location['national_anthem']
    return {} if anthem.blank?
    
    name, url = anthem.values_at("name", "audio")
    return {} if url.blank?

    
    name = hide_location_name(name, location)
    
    text = [
      "The National Anthem",
      name
    ].compact.join(" - ")

    {
      :type => :audio,
      :text => text,
      :url => url
    }
  end
end
