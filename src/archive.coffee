
fs = require 'fs'
#os = require 'os'
path = require 'path'

mkdirp = require 'mkdirp'
queue = require 'queue-async'

AsarArchiveFs = require './archive-fs'

module.exports = class AsarArchive extends AsarArchiveFs
	verify: (cb) ->
		# TODO also check file size
		@_calcArchiveChecksum (err, checksum) =>
			expected = @_checksum.toString('hex')
			cb null, checksum is expected, {checksum, expected}
		return
		
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
		#symlinksSupported = os.platform() isnt 'win32'

		filenames = @getEntries archiveRoot, pattern
		if filenames.length is 1
			archiveRoot = path.dirname archiveRoot
		#else
		#	mkdirp.sync dest # create destination directory

		relativeTo = archiveRoot
		relativeTo = relativeTo.substr 1 if relativeTo[0] in '/\\'.split ''
		relativeTo = relativeTo[...-1] if relativeTo[-1..] in '/\\'.split ''

		q = queue 1
		for filename in filenames
			destFilename = filename
			destFilename = destFilename.replace relativeTo, '' if relativeTo isnt '.'
			destFilename = path.join dest, destFilename

			destDir = path.dirname destFilename

			node = @_searchNode filename, no
			if node.files
				q.defer mkdirp, destFilename
			else
				q.defer mkdirp, destDir
				if node.link
					q.defer @extractSymlink, filename, destFilename
				else
					q.defer @extractFile, filename, destFilename

		q.awaitAll cb
		return

	# adds a directory and it's files to archive
	# also adds parent directories (but without their files)
	addDirectory: (dirname, opts={}, cb=null) ->
		@_dirty = yes
		if typeof opts is 'function'
			cb = opts
			opts = {}
		relativeTo = opts.relativeTo or dirname
		@_crawlFilesystem dirname, opts?.pattern, (err, files) =>
			for file in files
				#console.log "+ #{path.sep}#{path.relative relativeTo, file.name}" if @opts.verbose
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
