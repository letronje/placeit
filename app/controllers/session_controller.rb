class SessionController < ApplicationController
  def create
    Rails.logger.ap params
    
    username = params[:username]
    
    if username.present?
      session['username'] = username
      
      queue = Redis::List.new("user_queue")
      opponent = queue.pop()
    end

    if opponent.present?
      Rails.logger.ap "found opponent #{opponent}"
      
      players = [username, opponent]

      game_info = Game.create(players)

      Pusher.trigger("user_#{opponent}", 'game_ready', game_info)
    else
      Rails.logger.ap "no opponent found"
      queue << username
      game_info = {}
    end
    
    render :json => {
             :game_ready => opponent.present?,
             :game => game_info
           }
  end
end
