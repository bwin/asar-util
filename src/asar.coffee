
AsarArchive = require './archive'
serialization = require './serialization'

opts = {}

# create an archive
# if srcDir is set: add dirs/files from srcDir
# if archiveFilename is set: write archive to disk
createArchive = (srcDir, archiveFilename, pattern, cb) ->
	if typeof pattern is 'function'
		cb = pattern
		pattern = null
	archive = new AsarArchive opts
	if srcDir?
		archive.addDirectory srcDir, {pattern}, (err) ->
			if archiveFilename?
				archive.write archiveFilename, (err) ->
					return cb err, archive
	return

# load an archive from disk
loadArchive = (archiveFilename) ->
	archive = new AsarArchive opts
	return serialization.loadArchive archive, archiveFilename

verifyArchive = (archiveFilename, cb) ->
	loadArchive(archiveFilename).verify cb
	return

# retrieves a list of entries (dirs, files) in archive:/archiveRoot
getEntries = (archiveFilename, archiveRoot='/', pattern=null)->
	return loadArchive(archiveFilename).getEntries archiveRoot, pattern

# extract archive:/archiveRoot
#extractArchiveSync = (archiveFilename, destDir, archiveRoot='/', pattern=null) ->
#	return loadArchive(archiveFilename).extractSync destDir, archiveRoot, pattern

# extract archive:/archiveRoot
extractArchive = (archiveFilename, destDir, opts, cb) ->
	loadArchive(archiveFilename).extract destDir, opts, cb
	return

createReadStream = (archiveFilename, filename) ->
	return loadArchive(archiveFilename).createReadStream filename

module.exports = {
	AsarArchive
	createArchive
	loadArchive
	verifyArchive
	getEntries
	#extractArchiveSync
	extractArchive
	createReadStream
	opts
}