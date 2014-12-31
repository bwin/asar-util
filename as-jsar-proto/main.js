
var app = require('app');
var BrowserWindow = require('browser-window');

app.on('ready', function() {
  win1 = new BrowserWindow({
     "width": 400,
     "height": 600
  });
  win1.loadUrl('file://' + __dirname + '/index1.html');
  win1.show();
  win1.openDevTools();
});

/*
var app = require('app'),
    path = require('path');

app.on('will-finish-launching', function() {
    var protocol = require('protocol');
    protocol.registerProtocol('atom', function(request) {
      var url = request.url.substr(7)
      return new protocol.RequestFileJob(path.normalize(__dirname + '/' + url));
    });
});
*/