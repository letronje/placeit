class WelcomeController < ApplicationController
  def index
    redirect_to play_path
  end
end
