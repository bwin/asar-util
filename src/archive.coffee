
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'

walkdir = require 'walkdir'
mkdirp = require 'mkdirp'
pickle = require 'chromium-pickle'
UINT64 = require('cuint').UINT64

crawlFilesystem = (dir, cb) ->
	# cb: (err, paths, metadata)
	paths = []
	metadata = {}

	emitter = walkdir dir
	emitter.on 'directory', (p, stat) ->
		paths.push p
		metadata[p] =
			type: 'directory'
			stat: stat
		return
	emitter.on 'file', (p, stat) ->
		paths.push p
		metadata[p] =
			type: 'file'
			stat: stat
		return
	emitter.on 'link', (p, stat) ->
		paths.push p
		metadata[p] =
			type: 'link'
			stat: stat
		return
	emitter.on 'end', ->
		paths.sort()
		return cb null, paths, metadata
	emitter.on 'error', cb
	return

#md5 = (str) -> return crypto.createHash('md5').update(str)#.digest("hex")

module.exports = class AsarArchive
	constructor: ->
		@reset()
		return

	MAGIC: 'ASAR'
	VERSION: 1

	reset: ->
		@_header =
			version: @VERSION
			files: {}
		@_headerSize = 0
		@_offset = UINT64 0
		@_files = []
		@_archiveName = null
		return

	_searchNode: (p, create=yes) ->
		#console.log "_searchNode", p
		p = p.substr 1 if p[0] is path.sep # get rid of leading slash
		name = path.basename p
		node = @_header
		dirs = path.dirname(p).split path.sep
		for dir in dirs
			throw new Error "#{p} not found." unless node?
			node = node.files[dir] if dir isnt '.'
		node.files[name] = {} if create
		throw new Error "#{p} not found." unless node?
		node = node.files[name]
		return node

	_readHeader: (fd) ->
		magicLen = @MAGIC.length
		magicBuf = new Buffer magicLen
		if fs.readSync(fd, magicBuf, 0, magicLen, null) isnt magicLen
			throw new Error 'Unable to read from archive'
		if magicBuf.toString() isnt @MAGIC
			#throw new Error 'Invalid magic number'
			console.error 'Deprecation notice: old version of asar archive.'
			return @_readHeaderOld fd

		sizeBufSize = 4
		sizeBuf = new Buffer sizeBufSize
		if fs.readSync(fd, sizeBuf, 0, sizeBufSize, null) isnt sizeBufSize
			throw new Error 'Unable to read header size'
		size = sizeBuf.readUInt32BE 0

		headerBuf = new Buffer size
		if fs.readSync(fd, headerBuf, 0, size, null) isnt size
			throw new Error 'Unable to read header'

		headerStr = headerBuf.toString()

		return [headerBuf, size]

	_readHeaderOld: (fd) ->
		sizeBufSize = 8
		sizeBuf = new Buffer sizeBufSize
		if fs.readSync(fd, sizeBuf, 0, sizeBufSize, 0) isnt sizeBufSize
			throw new Error 'Unable to read header size'
		sizePickle = pickle.createFromBuffer sizeBuf
		size = sizePickle.createIterator().readUInt32()

		headerBuf = new Buffer size
		if fs.readSync(fd, headerBuf, 0, size, null) isnt size
			throw new Error 'Unable to read header'

		headerPickle = pickle.createFromBuffer headerBuf
		headerStr = headerPickle.createIterator().readString()

		return [headerStr, size]

	_writeHeader: (out, cb) ->
		headerStr = JSON.stringify @_header

		sizeBuf = new Buffer 4
		sizeBuf.writeUInt32BE headerStr.length, 0

		out.write @MAGIC, ->
			out.write sizeBuf, ->
				out.write headerStr, cb
		return

	# opens an asar archive from disk
	#open: (archiveName, cb) ->
	openSync: (archiveName) ->
		@reset()
		@_archiveName = archiveName

		fd = fs.openSync archiveName, 'r'
		[headerStr, size] = @_readHeader fd
		fs.closeSync fd

		@_header = JSON.parse headerStr
		@_headerSize = size

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
				q.awaitAll (err) ->
					return cb err
			return
		return
	#writeSync: (archiveName) ->
	#	return

	# retrieves a list of all entries (dirs, files) in archive
	getEntries: (archiveRoot='/')->
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
			archiveRoot = "#{path.sep}#{archiveRoot}"

		fillFilesFromHeader archiveRoot, json
		return files

	# !!! ...
	getMetadata: (filename) ->
		node = @_searchNode filename, no
		return node

	# !!! ...
	getFile: (filename) ->
		fd = fs.openSync @_archiveName, 'r'
		node = @_searchNode filename, no
		buffer = new Buffer node.size
		fs.readSync fd, buffer, 0, node.size, 8 + @_headerSize + parseInt(node.offset, 10)
		fs.closeSync fd
		return buffer
	
	# !!! ...
	extractFileSync: (filename, destFilename) ->
		mkdirp.sync path.dirname destFilename
		fs.writeFileSync destFilename, @getFile filename
		return yes
		
	# !!! ...
	extractSync: (destDir, archiveRoot='/') ->
		mkdirp.sync destDir # create destination directory
		filenames = @getEntries archiveRoot

		for filename in filenames
			destFilename = path.join destDir, filename
			node = @_searchNode filename, no
			if node.files
				# it's a directory, create it and continue with the next entry
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

		@_files.push filename

		p = path.relative relativeTo, filename
		node = @_searchNode p
		node.size = stat.size
		node.offset = @_offset.toString()
		if process.platform is 'win32' and stat.mode & 0o0100
			node.executable = true
		@_offset.add UINT64 stat.size
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
	addDirectory: (dirname, relativeTo, cb) ->
		crawlFilesystem dirname, (err, filenames, metadata) =>
			for filename in filenames
				file = metadata[filename]
				if file.type is 'directory'
					@createDirectory path.relative relativeTo, filename
				else if file.type is 'file'
					@addFile filename, relativeTo, file.stat
				#else if file.type is 'link'
					#filesystem.insertLink(filename, file.stat);
			return cb null
		return

	# removes a directory and its files from archive
	#removeDirectory: (dirname) ->
