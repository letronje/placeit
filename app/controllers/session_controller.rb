class SessionController < ApplicationController
  def create
    username = params[:username]
    
    if username.blank?
      render :json => {} and return
    end
    
    session['username'] = username

    queue = Redis::List.new("user_queue")

    opponent = loop do
      opponent = queue.pop()
      
      break if opponent.blank?
      
      opponent_key = "user_#{opponent}"
      opponent_info = Redis::HashKey.new(opponent_key, :marshal => true)

      since = Time.now - opponent_info['last_pinged_at']
      
      if(since >= 5)
        Rails.logger.ap "rejecting opponent #{opponent}, last pinged #{since} seconds ago"
        next
      else
        Rails.logger.ap "Found opponent #{opponent}, last pinged #{since} seconds ago"
        break opponent
      end
    end

    if opponent.present?
      Rails.logger.ap "found opponent #{opponent}"
      
      players = [username, opponent]

      players.each do |player|
        Game.register_ping(player)
      end
      
      game_info = Game.create(players)

      Pusher.trigger("user_#{opponent}", 'game_ready', game_info)
    else
      Rails.logger.ap "no opponent found"
      queue << username

      Game.register_ping(username)
      
      game_info = {}
    end
    
    render :json => {
             :game_ready => opponent.present?,
             :game => game_info
           }
  end
end
