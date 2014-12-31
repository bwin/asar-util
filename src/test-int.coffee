
#integration = require './integration'
##fs = require 'fs'
##integration.takeOver fs
#integration.takeOver()
#require('./integration').takeOver()
require './register'


y = require '../test/x.asar/dir1/file1'
#t2 = require '../test/x/node_modules/time'
#t2b = require '../test/x/node_modules/time/build/Release/time.node'
#t = require '../test/x.asar/node_modules/time'
#tb = require 'C:\\Users\\vbox\\AppData\\Local\\Temp\\asar-time.node'
#tb = require '../test/x.asar/node_modules/time/build/Release/time.node'
#console.log "t2",t2
#console.log "t2b", t2b
#console.log t
#console.log "tb", tb

### test
- [x] req out of arch
- [x] req from node_modules in arch
- [x] req into another arch
- [x] req native mod from arch
- [x] req compressed out of arch
- [x] req coffee out of arch
- [x] req json out of arch

- [ ] FIX missing files from archive !!!

maybe:
- [ ] require "jsar/register"
- [ ] archive: is origfs really neccessary?
- [ ] cached archives should have a fd open (should they?)
- [ ] emit events: "fs.lstatSync", args...

jsonHeader =
	version: 2
?	engines:
?		'atom-shell': '~0.21.0'
	files:
		"file1":
			size: 50
			segments: [
				offset: 10, size: 30
			,
				offset: 90, size: 20
			]
		"file2": offset: 10, size: 30
		"file3": offset: 10, size: 30, csize: 20
		"file4": offset: 10, size: 30, ctime: 12345, mtime: 12345

?	gaps: [ [ofs, size], ... ]
###

#cli = require './cli'
#asar = require './asar'
