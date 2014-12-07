_.templateSettings.interpolate = /{{([\s\S]+?)}}/g;

function l(o){
  return console.log(o);
}

function startPlaying(username, game_data){
  g.game = game_data;
  g.game.clueIndex = 0;
  
  var opponent = _.difference(g.game.players, [g.username])[0];
  l("You are up against " + opponent);
  renderClue();
  userChannel().bind('clue_complete', function(data) {
    handleClueComplete(data.next);
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
    setTimeout(function(){
      countDown(total, timeoutFn, n-1);
    }, 1000);
  }
  else{
    timeoutFn();
  }
}

function handleClueTimeout(){
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
  $("#clue_container").show();

  if(g.game.clueIndex >= _.size(g.game.clues)){
    l("We are done");
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
  $("#clue_container .content").html(clue.text);
}

var imageClueTemplate = _.template("<img src='{{url}}' /><br/><h2>{{text}}</h2>");

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

  $("form").submit(function(e){
    e.preventDefault();

    //TODO: figure out why the hell is the line below needed ?
    //ref: http://stackoverflow.com/a/18681588
    e.stopImmediatePropagation();

    var formData = $(this).serializeObject();
    var username = formData.username;
    
    $.post(g.createSessionPath, formData, function(data){
      g.username = username;

      $("#new_session_container").fadeOut();
      if(data.game_ready){
        startPlaying(username, data.game);
      }
      else{
        $.blockUI({message: "Please wait while we find an opponent for you."});
        userChannel().bind('game_ready', function(data) {
          $.unblockUI();
          startPlaying(username, data);
        });
      }
    });
  });
  
  
  
  
  
  
});
