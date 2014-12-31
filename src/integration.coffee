
fs = require 'fs'
child_process = require 'child_process'

#vm = require 'vm'
path = require 'path'

temp = require 'temp'

asar = require './asar'

# Automatically track and cleanup temp files at exit
#temp.track()

reportArchiveAsDirectory = yes#no # report it as file if off
maxCompatibility = no#yes # use temp files if on
dbg = no

# Override APIs that rely on passing file path instead of content to C++.
overrideAPISync = (module, name, arg = 0) ->
	old = module[name]
	module[name] = ->
		console.log "*** overrideAPISync #{name}", arguments if dbg
		p = arguments[arg]
		[isAsar, asarPath, filePath] = splitPath p
		return old.apply this, arguments unless isAsar

		newPath = copyFileOut asarPath, filePath
		throw new Error 'tempfileerror' unless newPath

		#archive = getOrLoadArchive asarPath
		#throw new Error("Invalid package #{asarPath}") unless archive

		#newPath = archive.copyFileOut filePath
		#throw createNotFoundError(asarPath, filePath) unless newPath

		arguments[arg] = newPath
		old.apply this, arguments
		
overrideAPI = (module, name, arg = 0) ->
	old = module[name]
	module[name] = ->
		console.log "*** overrideAPI #{name}", arguments if dbg
		p = arguments[arg]
		[isAsar, asarPath, filePath] = splitPath p
		return old.apply this, arguments unless isAsar
		
		callback = arguments[arguments.length - 1]
		return overrideAPISync module, name, arg unless typeof callback is 'function'

		newPath = copyFileOut asarPath, filePath
		throw new Error 'tempfileerror' unless newPath

		#archive = getOrCreateArchive asarPath
		#return callback new Error("Invalid package #{asarPath}") unless archive

		#newPath = archive.copyFileOut filePath
		#return callback createNotFoundError(asarPath, filePath) unless newPath

		arguments[arg] = newPath
		old.apply this, arguments

copyFileOut = (asarPath, filePath) ->
	archive = getOrLoadArchive asarPath
	throw new Error "Invalid package #{asarPath}" unless archive
	metadata = archive.getMetadata filePath
	throw new Error "File not found in package #{asarPath}:#{filePath}" unless metadata
	tempFile = temp.openSync "asar-#{path.basename filePath}-"
	content = archive.getFile filePath
	throw new Error "Could not read from package #{asarPath}:#{filePath}" unless content
	fs.writeSync tempFile.fd, content, 0, content.length
	fs.closeSync tempFile.fd
	console.log "*** TMP file ***", asarPath, filePath if dbg
	return tempFile.path

createNotFoundError = (asarPath, filePath) ->
	error = new Error "ENOENT, #{filePath} not found in #{asarPath}"
	error.code = "ENOENT"
	error.errno = -2
	error

# Cache asar archive objects.
cachedArchives = {}
getOrLoadArchive = (p) ->
	#console.log "getOrLoadArchive", p
	archive = cachedArchives[p]
	return archive if archive?
	#console.log "getOrLoadArchive LOAD!", p
	try archive = asar.loadArchive p
	catch err
		console.log "ERR", err
		return no
	return no unless archive
	cachedArchives[p] = archive
	#console.log "getOrLoadArchive got archive", archive
	return archive

# Separate asar package's path from full path.
originalLstatSync = fs.lstatSync
splitPath = (p) ->
	return [no] if typeof p isnt 'string'
	matches = p.match /.*?\.asar/g
	return [no] unless matches
	matchPath = ''
	for match in matches
		matchPath = [matchPath, match].filter( (x) -> x ).join '/'
		#try matchStat = originalLstatSync matchPath
		#catch err
		#	return [no]
		matchStat = isFile: -> yes
		filePath = p.replace matchPath, ''
		#console.log "### reportArchiveAsDirectory",reportArchiveAsDirectory, "filePath", filePath
		return [no] if filePath is '' and not reportArchiveAsDirectory
		return [yes, matchPath, filePath] if matchStat.isFile()
	return [no]

nextInode = 0
uid = if process.getuid? then process.getuid() else 0
gid = if process.getgid? then process.getgid() else 0
fakeTime = new Date()
asarStatsToFsStats = (metadata) ->
	dev: 1
	ino: ++nextInode
	mode: 33188
	nlink: 1
	uid: uid
	gid: gid
	rdev: 0
	atime: fakeTime
	birthtime: fakeTime
	mtime: fakeTime
	ctime: fakeTime
	size: metadata.size or 0
	isFile: -> metadata.size?
	isDirectory: -> metadata.files?
	isSymbolicLink: -> metadata.link?
	isBlockDevice: -> no
	isCharacterDevice: -> no
	isFIFO: -> no
	isSocket: -> no

