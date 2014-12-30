
assert = require 'assert'
fs = require 'fs'
os = require 'os'

streamEqual = require 'stream-equal'

asar = require '../lib/asar'
compDirs = require './util/compareDirectories'

#asar.opts.verbose = yes

describe 'api:', ->
	@timeout 1000*60 * 1 # minutes

	it 'should create archive from directory', (done) ->
		asar.createArchive 'test/input/packthis/', 'tmp/packthis-api.asar', (err) ->
			actual = fs.readFileSync 'tmp/packthis-api.asar', 'utf8'
			expected = fs.readFileSync 'test/expected/packthis.asar', 'utf8'
			return done assert.equal actual, expected
		return

	it 'should list files/dirs in archive', ->
		archive = asar.loadArchive 'test/input/extractthis.asar'
		actual = archive.getEntries().join '\n'
		expected = fs.readFileSync 'test/expected/extractthis-filelist.txt', 'utf8'
		# on windows replace slashes with backslashes and crlf with lf
		if os.platform() is 'win32'
			expected = expected.replace(/\//g, '\\').replace(/\r\n/g, '\n')
		return assert.equal actual, expected

	it 'should list files/dirs for directories in archive', ->
		archive = asar.loadArchive 'test/input/extractthis.asar'
		actual = archive.getEntries('dir2').join '\n'
		expected = fs.readFileSync 'test/expected/extractthis-filelist-dir2.txt', 'utf8'
		# on windows replace slashes with backslashes and crlf with lf
		if os.platform() is 'win32'
			expected = expected.replace(/\//g, '\\').replace(/\r\n/g, '\n')
		return assert.equal actual, expected

	it 'should list files/dirs for pattern in archive', ->
		archive = asar.loadArchive 'test/input/extractthis.asar'
		actual = archive.getEntries('/', '*.txt').join '\n'
		expected = fs.readFileSync 'test/expected/extractthis-filelist-txt-only.txt', 'utf8'
		# on windows replace slashes with backslashes and crlf with lf
		if os.platform() is 'win32'
			expected = expected.replace(/\//g, '\\').replace(/\r\n/g, '\n')
		return assert.equal actual, expected

	it 'should stream a text file from archive', (done) ->
		actual = asar.createReadStream 'test/input/extractthis.asar', 'dir1/file1.txt'
		expected = fs.createReadStream 'test/expected/extractthis/dir1/file1.txt', 'utf8'
		streamEqual actual, expected, (err, equal) ->
			done assert.ok equal
		return

	it 'should stream a binary file from archive', (done) ->
		actual = asar.createReadStream 'test/input/extractthis.asar', 'dir2/file2.png'
		expected = fs.createReadStream 'test/expected/extractthis/dir2/file2.png', 'utf8'
		streamEqual actual, expected, (err, equal) ->
			done assert.ok equal
		return

	it 'should extract an archive', (done) ->
		extractTo = 'tmp/extractthis-api/'
		asar.extractArchive 'test/input/extractthis.asar', extractTo, (err) ->
			compDirs extractTo, 'test/expected/extractthis', done
		return

	it 'should extract a directory from archive', (done) ->
		extractTo = 'tmp/extractthis-dir2-api/'
		asar.extractArchive 'test/input/extractthis.asar', extractTo, root: 'dir2', (err) ->
			compDirs extractTo, 'test/expected/extractthis-dir2', done
		return

	describe 'archive node_modules:', ->
		src = 'node_modules/'
		archiveFilename = 'tmp/modules-api.asar'
		extractTo = 'tmp/modules-api/'

		it 'create it', (done) ->
			asar.createArchive src, archiveFilename, (err) ->
				return done err
			return
		
		it 'extract it', (done) ->
			asar.extractArchive archiveFilename, extractTo, done
			return

		it 'compare it', (done) ->
			compDirs extractTo, src, done
			return

		it 'extract coffee-script', (done) ->
			asar.extractArchive archiveFilename, 'tmp/coffee-script-api/', root: 'coffee-script/', done
			return

		it 'compare coffee-script', (done) ->
			compDirs 'tmp/coffee-script-api/', 'node_modules/coffee-script/', done
			return

		return

	return

describe 'api (old format, read-only):', ->
	@timeout 1000*60 * 1 # minutes

	it 'should list files/dirs in archive', ->
		archive = asar.loadArchive 'test/input/extractthis-oldformat.asar'
		actual = archive.getEntries().join '\n'
		expected = fs.readFileSync 'test/expected/extractthis-filelist.txt', 'utf8'
		# on windows replace slashes with backslashes and crlf with lf
		if os.platform() is 'win32'
			expected = expected.replace(/\//g, '\\').replace(/\r\n/g, '\n')
		return assert.equal actual, expected

	it 'should list files/dirs for directories in archive', ->
		archive = asar.loadArchive 'test/input/extractthis-oldformat.asar'
		actual = archive.getEntries('dir2').join '\n'
		expected = fs.readFileSync 'test/expected/extractthis-filelist-dir2.txt', 'utf8'
		# on windows replace slashes with backslashes and crlf with lf
		if os.platform() is 'win32'
			expected = expected.replace(/\//g, '\\').replace(/\r\n/g, '\n')
		return assert.equal actual, expected



	it 'should stream a text file from archive', (done) ->
		actual = asar.createReadStream 'test/input/extractthis-oldformat.asar', 'dir1/file1.txt'
		expected = fs.createReadStream 'test/expected/extractthis/dir1/file1.txt', 'utf8'
		streamEqual actual, expected, (err, equal) ->
			done assert.ok equal
		return

	it 'should stream a binary file from archive', (done) ->
		actual = asar.createReadStream 'test/input/extractthis-oldformat.asar', 'dir2/file2.png'
		expected = fs.createReadStream 'test/expected/extractthis/dir2/file2.png', 'utf8'
		streamEqual actual, expected, (err, equal) ->
			done assert.ok equal
		return

	it 'should extract an archive', (done) ->
		extractTo = 'tmp/extractthis-api-old/'
		asar.extractArchive 'test/input/extractthis-oldformat.asar', extractTo, (err) ->
			compDirs extractTo, 'test/expected/extractthis', done
		return

	it 'should extract a directory from archive', (done) ->
		extractTo = 'tmp/extractthis-dir2-api-old/'
		asar.extractArchive 'test/input/extractthis-oldformat.asar', extractTo, root: 'dir2', (err) ->
			compDirs extractTo, 'test/expected/extractthis-dir2', done
		return

	return
