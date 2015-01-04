
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
zlib = require 'zlib'
stream = require 'stream'

walkdir = require 'walkdir'
mkdirp = require 'mkdirp'
queue = require 'queue-async'
UINT64 = require('cuint').UINT64

AsarArchiveBase = require './archive-base'

writeUINT64 = (buf, val, ofs=0) ->
	uintval = UINT64 val
	buf.writeUInt16LE uintval._a00, ofs + 0
	buf.writeUInt16LE uintval._a16, ofs + 2
	buf.writeUInt16LE uintval._a32, ofs + 4
	buf.writeUInt16LE uintval._a48, ofs + 6
	return buf

readUINT64 = (buf, ofs=0) ->
	lo = buf.readUInt32LE ofs + 0
	hi = buf.readUInt32LE ofs + 4
	val = UINT64(lo, hi).toNumber()
	return val

sortBy = (prop) -> (a, b) -> #a[prop].localeCompare b[prop] # ?
	return -1 if a[prop] < b[prop]
	return 1 if a[prop] > b[prop]
	return 0

module.exports = class AsarArchiveFs extends AsarArchiveBase
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

	_readHeader: (fd) ->
		magicLen = @MAGIC.length
		magicBuf = new Buffer magicLen
		if fs.readSync(fd, magicBuf, 0, magicLen, null) isnt magicLen
			throw new Error "Unable to open archive: #{@_archiveName}"
		if magicBuf.toString() isnt @MAGIC
			#throw new Error 'Invalid magic number'
			#console.warn 'Deprecation notice: old version of asar archive.'
			return @_readHeaderOld fd

		headerSizeOfs = @_archiveSize - (@SIZELENGTH + 16 + @SIZELENGTH) # headerSize, checksum, archiveSize
		headerSizeBuf = new Buffer @SIZELENGTH
		if fs.readSync(fd, headerSizeBuf, 0, @SIZELENGTH, headerSizeOfs) isnt @SIZELENGTH
			throw new Error "Unable to read header size: #{@_archiveName}"
		headerSize = readUINT64 headerSizeBuf

		headerOfs = @_archiveSize - headerSize - (@SIZELENGTH + 16 + @SIZELENGTH) # headerSize, checksum, archiveSize
		headerBuf = new Buffer headerSize
		if fs.readSync(fd, headerBuf, 0, headerSize, headerOfs) isnt headerSize
			throw new Error "Unable to read header: #{@_archiveName}"

		@_offset = headerOfs

		checksumSize = 16
		checksumOfs = @_archiveSize - 16 - @SIZELENGTH # checksum, archiveSize
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

		actualSize = size - 8
		headerBuf = new Buffer actualSize
		if fs.readSync(fd, headerBuf, 0, actualSize, 16) isnt actualSize
			throw new Error 'Unable to read header (assumed old format)'

		try
			# remove trailing 0's (because of padding that can occur?)
			headerStr = headerBuf.toString().replace /\0+$/g, ''
			@_header = JSON.parse headerStr
		catch err
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
		headerSizeBuf = new Buffer @SIZELENGTH
		writeUINT64 headerSizeBuf, @_headerSize
		
		out.write headerStr, =>
			out.write headerSizeBuf, =>
				archiveFile = fs.createReadStream @_archiveName
				md5 = crypto.createHash('md5')
				archiveFile.pipe md5
				archiveFile.on 'end', =>
				#md5.on 'finish', =>
					# is this really ok ???
					@_checksum = md5.read()
					@_archiveSize = @_offset + @_headerSize + @SIZELENGTH + 16 + @SIZELENGTH  
					if @_archiveSize > @MAX_SAFE_INTEGER
						return cb? new Error "archive size can not be larger than 9PB"
					archiveSizeBuf = new Buffer @SIZELENGTH
					writeUINT64 archiveSizeBuf, @_archiveSize

					out.write @_checksum, ->
						out.write archiveSizeBuf, cb
						return
					return
				return
			return
		return

	_calcArchiveChecksum: (cb) ->
		endOfs = @_offset + @_headerSize + @SIZELENGTH - 1
		archiveFile = fs.createReadStream @_archiveName,
			start: 0
			end: endOfs
		md5 = crypto.createHash('md5')
		archiveFile.pipe md5
		archiveFile.on 'error', cb
		archiveFile.on 'end', -> cb null, md5.read().toString('hex')

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
		#console.log "writing #{archiveName} ..." if @opts.verbose
		appendMode = @_archiveName is archiveName
		@_archiveName = archiveName

		# create output dir if necessary
		mkdirp.sync path.dirname archiveName

		writeFile = (filename, out, internalFilename, node, cb) =>
			console.log "+ #{path.sep}#{internalFilename}" if @opts.verbose

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
				q.defer writeFile, file, out, @_filesInternalName[i], @_fileNodes[i]
			q.awaitAll (err) =>
				return cb? err if err
				@_writeFooter out, (err) ->
					return cb err if err
					@_dirty = no
					@_files = []
					@_filesInternalName = []
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

	extractFile: (filename, destFilename, cb) => #=>
		console.log "-> #{destFilename}" if @opts.verbose
		inStream = @createReadStream filename

		out = fs.createWriteStream destFilename
		out.on 'finish', cb
		out.on 'error', cb

		inStream.pipe out
		return

	extractSymlink: (filename, destFilename, cb) =>
		destDir = path.dirname destFilename
		mkdirp.sync destDir

		linkTo = path.join destDir, relativeTo, node.link
		linkToRel = path.relative path.dirname(destFilename), linkTo

		# try to delete output file first, because we can't overwrite a link
		try fs.unlinkSync destFilename
		fs.symlinkSync linkToRel, destFilename
		return cb null
	#extractDirectory: -> (filename, destFilename, cb) ->
