console.log("** FROM file1.js", __filename, __dirname);

//zipfile = require("../../x/node_modules/zipfile"); // native module outside asar
//zipfile = require("../node_modules/zipfile"); // native module in node_modules one level up, but still inside asar
//zipfile = require("zipfile"); // native module in node_modules one level up, but still inside asar
//console.log("zipfile", zipfile);
time = require("time"); // native module in node_modules one level up, but still inside asar
console.log("time", time);

data = require("../data");
console.log("data.json", data);
require("../dir2/file2");
require("testmodule");
require("../../file3"); // outside asar
require("../../x2.asar/file4.js"); // inside another asar
require("../../xc.asar/file5.js"); // inside another asar (compressed)
require("./file6"); // coffeescript
time2 = require("../node_modules/time/build/Release/time.node"); // native module in node_modules one level up, but still inside asar
console.log("time2", time2);