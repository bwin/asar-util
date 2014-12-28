
AsarArchive = require './archive'

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
		archive.addDirectory srcDir, srcDir, {pattern}, (err) ->
			if archiveFilename?
				archive.write archiveFilename, {}, (err) ->
					return cb err, archive
	return

# load an archive from disk
loadArchive = (archiveFilename) ->
	archive = new AsarArchive opts
	archive.openSync archiveFilename
	return archive

# retrieves a list of entries (dirs, files) in archive:/archiveRoot
getEntries = (archiveFilename, archiveRoot='/', pattern=null)->
	archive = loadArchive archiveFilename
	list = archive.getEntries archiveRoot, pattern
	return list

# extract archive:/archiveRoot
extractArchive = (archiveFilename, destDir, archiveRoot='/', pattern=null) ->
	archive = loadArchive archiveFilename
	archive.extractSync destDir, archiveRoot, pattern
	return

module.exports = {
	AsarArchive
	createArchive
	loadArchive
	getEntries
	extractArchive
	opts
}