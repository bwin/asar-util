
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
stream = require 'stream'

walkdir = require 'walkdir'
minimatch = require 'minimatch'
mkdirp = require 'mkdirp'

sortBy = (prop) -> (a, b) ->
	return -1 if a[prop] < b[prop]
	return 1 if a[prop] > b[prop]
	return 0

module.exports = class AsarArchive
	MAGIC: 'ASAR\r\n'
	VERSION: 1

	constructor: (@opts) ->
		@reset()
		return

	reset: ->
		@_header =
			version: @VERSION
			files: {}
		@_headerSize = 0
		@_offset = 0
		@_archiveSize = 0
		@_files = []
		@_archiveName = null
		@_checksum = null
		@_legacyMode = no
		return

	_searchNode: (p, create=yes) ->
		p = p.substr 1 if p[0] in '/\\'.split '' # get rid of leading slash
		#! console.log "_searchNode", p
		name = path.basename p
		node = @_header
		dirs = path.dirname(p).split path.sep
		for dir in dirs
			throw new Error "#{p} not found." unless node?
			if dir isnt '.'
				node.files[dir] ?= {files:{}} if create
				node = node.files[dir]
			#! console.log "dir", dir, @_header
		throw new Error "#{p} not found." unless node?
		#! console.log "header,node,return", @_header, node, node.files[name]
		node.files[name] ?= {} if create
		node = node.files[name]
		return node

	_readHeader: (fd) ->
		magicLen = @MAGIC.length
		magicBuf = new Buffer magicLen
		if fs.readSync(fd, magicBuf, 0, magicLen, null) isnt magicLen
			throw new Error "Unable to open archive: #{@_archiveName}"
		if magicBuf.toString() isnt @MAGIC
			#throw new Error 'Invalid magic number'
			#console.warn 'Deprecation notice: old version of asar archive.'
			return @_readHeaderOld fd

		sizeBufSize = 4
		headerSizeOfs = @_archiveSize - (4 + 16 + 4) # headerSize, checksum, archiveSize
		headerSizeBuf = new Buffer sizeBufSize
		if fs.readSync(fd, headerSizeBuf, 0, sizeBufSize, headerSizeOfs) isnt sizeBufSize
			throw new Error "Unable to read header size: #{@_archiveName}"
		headerSize = headerSizeBuf.readUInt32LE 0

		headerOfs = @_archiveSize - headerSize - (4 + 16 + 4) # headerSize, checksum, archiveSize
		headerBuf = new Buffer headerSize
		if fs.readSync(fd, headerBuf, 0, headerSize, headerOfs) isnt headerSize
			throw new Error "Unable to read header: #{@_archiveName}"

		checksumSize = 16
		checksumOfs = @_archiveSize - 16 - 4 # checksum, archiveSize
		@_checksum = new Buffer checksumSize
		if fs.readSync(fd, @_checksum, 0, checksumSize, checksumOfs) isnt checksumSize
			throw new Error "Unable to read checksum: #{@_archiveName}"

		try
			@_header = JSON.parse headerBuf
		catch err
			throw new Error "Unable to parse header: #{@_archiveName}"
		@_headerSize = headerSize
		return

	_readHeaderOld: (fd) ->
		@_legacyMode = yes

		sizeBufSize = 8
		sizeBuf = new Buffer sizeBufSize
		if fs.readSync(fd, sizeBuf, 0, sizeBufSize, 0) isnt sizeBufSize
			throw new Error 'Unable to read header size (assumed old format)'
		size = sizeBuf.readUInt32LE 4

		#if fs.readSync(fd, sizeBuf, 0, sizeBufSize, 8) isnt sizeBufSize
		#	throw new Error 'Unable to read header something between size and json-header (assumed old format)'
		#console.log "s=", size
		#console.log "s1=", sizeBuf.readUInt32LE 0
		#console.log "s2=", sizeBuf.readUInt32LE 4

		actualSize = size - 8
		headerBuf = new Buffer actualSize
		if fs.readSync(fd, headerBuf, 0, actualSize, 16) isnt actualSize
			throw new Error 'Unable to read header (assumed old format)'

		try
			# remove trailing 0's (because of padding that can occur?)
			headerStr = headerBuf.toString().replace /\0+$/g, ''
			@_header = JSON.parse headerStr
		catch err
			console.log "header:'#{x}'",err
			throw new Error 'Unable to parse header (assumed old format)'
		@_headerSize = size
		return

	_writeHeader: (out, cb) ->
		out.write @MAGIC, cb
		return

	_writeFooter: (out, cb) ->
		headerStr = JSON.stringify @_header

		@_headerSize = headerStr.length
		headerSizeBuf = new Buffer 4
		headerSizeBuf.writeUInt32LE @_headerSize, 0
		
		out.write headerStr, =>
			out.write headerSizeBuf, =>
				archiveFile = fs.createReadStream @_archiveName
				md5 = crypto.createHash('md5')
				archiveFile.pipe md5
				archiveFile.on 'end', =>
					# is this really ok ???
					@_checksum = md5.read()
					@_archiveSize = 4 + @_offset + @_headerSize + 4 + 16 + 4  
					if @_archiveSize > 4294967295 # because of js precision limit
						return cb? new Error "archive size can not be larger than 4.2GB"
					archiveSizeBuf = new Buffer 4
					archiveSizeBuf.writeUInt32LE @_archiveSize, 0

					out.write @_checksum, ->
						out.write archiveSizeBuf, cb
						return
					return
				return
			return
		return

	_crawlFilesystem: (dir, pattern, cb) ->
		# cb: (err, paths=[{name, stat}, ...])
		paths = []

		walker = walkdir dir
		walker.on 'path', (p, stat) ->
			paths.push
				name: p
				stat: stat
			return
		walker.on 'end', =>
			if pattern
				matchFn = minimatch.filter pattern, matchBase: yes
				paths = paths.filter (a) ->	matchFn path.sep + path.relative dir, a.name
			paths.sort sortBy 'name'
			return cb? null, paths
		walker.on 'error', cb
		return

	# opens an asar archive from disk
	#open: (archiveName, cb) ->
	openSync: (archiveName) ->
		@reset()
		@_archiveName = archiveName

		try
			@_archiveSize = fs.lstatSync(archiveName).size
			fd = fs.openSync archiveName, 'r'
			@_readHeader fd
		catch err
			throw err
		fs.closeSync fd

		if @_header.version? and @_header.version > @VERSION
			throw new Error "Unsupported asar format version: #{@_header.version} (max supported: #{@VERSION})"

		return yes

	# saves an asar archive to disk
	write: (archiveName, opts, cb) ->
		@_archiveName = archiveName

		# create output dir if necessary
		mkdirp.sync path.dirname archiveName

		queue = require 'queue-async'

		writeFile = (filename, out, cb) ->
			src = fs.createReadStream filename
			src.on 'end', cb
			src.pipe out, end: no
			return
		
		out = fs.createWriteStream archiveName
		@_writeHeader out, =>
			q = queue 1
			for file in @_files
				q.defer writeFile, file, out
				q.awaitAll (err) =>
					return cb? err if err
					@_writeFooter out, cb
					
			return
		return
	#writeSync: (archiveName) ->
	#	return

	# retrieves a list of all entries (dirs, files) in archive
	getEntries: (archiveRoot='/', pattern=null)->
		archiveRoot = archiveRoot.substr 1 if archiveRoot.length > 1 and archiveRoot[0] in '/\\'.split '' # get rid of leading slash
		files = []
		fillFilesFromHeader = (p, json) ->
			return unless json?.files?
			for f of json.files
				fullPath = path.join p, f
				files.push fullPath
				fillFilesFromHeader fullPath, json.files[f]
			return

		if archiveRoot is '/'
			json = @_header
		else
			json = @_searchNode archiveRoot, no
			files.push archiveRoot if json.size
			archiveRoot = "#{path.sep}#{archiveRoot}"

		fillFilesFromHeader archiveRoot, json

		files = files.filter minimatch.filter pattern, matchBase: yes if pattern

		return files

	# !!! ...
	getMetadata: (filename) ->
		node = @_searchNode filename, no
		return node

	# !!! ...
	getFile: (filename) ->
		fd = fs.openSync @_archiveName, 'r'
		node = @_searchNode filename, no
		return '' unless node.size > 0
		buffer = new Buffer node.size
		unless @_legacyMode
			offset = @MAGIC.length + parseInt node.offset, 10
		else
			offset = 8 + @_headerSize + parseInt node.offset, 10
		fs.readSync fd, buffer, 0, node.size, offset
		fs.closeSync fd
		return buffer
	
	# !!! ...
	extractFileSync: (filename, destFilename) ->
		mkdirp.sync path.dirname destFilename
		fs.writeFileSync destFilename, @getFile filename
		return yes

	# !!! ...
	createReadStream: (filename) ->
		node = @_searchNode filename, no
		if node.size > 0
			unless @_legacyMode
				start = @MAGIC.length + parseInt node.offset, 10
			else
				start = 8 + @_headerSize + parseInt node.offset, 10
			end = start + node.size - 1
			return fs.createReadStream @_archiveName, start: start, end: end
		else
			emptyStream = stream.Readable()
			emptyStream.push null
			return emptyStream
		
	# !!! ...
	extract: (dest, opts, cb) ->
		# make opts optional
		if typeof opts is 'function'
			cb = opts
			opts = {}
		# init default opts
		archiveRoot = opts.root or '/'
		pattern = opts.pattern

		filenames = @getEntries archiveRoot, pattern
		if filenames.length is 1
			archiveRoot = path.dirname archiveRoot
		else
			mkdirp.sync dest # create destination directory

		relativeTo = archiveRoot
		relativeTo = relativeTo.substr 1 if relativeTo[0] in '/\\'.split ''
		relativeTo = relativeTo[...-1] if relativeTo[-1..] in '/\\'.split ''

		writeStreamToFile = (inStream, destFilename, cb) ->
			out = fs.createWriteStream destFilename
			inStream.on 'end', cb
			inStream.on 'error', cb
			inStream.pipe out
			return

		q = queue 1
		for filename in filenames
			destFilename = filename
			destFilename = destFilename.replace relativeTo, '' if relativeTo isnt '.'
			destFilename = path.join dest, destFilename
			console.log "#{filename} -> #{destFilename}" if @opts.verbose

			node = @_searchNode filename, no
			if node.files
				# it's a directory, create it
				mkdirp.sync destFilename
			else
				inStream = @createReadStream filename
				q.defer writeStreamToFile, inStream, destFilename

		q.awaitAll (err) => cb? err

	# !!! ...
	extractSync: (dest, archiveRoot='/', pattern=null) ->
		filenames = @getEntries archiveRoot, pattern
		if filenames.length is 1
			archiveRoot = path.dirname archiveRoot
		else
			mkdirp.sync dest # create destination directory
		relativeTo = archiveRoot
		relativeTo = relativeTo.substr 1 if relativeTo[0] in '/\\'.split ''
		relativeTo = relativeTo[...-1] if relativeTo[-1..] in '/\\'.split ''

		for filename in filenames
			destFilename = filename
			#destFilename = path.relative destFilename, relativeTo if relativeTo isnt '.'
			destFilename = destFilename.replace relativeTo, '' if relativeTo isnt '.'
			destFilename = path.join dest, destFilename
			#dbg console.log "filename=#{filename} relativeTo=#{relativeTo} archiveRoot=#{archiveRoot} destFilename=#{destFilename}"
			console.log "#{filename} -> #{destFilename}" if @opts.verbose
			node = @_searchNode filename, no
			if node.files
				# it's a directory, create it
				mkdirp.sync destFilename
			else
				# it's a file, extract it
				@extractFileSync filename, destFilename
		return yes

	# adds a single file to archive
	# also adds parent directories (without their files)
	# if content is not set, the file is read from disk (on this.write)
	addFile: (filename, relativeTo, stat=null, content=null) ->
		stat ?= fs.lstatSyc filename

		# JavaScript can not precisely present integers >= UINT32_MAX.
		if stat.size > 4294967295
			throw new Error "#{p}: file size can not be larger than 4.2GB"

		# this is only approximate
		# we dont take into account the size of the header
		if @_offset + stat.size > 4294967295
			throw new Error "#{p}: archive size can not be larger than 4.2GB"

		@_files.push filename

		p = path.relative relativeTo, filename
		node = @_searchNode p
		node.size = stat.size
		node.offset = @_offset.toString()
		if process.platform is 'win32' and stat.mode & 0o0100
			node.executable = true
		@_offset += stat.size
		return

	# adds a single file to archive
	# also adds parent directories (without their files)
	addSymlink: (filename, relativeTo, stat=null) ->
		stat ?= fs.lstatSyc filename

		link = path.relative(fs.realpathSync(this.src), fs.realpathSync(p));
		if link.substr(0, 2) is '..'
			throw new Error p + ': file links out of the archive'

		p = path.relative relativeTo, filename
		node = @_searchNode p
		node.size = stat.size
		node.offset = @_offset.toString()
		if process.platform is 'win32' and stat.mode & 0o0100
			node.executable = true
		@_offset += stat.size
		return

	# removes a file from archive
	#removeFile: (filename) ->

	# creates an empty directory in the archive
	createDirectory: (dirname) ->
		entry = @_searchNode dirname
		entry.files = {}
		return

	# adds a directory and it's files to archive
	# also adds parent directories (but without their files)
	addDirectory: (dirname, relativeTo, opts, cb) ->
		if typeof opts is 'function'
			cb = opts
			opts = {}
		@_crawlFilesystem dirname, opts.pattern, (err, files) =>
			for file in files
				console.log "+ #{path.sep}#{path.relative relativeTo, file.name}" if @opts.verbose
				if file.stat.isDirectory()
					@createDirectory path.relative relativeTo, file.name
				else if file.stat.isFile() or file.stat.isSymbolicLink()
					@addFile file.name, relativeTo, file.stat
				#else if file.stat.isSymbolicLink()
				#	@addSymlink file.name, relativeTo, file.stat
			return cb? null
		return

	# removes a directory and its files from archive
	#removeDirectory: (dirname) ->
