
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
zlib = require 'zlib'

mkdirp = require 'mkdirp'
queue = require 'queue-async'
UINT64 = require('cuint').UINT64

MAX_SAFE_INTEGER = 9007199254740992

writeUINT64 = (buf, val, ofs=0) ->
	uintval = UINT64 val
	buf.writeUInt16LE uintval._a00, ofs + 0
	buf.writeUInt16LE uintval._a16, ofs + 2
	buf.writeUInt16LE uintval._a32, ofs + 4
	buf.writeUInt16LE uintval._a48, ofs + 6
	#console.log "UINT64-conv-write:", val, buf
	return buf

readUINT64 = (buf, ofs=0) ->
	lo = buf.readUInt32LE ofs + 0
	hi = buf.readUInt32LE ofs + 4
	val = UINT64(lo, hi).toNumber()
	#console.log "UINT64-conv-read:", val, buf
	return val

readHeader = (archive, fd) ->
	magicLen = archive.MAGIC.length
	magicBuf = new Buffer magicLen
	if fs.readSync(fd, magicBuf, 0, magicLen, null) isnt magicLen
		throw new Error "Unable to open archive: #{archive._archiveName}"
	if magicBuf.toString() isnt archive.MAGIC
		#throw new Error 'Invalid magic number'
		#console.warn 'Deprecation notice: old version of asar archive.'
		return readHeaderOld archive, fd

	headerSizeOfs = archive._archiveSize - (archive.SIZELENGTH + 16 + archive.SIZELENGTH) # headerSize, checksum, archiveSize
	headerSizeBuf = new Buffer archive.SIZELENGTH
	if fs.readSync(fd, headerSizeBuf, 0, archive.SIZELENGTH, headerSizeOfs) isnt archive.SIZELENGTH
		throw new Error "Unable to read header size: #{archive._archiveName}"
	headerSize = readUINT64 headerSizeBuf

	headerOfs = archive._archiveSize - headerSize - (archive.SIZELENGTH + 16 + archive.SIZELENGTH) # headerSize, checksum, archiveSize
	headerBuf = new Buffer headerSize
	if fs.readSync(fd, headerBuf, 0, headerSize, headerOfs) isnt headerSize
		throw new Error "Unable to read header: #{archive._archiveName}"

	archive._offset = headerOfs

	checksumSize = 16
	checksumOfs = archive._archiveSize - 16 - archive.SIZELENGTH # checksum, archiveSize
	archive._checksum = new Buffer checksumSize
	if fs.readSync(fd, archive._checksum, 0, checksumSize, checksumOfs) isnt checksumSize
		throw new Error "Unable to read checksum: #{archive._archiveName}"

	try
		archive._header = JSON.parse headerBuf
	catch err
		throw new Error "Unable to parse header: #{archive._archiveName}"
	archive._headerSize = headerSize
	return

readHeaderOld = (archive, fd) ->
	archive._legacyMode = yes

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
		archive._header = JSON.parse headerStr
	catch err
		throw new Error 'Unable to parse header (assumed old format)'
	archive._headerSize = size
	return

writeHeader = (archive, out, cb) ->
	out.write archive.MAGIC, cb
	return

writeFooter = (archive, out, cb) ->
	if archive.opts.prettyToc
		headerStr = JSON.stringify(archive._header, null, '  ').replace /\n/g, '\r\n'
		headerStr = "\r\n#{headerStr}\r\n"
	else
		headerStr = JSON.stringify archive._header

	archive._headerSize = headerStr.length
	headerSizeBuf = new Buffer archive.SIZELENGTH
	writeUINT64 headerSizeBuf, archive._headerSize
	
	out.write headerStr, ->
		out.write headerSizeBuf, ->
			archiveFile = fs.createReadStream archive._archiveName
			md5 = crypto.createHash('md5')
			archiveFile.pipe md5
			archiveFile.on 'end', ->
			#md5.on 'finish', ->
				# is this really ok ???
				archive._checksum = md5.read()
				archive._archiveSize = archive._offset + archive._headerSize + archive.SIZELENGTH + 16 + archive.SIZELENGTH  
				if archive._archiveSize > MAX_SAFE_INTEGER
					return cb? new Error "archive size can not be larger than 9PB"
				archiveSizeBuf = new Buffer archive.SIZELENGTH
				writeUINT64 archiveSizeBuf, archive._archiveSize

				out.write archive._checksum, ->
					out.write archiveSizeBuf, cb
					return
				return
			return
		return
	return

# opens an asar archive from disk
#open: (archiveName, cb) ->
openSync = (archive, archiveName) ->
	archive.reset()
	archive._archiveName = archiveName

	try
		archive._archiveSize = fs.lstatSync(archiveName).size
		fd = fs.openSync archiveName, 'r'
		readHeader archive, fd
	catch err
		throw err
	fs.closeSync fd

	if archive._header.version? and archive._header.version > archive.VERSION
		throw new Error "Unsupported asar format version: #{archive._header.version} (max supported: #{archive.VERSION})"

	return yes

# saves an asar archive to disk
saveArchive = (archive, archiveName, opts, cb) ->
	# make opts optional
	if typeof opts is 'function'
		cb = opts
		opts = {}
	appendMode = archive._archiveName is archiveName
	archive._archiveName = archiveName

	# create output dir if necessary
	mkdirp.sync path.dirname archiveName

	writeFile = (filename, out, node, cb) ->
		realSize = 0
		src = fs.createReadStream filename
		
		if archive.opts.compress and node.size > archive.opts.minSizeToCompress
			gzip = zlib.createGzip()
			gzip.on 'data', (chunk) ->
				realSize += chunk.length
				return
			gzip.on 'end', ->
				node.offset = archive._offset
				node.csize = realSize
				archive._offset += realSize
				cb()
				return
			src.pipe gzip
			gzip.pipe out, end: no
		else
			src.on 'data', (chunk) ->
				realSize += chunk.length
				return
			src.on 'end', ->
				node.offset = archive._offset
				archive._offset += realSize
				cb()
				return
			src.pipe out, end: no
		return

	writeArchive = (err, cb) ->
		return cb? err if err
		q = queue 1
		for file, i in archive._files
			q.defer writeFile, file, out, archive._fileNodes[i]
		q.awaitAll (err) ->
			return cb? err if err
			writeFooter archive, out, (err) ->
				return cb err if err
				archive._dirty = no
				archive._files = []
				archive._fileNodes = []
				cb()
		return
	
	start = if appendMode then archive._offset else 0
	if appendMode
		out = fs.createWriteStream archiveName, flags: 'r+', start: start
		writeArchive null, cb
	else
		out = fs.createWriteStream archiveName
		writeHeader archive, out, (err) -> writeArchive err, cb
	return

module.exports =
	loadArchive: (archive, archiveName) ->
		openSync archive, archiveName
		return archive

	saveArchive: (archive, archiveName, cb) ->
		saveArchive archive, archiveName, cb
		return

	MAX_SAFE_INTEGER: MAX_SAFE_INTEGER