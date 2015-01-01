
fs = require 'fs'
os = require 'os'
path = require 'path'
crypto = require 'crypto'
stream = require 'stream'
zlib = require 'zlib'

walkdir = require 'walkdir'
minimatch = require 'minimatch'
mkdirp = require 'mkdirp'
queue = require 'queue-async'

sortBy = (prop) -> (a, b) ->
	return -1 if a[prop] < b[prop]
	return 1 if a[prop] > b[prop]
	return 0

module.exports = class AsarArchive
	MAGIC: 'ASAR\r\n'
	VERSION: 1

	constructor: (@opts={}) ->
		# default options
		@opts.minSizeToCompress ?= 256

		@reset()
		return

	reset: ->
		@_header =
			version: @VERSION
			files: {}
		@_headerSize = 0
		@_offset = @MAGIC.length #0
		@_archiveSize = 0
		@_files = []
		@_fileNodes = []
		@_archiveName = null
		@_dirty = no
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

		@_offset = headerOfs

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
			#console.log "header:'#{x}'",err
			throw new Error 'Unable to parse header (assumed old format)'
		@_headerSize = size
		return

	_writeHeader: (out, cb) ->
		out.write @MAGIC, cb
		return

	_writeFooter: (out, cb) ->
		if @opts.prettyToc
			headerStr = JSON.stringify(@_header, null, '  ').replace /\n/g, '\r\n'
			headerStr = "\r\n#{headerStr}\r\n"
		else
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
				#md5.on 'finish', =>
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
		# make opts optional
		if typeof opts is 'function'
			cb = opts
			opts = {}
		appendMode = @_archiveName is archiveName
		@_archiveName = archiveName

		# create output dir if necessary
		mkdirp.sync path.dirname archiveName

		writeFile = (filename, out, node, cb) =>
			realSize = 0
			src = fs.createReadStream filename
			
			if @opts.compress and node.size > @opts.minSizeToCompress
				gzip = zlib.createGzip()
				gzip.on 'data', (chunk) ->
					realSize += chunk.length
					return
				gzip.on 'end', =>
					node.offset = @_offset
					node.csize = realSize
					@_offset += realSize
					cb()
					return
				src.pipe gzip
				gzip.pipe out, end: no
			else
				src.on 'data', (chunk) ->
					realSize += chunk.length
					return
				src.on 'end', =>
					node.offset = @_offset
					@_offset += realSize
					cb()
					return
				src.pipe out, end: no
			return

		writeArchive = (err, cb) =>
			return cb? err if err
			q = queue 1
			for file, i in @_files
				q.defer writeFile, file, out, @_fileNodes[i]
			q.awaitAll (err) =>
				return cb? err if err
				@_writeFooter out, (err) ->
					return cb err if err
					@_dirty = no
					@_files = []
					@_fileNodes = []
					cb()
			return
		
		start = if appendMode then @_offset else 0
		if appendMode
			out = fs.createWriteStream archiveName, flags: 'r+', start: start
			writeArchive null, cb
		else
			out = fs.createWriteStream archiveName
			@_writeHeader out, (err) -> writeArchive err, cb
		return

	verify: (cb) ->
		endOfs = @_offset + @_headerSize + 4 - 1
		archiveFile = fs.createReadStream @_archiveName,
			start: 0
			end: endOfs
		md5 = crypto.createHash('md5')
		archiveFile.pipe md5
		archiveFile.on 'end', =>
			actual = md5.read().toString('hex')
			excpected = @_checksum.toString('hex')
			cb null, actual is excpected, {actual, excpected}
			return
		return

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

	# shouldn't be public (but it for now because of cli -ls)
	getMetadata: (filename) ->
		node = @_searchNode filename, no
		return node

	# !!! ...
	createReadStream: (filename) ->
		node = @_searchNode filename, no
		if node.size > 0
			unless @_legacyMode
				start = node.offset
			else
				start = 8 + @_headerSize + parseInt node.offset, 10
			size = node.csize or node.size
			end = start + size - 1
			inStream = fs.createReadStream @_archiveName, start: start, end: end

			if node.csize?
				gunzip = zlib.createGunzip()
				inStream.pipe gunzip
				return gunzip

			return inStream
		else
			emptyStream = stream.Readable()
			emptyStream.push null
			return emptyStream
		
	# !!! ...
	# opts can be string or object
	# extract('dest', 'filename', cb) can be used to extract a single file
	extract: (dest, opts, cb) ->
		# make opts optional
		if typeof opts is 'function'
			cb = opts
			opts = {}
		opts = root: opts if typeof opts is 'string'
		# init default opts
		archiveRoot = opts.root or '/'
		pattern = opts.pattern
		symlinksSupported = os.platform() isnt 'win32'

		filenames = @getEntries archiveRoot, pattern
		if filenames.length is 1
			archiveRoot = path.dirname archiveRoot
		else
			mkdirp.sync dest # create destination directory

		relativeTo = archiveRoot
		relativeTo = relativeTo.substr 1 if relativeTo[0] in '/\\'.split ''
		relativeTo = relativeTo[...-1] if relativeTo[-1..] in '/\\'.split ''

		writeStreamToFile = (filename, destFilename, cb) =>
			inStream = @createReadStream filename

			out = fs.createWriteStream destFilename
			out.on 'finish', cb
			out.on 'error', cb

			inStream.pipe out
			return

		q = queue 1
		for filename in filenames
			destFilename = filename
			destFilename = destFilename.replace relativeTo, '' if relativeTo isnt '.'
			destFilename = path.join dest, destFilename
			#console.log "#{filename} -> #{destFilename}" if @opts.verbose
			console.log "-> #{destFilename}" if @opts.verbose

			node = @_searchNode filename, no
			if node.files
				q.defer mkdirp, destFilename
			else if node.link
				if symlinksSupported
					destDir = path.dirname destFilename
					q.defer mkdirp, destDir

					linkTo = path.join destDir, relativeTo, node.link
					linkToRel = path.relative path.dirname(destFilename), linkTo

					# try to delete output file first, because we can't overwrite a link
					try fs.unlinkSync destFilename
					fs.symlinkSync linkToRel, destFilename
				else
					console.log "Warning: extracting symlinks on windows not yet supported. Skipping #{destFilename}" if @opts.verbose
					# TODO
			else
				destDir = path.dirname destFilename
				q.defer mkdirp, destDir
				q.defer writeStreamToFile, filename, destFilename

		q.awaitAll cb
		return

	# adds a single file to archive
	# also adds parent directories (without their files)
	# if content is not set, the file is read from disk (on this.write)
	addFile: (filename, opts={}) ->
		stat = opts.stat or fs.lstatSyc filename
		relativeTo = opts.relativeTo or path.dirname filename
		
		@_dirty = yes

		# JavaScript can not precisely present integers >= UINT32_MAX.
		if stat.size > 4294967295
			throw new Error "#{p}: file size can not be larger than 4.2GB"

		# this is only approximate
		# we dont take into account the size of the header
		#if @_offset + stat.size > 4294967295
		#	throw new Error "#{p}: archive size can not be larger than 4.2GB"

		p = path.relative relativeTo, filename
		node = @_searchNode p
		node.size = stat.size
		#node.offset = @_offset.toString()
		
		return if node.size is 0

		@_files.push filename
		@_fileNodes.push node
		
		if process.platform is 'win32' and stat.mode & 0o0100
			node.executable = true
		return

	# adds a single file to archive
	# also adds parent directories (without their files)
	addSymlink: (filename, opts={}) ->
		relativeTo = opts.relativeTo or path.dirname filename
		
		@_dirty = yes
		
		p = path.relative relativeTo, filename
		pDir = path.dirname path.join relativeTo, p
		pAbsDir = path.resolve pDir
		linkAbsolute = fs.realpathSync filename
		linkTo = path.relative pAbsDir, linkAbsolute

		node = @_searchNode p
		node.link = linkTo
		return

	# removes a file from archive
	#removeFile: (filename) ->

	# creates an empty directory in the archive
	createDirectory: (dirname) ->
		@_dirty = yes
		entry = @_searchNode dirname
		entry.files = {}
		return

	# adds a directory and it's files to archive
	# also adds parent directories (but without their files)
	addDirectory: (dirname, opts, cb) ->
		@_dirty = yes
		if typeof opts is 'function'
			cb = opts
			opts = {}
		relativeTo = opts.relativeTo or dirname
		@_crawlFilesystem dirname, opts?.pattern, (err, files) =>
			for file in files
				console.log "+ #{path.sep}#{path.relative relativeTo, file.name}" if @opts.verbose
				if file.stat.isDirectory()
					@createDirectory path.relative relativeTo, file.name
				else if file.stat.isFile()
					@addFile file.name,
						relativeTo: relativeTo
						stat: file.stat
				else if file.stat.isSymbolicLink()
					@addSymlink file.name, relativeTo: relativeTo
			return cb? null
		return

	# removes a directory and its files from archive
	#removeDirectory: (dirname) ->