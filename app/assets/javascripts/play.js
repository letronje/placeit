_.templateSettings.interpolate = /{{([\s\S]+?)}}/g;

function l(o){
  return console.log(o);
}

function blockUI(msg, timeout, cb){
  if(!timeout){
    timeout = 3600 * 1000;
  }

  if(!cb){
    cb = _.noop();
  }
  
  $.blockUI({
    message: msg,
    css: { 
      border: 'none', 
      padding: '15px', 
      backgroundColor: '#000', 
      '-webkit-border-radius': '10px', 
      '-moz-border-radius': '10px', 
      opacity: .5, 
      color: '#fff' 
    }
  });

  setTimeout(function() { 
    $.unblockUI({ 
      onUnblock: cb
    }); 
  }, timeout); 
}

function unblockUI(){
  $.unblockUI();
}

function ping(){
  $.post(g.pingPath, {username: g.username}, function(data){
    l('got pong');
    l(data);
  });
}

function startPlaying(username, game_data){
  g.game = game_data;
  g.game.clueIndex = 0;

  var opponent = _.difference(g.game.players, [g.username])[0];
  blockUI("You are up against " + opponent, 2000, function(){
    setupLocationGuessing();
    
    renderClue();

    userChannel().bind('clue_complete', function(data) {
      handleClueComplete(data.next);
    });

    userChannel().bind('game_complete', function(data) {
      if(data.winner != g.username){
        clearTimeout(g.clueTimeoutRef);
        g.game_completed = true;
        blockUI("The opponent won, the country is " + data.location, 5000);
      }
    });
  });
}

function setupLocationGuessing(){
  var options = _.map(g.game.locations, function(location_name){
    return({
      id: location_name,
      text: location_name
    });
  });

  $("#locations").select2({data: options, placeholder: "Select Country", allowClear: false});

  $("#guess_location").click(function(){
    if(g.game_completed){
      blockUI("Game Over. Please refresh for a fresh game.", 1000);
      return;
    }
    
    if(g.guesses_remaining <= 0){
      blockUI("You have exhaused all your chances.", 1000);
      return;
    }
    
    var guess = $("#locations").select2("val");

    if(_.isEmpty(guess)){
      return;
    }
    
    var postData = {
      game_key: g.game.key,
      username: g.username,
      location: guess
    };
    
    $.post(g.guessLocationPath, postData, function(data){
      l(data);

      if(data.complete){
        clearTimeout(g.clueTimeoutRef);
        g.game_completed = true;
        blockUI("That was the correct guess, you won!!", 2000);
      }
      else{
        g.guesses_remaining = data.remaining;
        if(g.guesses_remaining < 0){
          blockUI("You have exhaused all your chances.", 2000);
        }
        else{
          blockUI("That was a wrong guess, you have " + data.remaining + " more chances.", 2000);
        }
      }
    });
    
  });
}

function handleClueComplete(nextClueIndex){
  g.game.clueIndex = nextClueIndex;
  l("Next clue : " + nextClueIndex);
  renderClue();
}

function toTitleCase(str)
{
  return str.replace(/\w\S*/g, function(txt){
    return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
  });
}

function countDown(total, timeoutFn, n){
  if(_.isUndefined(n)){
    n = total;
  }
  
  $("#clue_container .counter").html(n);
  
  if(n != 0){
    g.clueTimeoutRef = setTimeout(function(){
      countDown(total, timeoutFn, n-1);
    }, 1000);
  }
  else{
    timeoutFn();
  }
}

function handleClueTimeout(){
  $("#clue_container").fadeTo("slow", 0.33);
  var postData = {
    game_key: g.game.key,
    clue_index: g.game.clueIndex
  };

  l(postData);
  
  $.post(g.clueTimeoutPath, postData, function(data){
    l("notified timeout for clue " + g.game.clueIndex);
  });
  
  l("Timeup, waiting for next clue");
}

function renderClue(){
  $("#clue_container").fadeTo("slow", 1.0);

  if(g.game.clueIndex >= _.size(g.game.clues)){
    g.game_completed = true;
    blockUI("Game Over", 5000);
    return;
  }
  
  var clue = g.game.clues[g.game.clueIndex];

  renderClueCount();
  window['render' + toTitleCase(clue.type) + 'Clue'](clue);

  setTimeout(function(){
    countDown(g.clueTimeout, handleClueTimeout);
  }, 1000);
}

function renderClueCount(){
  $("#clue_container .title").html("Clue #" + (g.game.clueIndex+1));
}

function renderTextClue(clue){
  $("#clue_container .content").html(clue.text);
}

function renderAudioClue(clue){
  var html = '<audio autoplay="autoplay" controls="controls"><source src="' + clue.url + '" /></audio><br /><h2>' + clue.text + "</h2";
  $("#clue_container .content").html(html);
}

var imageClueTemplate = _.template("<div style='width: 500px; height: 250px;'><img style='min-height: 100%; max-width: 100%; max-height: 100%; ' src='{{url}}' /></div><br/><h2>{{text}}</h2>");

function renderImageClue(clue){
  $("#clue_container .content").html(imageClueTemplate(clue));
}

function userChannel(){
  if(!g.userChannel){
    l('setting up user channel for ' + g.username);
    var channelName = 'user_' + g.username;
    g.userChannel = g.pusher.subscribe(channelName);
  }
  
  return g.userChannel;
}

$(function(){
  $("#new_session_container").fadeIn("slow");
  $("form").submit(function(e){
    e.preventDefault();

    //TODO: figure out why the hell is the line below needed ?
    //ref: http://stackoverflow.com/a/18681588
    e.stopImmediatePropagation();

    var formData = $(this).serializeObject();
    var username = formData.username;
    
    $.post(g.createSessionPath, formData, function(data){
      
      g.username = username;

      g.pingIntervalRef = setInterval(ping, 1000);
      
      $("#new_session_container").fadeOut();
      if(data.game_ready){
        startPlaying(username, data.game);
      }
      else{
        blockUI("Please wait while we find an opponent for you ... Or Click <a href='/play' target='_blank' >here</a> to start playing as the opponent.");
        userChannel().bind('game_ready', function(data) {
          unblockUI();
          startPlaying(username, data);
        });
      }
    });
  });
});
