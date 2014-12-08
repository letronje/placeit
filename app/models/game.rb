module Game
  extend self

  CLUES = [
    :landmark,

    :flag,

    :peak,
    
    :landmark,

    :currency,

    :languages,

    :city,

    :heads_of_state,

    :city,

    :capital
  ]

  MIN_CLUES = 10

  class << self
    attr_accessor :location_clues
  end

  def register_ping(username)
    user_key = "user_#{username}"
    user = Redis::HashKey.new(user_key, :marshal => true)
    user['last_pinged_at'] = Time.now
  end
  
  def all_location_clues
    all_locations = Rails.configuration.locations
    all_locations.map do |location_name, info|
      next if info["name"].blank?
      
      clues = clues_for_location(location_name)
      next if clues.size < MIN_CLUES
      
      [info["name"], clues]
    end.compact
  end

  def self.location_clues
    @location_clues ||= all_location_clues
  end
  
  def create(players)
    location_name, clues = self.location_clues.sample

    game_key = ["game", *players.sort].join("_")
    game = Redis::HashKey.new(game_key, :marshal => true)

    game_info = {
      'players' => players,
      'location' => location_name,
      'clues' => clues,
      'locations' => location_clues.map(&:first)
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
        chosen_location = locations[location_name]["name"]
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
        clue = send("generate_#{clue}_clue", location)

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
    end.select(&:present?).uniq
  end

  def generate_city_clue(location)
    cities = location["cities"]
    return {} if cities.blank?
    
    name, url = cities.select{ |city| 
      city["name"].present? && city["img_src"].present?
    }.sample.values_at("name", "img_src")

    {
      :type => :image,
      :text => "City : " + hide_location_name(name, location),
      :url => url
    }
  end

  def generate_landmark_clue(location)
    landmarks = location["landmarks"]
    return {} if landmarks.blank?
    
    name, url = landmarks.select{ |landmark| 
      landmark["name"].present? && landmark["img_src"].present?
    }.sample.values_at("name", "img_src")

    {
      :type => :image,
      :text => "Landmark : " + hide_location_name(name, location),
      :url => url
    }
  end
  
  def generate_flag_clue(location)
    url = location["flag"]

    facts = location["facts"]
    
    if facts.present?
      flag_fact = facts.find{ |fact| fact["name"] =~ /flag/i }
      if flag_fact.present?
        url = flag_fact["img_src"]
      end
    end
    
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
      :text => "Heads of State : " + text
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
      :text => "The Capital : #{name}",
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
      :text => "National Currency : #{currency}",
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
      :text => "The Highest Peak: " + text
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
      :url => "http://upload.wikimedia.org/wikipedia/commons/6/65/Star_Spangled_Banner_instrumental.ogg"
    }
  end
end
