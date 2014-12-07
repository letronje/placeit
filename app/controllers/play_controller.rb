class PlayController < ApplicationController
  def index
    
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
    else
      Rails.logger.ap "clue #{clue_index+1} of game #{game['key']} timed out #{total} times"
    end

    render :json => {}
  end
end
