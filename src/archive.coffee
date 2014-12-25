
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'

walkdir = require 'walkdir'
mkdirp = require 'mkdirp'

crawlFilesystem = (dir, cb) ->
	# cb: (err, paths)
	paths = []

	walker = walkdir dir
	walker.on 'path', (p, stat) ->
		paths.push
			name: p
			stat: stat
		return
	walker.on 'end', ->
		paths.sort (a, b) ->
			return -1 if a.name < b.name
			return 1 if a.name > b.name
			return 0
		return cb null, paths
	walker.on 'error', cb
	return

module.exports = class AsarArchive
	constructor: (@opts) ->
		@reset()
		return

	MAGIC: 'ASAR'
	VERSION: 1

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
		#console.log "_searchNode", p
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
			#console.warn 'Deprecation notice: old version of asar archive.'
			return @_readHeaderOld fd

		sizeBufSize = 4
		sizeBuf = new Buffer sizeBufSize
		if fs.readSync(fd, sizeBuf, 0, sizeBufSize, null) isnt sizeBufSize
			throw new Error 'Unable to read header size'
		size = sizeBuf.readUInt32LE 0

		headerBuf = new Buffer size
		if fs.readSync(fd, headerBuf, 0, size, null) isnt size
			throw new Error 'Unable to read header'

		checksumSize = 16
		@_checksum = new Buffer checksumSize
		if fs.readSync(fd, @_checksum, 0, checksumSize, @_archiveSize - 16 - 4) isnt checksumSize
			throw new Error 'Unable to read checksum'

		try
			@_header = JSON.parse headerBuf
		catch err
			throw new Error 'Unable to parse header'
		@_headerSize = size
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
			@_header = JSON.parse headerBuf
		catch err
			throw new Error 'Unable to parse header (assumed old format)'
		@_headerSize = size
		return

	_writeHeader: (out, cb) ->
		headerStr = JSON.stringify @_header

		@_headerSize = headerStr.length
		sizeBuf = new Buffer 4
		sizeBuf.writeUInt32LE @_headerSize, 0

		out.write @MAGIC, ->
			out.write sizeBuf, ->
				out.write headerStr, cb
		return

	_writeFooter: (out, cb) ->
		archiveFile = fs.createReadStream @_archiveName
		archiveFile.on 'readable', =>
			md5 = crypto.createHash('md5')
			archiveFile.pipe md5
			md5.on 'readable', =>
				@_checksum = md5.read()
				@_archiveSize = 8 + @_headerSize + @_offset + 16 + 4  
				if @_archiveSize > 4294967295 # because of js precision limit
					return cb new Error "archive size can not be larger than 4.2GB"
				sizeBuf = new Buffer 4
				sizeBuf.writeUInt32LE @_archiveSize, 0

				out.write @_checksum, ->
					out.write sizeBuf, cb
					return
				return
			return
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
					return cb err if err
					@_writeFooter out, cb
					
			return
		return
	#writeSync: (archiveName) ->
	#	return

	# retrieves a list of all entries (dirs, files) in archive
	getEntries: (archiveRoot='/')->
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
		fs.readSync fd, buffer, 0, node.size, 8 + @_headerSize + parseInt node.offset, 10
		fs.closeSync fd
		return buffer
	
	# !!! ...
	extractFileSync: (filename, destFilename) ->
		mkdirp.sync path.dirname destFilename
		fs.writeFileSync destFilename, @getFile filename
		return yes
		
	# !!! ...
	extractSync: (dest, archiveRoot='/') ->
		filenames = @getEntries archiveRoot
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
		crawlFilesystem dirname, (err, files) =>
			for file in files
				console.log "+ #{path.sep}#{path.relative relativeTo, file.name}" if @opts.verbose
				if file.stat.isDirectory()
					@createDirectory path.relative relativeTo, file.name
				else if file.stat.isFile()
					@addFile file.name, relativeTo, file.stat
				#else if file.stat.isLink()
					#filesystem.insertLink(file.name, file.stat);
			return cb null
		return

	# removes a directory and its files from archive
	#removeDirectory: (dirname) ->