module.exports =
	takeOver: (hostObj) ->
		hostObj ?= require 'fs'
		origFs =
			openSync: hostObj.openSync
			closeSync: hostObj.closeSync
			readSync: hostObj.readSync
			existsSync: hostObj.existsSync
			statSync: hostObj.statSync
			lstatSync: hostObj.lstatSync
			fstatSync: hostObj.fstatSync

		#wrapSyncApi = (funcName) ->
		#	origFs[funcName] = hostObj[funcName]
		#	hostObj[funcName] = (args...) ->
		#		console.log "** fs.#{funcName}", args...
		#		return origFs[funcName] args...
		#
		#if dbg
		#	wrapSyncApi 'readDirSync'
		#	#wrapSyncApi 'statSync'
		#	#wrapSyncApi 'lstatSync'
		#	#wrapSyncApi 'fstatSync'
		#	#wrapSyncApi 'closeSync'

		if maxCompatibility
			# these use copyFileOut
			overrideAPISync fs, 'openSync'
		else
			hostObj.openSync = (p, flags, mode) ->
				console.log "* openSync", p if dbg
				
				[isAsar, asarPath, filePath] = splitPath p
				return origFs.openSync p, flags, mode unless isAsar

				archive = getOrLoadArchive asarPath
				throw new Error("Invalid package #{asarPath}") unless archive
				metadata = archive.getMetadata filePath

				if metadata
					console.log "--- open File found", filePath if dbg
				else
					console.log "--- open File NOT found", filePath if dbg

				throw new Error("File not found in package #{asarPath}:#{filePath}") unless metadata

				return {asarPath, filePath}


		# these use copyFileOut
		overrideAPI fs, 'open'
		overrideAPI child_process, 'execFile'
		overrideAPISync process, 'dlopen', 1
		overrideAPISync require('module')._extensions, '.node', 1
		overrideAPISync child_process, 'fork'




		hostObj.statSync = (path) ->
			[isAsar, asarPath, filePath] = splitPath path
			console.log "* statSync", path, [isAsar, asarPath, filePath] if dbg
			#console.log "* statSync bypass", origFs.statSync(path) unless isAsar
			return origFs.statSync path unless isAsar

			#console.log "*stat 1.1"
			archive = getOrLoadArchive asarPath
			#console.log "*stat 1.2 arc:", archive
			throw new Error("Invalid package #{asarPath}") unless archive
			#console.log "*stat 1.3"
			metadata = archive.getMetadata filePath
			#console.log "*stat 1.4"

			if metadata
				console.log "--- stat File found", filePath if dbg
			else
				console.log "--- stat File NOT found", filePath if dbg

			throw new Error("File not found in package #{asarPath}:#{filePath}") unless metadata
			#console.log "*stat 1.5"
			stat = asarStatsToFsStats metadata
			#console.log "*stat", stat
			return stat

		hostObj.lstatSync = (path) -> 
			[isAsar, asarPath, filePath] = splitPath path
			console.log "* LstatSync", path, [isAsar, asarPath, filePath] if dbg
			#console.log "* LstatSync bypass" unless isAsar
			return origFs.lstatSync path unless isAsar

			#console.log "* Lstat 1.1"
			archive = getOrLoadArchive asarPath
			#console.log "* Lstat 1.2 arc:", archive
			throw new Error("Invalid package #{asarPath}") unless archive
			#console.log "* Lstat 1.3"
			if filePath
				metadata = archive.getMetadata filePath
			else # asar archive root (pretend it's a directory)
				metadata = files: 1
			#console.log "* Lstat 1.4"
			
			if metadata
				console.log "--- lstat File found", filePath if dbg
			else
				console.log "--- lstat File NOT found", filePath if dbg

			throw new Error("File not found in package #{asarPath}:#{filePath}") unless metadata
			#console.log "* Lstat 1.5"
			stat = asarStatsToFsStats metadata
			#console.log "* Lstat", stat
			return stat

		hostObj.fstatSync = (fd) ->
			return origFs.fstatSync fd unless fd.asarPath?
			{asarPath, filePath} = fd
			archive = getOrLoadArchive asarPath
			#console.log "*fstat 1.2 arc:", archive
			throw new Error("Invalid package #{asarPath}") unless archive
			#console.log "*fstat 1.3"
			metadata = archive.getMetadata filePath
			#console.log "*fstat 1.4"
			throw new Error("File not found in package #{asarPath}:#{filePath}") unless metadata
			#console.log "*fstat 1.5"
			stat = asarStatsToFsStats metadata
			#console.log "*fstat", stat
			return stat

		hostObj.closeSync = (fd) ->
			console.log "* closeSync", fd if dbg
			return origFs.closeSync fd unless fd.asarPath?
			return yes

		hostObj.readSync = (fd, buffer, offset, length, position) ->
			console.log "** readSync fd=#{fd} offset=#{offset} length=#{length} position=#{position}" if dbg
			#[isAsar, asarPath, filePath] = splitPath path

			return origFs.readSync fd, buffer, offset, length, position unless fd.asarPath?

			{asarPath, filePath} = fd

			console.log "** readSync it is asar", asarPath, filePath if dbg

			archive = getOrLoadArchive asarPath
			throw new Error("Invalid package #{asarPath}") unless archive

			#data = archive.getFile(filePath).toString().substr(offset, length)
			data = archive.getFile(filePath).slice(offset, length)
			#if data.length
			#	console.log "*********************** data", data.toString()
			#else
			#	console.log "*********************** no data"
			return 0 unless data
			if typeof data is 'string'
				buffer.write data
			else # it's a buffer
				data.copy buffer

			return data.length

			return 0 if offset
			fake = '{}'
			buffer.write fake
			return fake.length
			

		hostObj.existsSync = (path) ->
			console.log "** existsSync", path if dbg
			[isAsar, asarPath, filePath] = splitPath path

			return origFs.existsSync path unless isAsar

			#console.log "** existsSync asar"
			try archive = getOrLoadArchive asarPath
			catch err
				throw new Error("Invalid package #{asarPath}") unless archive

			try source = archive.getFile filePath
			catch err
				return no
			return yes
