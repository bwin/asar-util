
AsarArchive = require './archive'

# create an archive
# if srcDir is set: add dirs/files from srcDir
# if destFile is set: write archive to destFile
createArchive = (srcDir, destFile, cb) ->
	archive = new AsarArchive()
	if srcDir?
		archive.addDirectory srcDir, srcDir, (err) ->
			if destFile?
				archive.write destFile, {}, (err) ->
					return cb err, archive
	return

# load an archive from disk
loadArchive = (archiveFilename) ->
	archive = new AsarArchive()
	archive.openSync archiveFilename
	return archive

# retrieves a list of all entries (dirs, files) in archive
getEntries = (archiveFilename, archiveRoot='/')->
	archive = loadArchive archiveFilename
	list = archive.getEntries archiveRoot
	return list

# extract an archive
extractArchive = (archiveFilename, destDir) ->
	archive = loadArchive archiveFilename
	archive.extractSync destDir
	return

# extract a file from archive
extractFileFromArchive = (archiveFilename, filename, destFilename) ->
	archive = loadArchive archiveFilename
	archive.extractFileSync filename, destFilename
	return

# extract a directory and its files from archive
extractDirectoryFromArchive = (archiveFilename, dirname, destDir) ->
	archive = loadArchive archiveFilename
	archive.extractSync destDir, dirname
	return

module.exports = {
	AsarArchive
	createArchive
	loadArchive
	getEntries
	extractArchive
	extractFileFromArchive
	extractDirectoryFromArchive
}