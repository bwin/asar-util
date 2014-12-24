
AsarArchive = require './archive'

# create an archive
# if srcDir is set: add dirs/files from srcDir
# if archiveFilename is set: write archive to disk
createArchive = (srcDir, archiveFilename, cb) ->
	archive = new AsarArchive()
	if srcDir?
		archive.addDirectory srcDir, srcDir, (err) ->
			if archiveFilename?
				archive.write archiveFilename, {}, (err) ->
					return cb err, archive
	return

# load an archive from disk
loadArchive = (archiveFilename) ->
	archive = new AsarArchive()
	archive.openSync archiveFilename
	return archive

# retrieves a list of entries (dirs, files) in archive:/archiveRoot
getEntries = (archiveFilename, archiveRoot='/')->
	archive = loadArchive archiveFilename
	list = archive.getEntries archiveRoot
	return list

# extract archive:/archiveRoot
extractArchive = (archiveFilename, destDir, archiveRoot='/') ->
	archive = loadArchive archiveFilename
	archive.extractSync destDir, archiveRoot
	return

module.exports = {
	AsarArchive
	createArchive
	loadArchive
	getEntries
	extractArchive
}