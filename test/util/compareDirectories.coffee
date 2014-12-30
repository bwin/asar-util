
os = require 'os'
fs = require 'fs'
path = require 'path'

walkdir = require 'walkdir'
_ = require 'lodash'
streamEqual = require 'stream-equal'
queue = require 'queue-async'

crawlFilesystem = (dir, cb) ->
	paths = []
	metadata =

	emitter = walkdir(dir)
	emitter.on 'directory', (p, stat) ->
		p = path.relative(dir, p)
		paths.push(p)
		metadata[p] =
			type: 'directory'
			stat: stat
	emitter.on 'file', (p, stat) ->
		p = path.relative(dir, p)
		paths.push(p)
		metadata[p] =
			type: 'file'
			stat: stat
	emitter.on 'link', (p, stat) ->
		p = path.relative(dir, p)
		paths.push(p)
		metadata[p] =
			type: 'link'
			stat: stat
	emitter.on 'end', ->
		paths.sort()
		cb no, paths, metadata
	emitter.on 'error', cb


module.exports = (dirA, dirB, cb) ->
	crawlFilesystem dirA, (err, pathsA, metadataA) ->
		crawlFilesystem dirB, (err, pathsB, metadataB) ->
			onlyInA = _.difference pathsA, pathsB
			onlyInB = _.difference pathsB, pathsA
			inBoth = _.intersection pathsA, pathsB
			differentFiles = []
			errorMsg = '\n'

			compareFiles = (filename, cb) ->
				typeA = metadataA[filename].type
				typeB = metadataB[filename].type
				# skip if both are directories
				return cb() if typeA is 'directory' and typeB is 'directory'

				# something is wrong if one entry is a file and the other is a directory
				# we already know that not bothof them are dirs
				if typeA is 'directory' or typeB is 'directory'
					differentFiles.push filename
					return cb()
				streamA = fs.createReadStream path.join dirA, filename
				streamB = fs.createReadStream path.join dirB, filename
				streamEqual streamA, streamB, (err, equal) ->
					differentFiles.push filename unless equal
					cb()
					return
				return

			q = queue 1
			q.defer compareFiles, filename for filename in inBoth
			
			q.awaitAll (err) ->
				errorMsg = ['directory content is not the same']
				if onlyInA.length
					errorMsg.push "\tEntries only in '#{dirA}':"
					for filename in onlyInA
						errorMsg.push "\t  #{filename}"
				
				if onlyInB.length
					errorMsg.push "\tEntries only in '#{dirB}':"
					for filename in onlyInB
						errorMsg.push "\t  #{filename}"
				
				if differentFiles.length
					errorMsg.push '\tDifferent file content:'
					for filename in differentFiles
						errorMsg.push "\t  #{filename}"

				isIdentical = errorMsg.length is 1

				err = if isIdentical then null else new Error errorMsg.join os.EOL

				cb err
				return
			return
		return
	return
