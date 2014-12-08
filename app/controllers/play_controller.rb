class PlayController < ApplicationController

  MAX_ATTEMPTS = 3
  
  def index
    
  end

  def ping
    username = params[:username]
    Game.register_ping(username)

    render :json => { :pong => true }
  end
  
  def guess
    location = params[:location]
    username = params[:username]
    game_key = params[:game_key]
    
    game = Redis::HashKey.new(game_key, :marshal => true)

    Rails.logger.ap([
                      location,
                      game['location']
                    ])
    
    if game['location'] == location
      game['winner'] = username
      (game['players'] - [username]).each do |uname|
        Pusher.trigger("user_#{uname}",
                       'game_complete', {
                         :winner => username,
                         :location => Rails.configuration.locations[location]["name"].titleize
                       })
      end
      
      Rails.logger.ap "clearing game"
      game.clear

      render :json => { :complete => true, :remaining => 0 }
    else
      attempt_count_key = 'attempt_count_' + username
      total_attempts = game.incr(attempt_count_key, 1)
      
      if total_attempts > MAX_ATTEMPTS
        attempts_remaining = -1
      else
        attempts_remaining = MAX_ATTEMPTS - total_attempts
      end
      
      render :json => { :remaining => attempts_remaining, :complete => false }
    end
  end
  
  def clue_timeout
    game_key = params[:game_key]
    clue_index = params[:clue_index].to_i

    game = Redis::HashKey.new(game_key, :marshal => true)

    Rails.logger.ap game
    
    timeout_count_key = 'clue_' + clue_index.to_s + "_timeout_count"
    total = game.incr(timeout_count_key, 1)

    if total == game['players'].size
      clue_index = game.incr('clueIndex', 1)

      game['players'].each do |uname| 
        Pusher.trigger("user_#{uname}",
                       'clue_complete', {
                         :next => clue_index
                       })
      end

      if clue_index == game['clues'].size
        Rails.logger.ap "clearing game"
        game.clear
      end
    else
      Rails.logger.ap "clue #{clue_index+1} of game #{game['key']} timed out #{total} times"
    end

    render :json => {}
  end
end
