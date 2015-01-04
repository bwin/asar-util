
fs = require 'fs'
path = require 'path'

minimatch = require 'minimatch'

module.exports = class AsarArchiveBase
	MAGIC: 'ASAR\r\n'
	VERSION: 1
	SIZELENGTH: 64 / 8
	MAX_SAFE_INTEGER: 9007199254740992

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
		@_offset = @MAGIC.length
		@_archiveSize = 0
		@_files = []
		@_filesInternalName = []
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
		return node if p is ''
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

	# retrieves a list of all entries (dirs, files) in archive
	getEntries: (archiveRoot='/', pattern=null) ->
		archiveRoot = archiveRoot.substr 1 if archiveRoot.length > 1 and archiveRoot[0] in '/\\'.split '' # get rid of leading slash
		files = []
		fillFilesFromHeader = (p, node) ->
			return unless node?.files?
			for f of node.files
				fullPath = path.join p, f
				files.push fullPath
				fillFilesFromHeader fullPath, node.files[f]
			return

		node = @_searchNode archiveRoot, no
		throw new Error "#{archiveRoot} not found in #{@_archiveName}" unless node?
		files.push archiveRoot if node.size
		archiveRoot = "#{path.sep}#{archiveRoot}"

		fillFilesFromHeader archiveRoot, node

		files = files.filter minimatch.filter pattern, matchBase: yes if pattern

		return files
	###
		or addHelp = (msg, fn) -> fn.help = (-> console.log msg); fn
	###

	# shouldn't be public (but it for now because of cli -ls)
	getMetadata: (filename) ->
		node = @_searchNode filename, no
		return node
	
	# adds a single file to archive
	# also adds parent directories (without their files)
	# if content is not set, the file is read from disk (on this.write)
	addFile: (filename, opts={}) ->
		stat = opts.stat or fs.lstatSyc filename
		relativeTo = opts.relativeTo or path.dirname filename
		
		@_dirty = yes

		# JavaScript can not precisely present integers >= UINT32_MAX.
		if stat.size > @MAX_SAFE_INTEGER
			throw new Error "#{p}: file size can not be larger than 9PB"

		p = path.relative relativeTo, filename
		node = @_searchNode p
		node.size = stat.size
		#node.offset = @_offset.toString()
		
		return if node.size is 0

		@_files.push filename
		@_filesInternalName.push p
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
		entry.files ?= {}
		return

	# removes a directory and its files from archive
	#removeDirectory: (dirname) ->