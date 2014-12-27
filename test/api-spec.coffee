
assert = require 'assert'
fs = require 'fs'
os = require 'os'

asar = require '../lib/asar'
compDirs = require './util/compareDirectories'

#asar.opts.verbose = yes

describe 'api:', ->
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

	it 'should extract a text file (to memory) from archive', ->
		archive = asar.loadArchive 'test/input/extractthis.asar'
		actual = archive.getFile('dir1/file1.txt').toString 'utf8'
		expected = fs.readFileSync 'test/expected/extractthis/dir1/file1.txt', 'utf8'
		# on windows replace crlf with lf
		expected = expected.replace(/\r\n/g, '\n') if os.platform() is 'win32'
		return assert.equal actual, expected

	it 'should extract a binary file (to memory) from archive', ->
		archive = asar.loadArchive 'test/input/extractthis.asar'
		actual = archive.getFile 'dir2/file2.png'
		expected = fs.readFileSync 'test/expected/extractthis/dir2/file2.png', 'utf8'
		return assert.equal actual, expected

	it 'should extract a text file (to disk) from archive', ->
		extractTo = 'tmp/extracted-api'
		extractedFilename = path.join extractTo, 'file1.txt'
		asar.extractArchive 'test/input/extractthis.asar', extractTo, 'dir1/file1.txt'
		actual = fs.readFileSync extractedFilename, 'utf8'
		expected = fs.readFileSync 'test/expected/extractthis/dir1/file1.txt', 'utf8'
		# on windows replace crlf with lf
		expected = expected.replace(/\r\n/g, '\n') if os.platform() is 'win32'
		return assert.equal actual, expected

	it 'should extract a binary file (to disk) from archive', ->
		extractTo = 'tmp/extracted-api'
		extractedFilename = path.join extractTo, 'file2.png'
		asar.extractArchive 'test/input/extractthis.asar', extractTo, 'dir2/file2.png'
		actual = fs.readFileSync extractedFilename, 'utf8'
		expected = fs.readFileSync 'test/expected/extractthis/dir2/file2.png', 'utf8'
		return assert.equal actual, expected

	it 'should extract an archive', (done) ->
		extractTo = 'tmp/extractthis-api/'
		asar.extractArchive 'test/input/extractthis.asar', extractTo
		compDirs extractTo, 'test/expected/extractthis', done
		return

	it 'should extract a directory from archive', (done) ->
		extractTo = 'tmp/extractthis-dir2-api/'
		asar.extractArchive 'test/input/extractthis.asar', extractTo, 'dir2'
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
			try
				asar.extractArchive archiveFilename, extractTo
			catch err
				return done err
			done()
			return

		it 'compare it', (done) ->
			compDirs extractTo, src, done
			return

		it 'extract coffee-script', (done) ->
			try
				asar.extractArchive archiveFilename, 'tmp/coffee-script-api/', 'coffee-script/'
			catch err
				return done err
			done()
			return

		it 'compare coffee-script', (done) ->
			compDirs 'tmp/coffee-script-api/', 'node_modules/coffee-script/', done
			return

		return

	return

describe 'api (old format, read-only):', ->

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

	it 'should extract a text file (to memory) from archive', ->
		archive = asar.loadArchive 'test/input/extractthis-oldformat.asar'
		actual = archive.getFile('dir1/file1.txt').toString 'utf8'
		expected = fs.readFileSync 'test/expected/extractthis/dir1/file1.txt', 'utf8'
		# on windows replace crlf with lf
		expected = expected.replace(/\r\n/g, '\n') if os.platform() is 'win32'
		return assert.equal actual, expected

	it 'should extract a binary file (to memory) from archive', ->
		archive = asar.loadArchive 'test/input/extractthis-oldformat.asar'
		actual = archive.getFile 'dir2/file2.png'
		expected = fs.readFileSync 'test/expected/extractthis/dir2/file2.png', 'utf8'
		return assert.equal actual, expected

	it 'should extract a text file (to disk) from archive', ->
		extractTo = 'tmp/extracted-api-old'
		extractedFilename = path.join extractTo, 'file1.txt'
		asar.extractArchive 'test/input/extractthis-oldformat.asar', extractTo, 'dir1/file1.txt'
		actual = fs.readFileSync extractedFilename, 'utf8'
		expected = fs.readFileSync 'test/expected/extractthis/dir1/file1.txt', 'utf8'
		# on windows replace crlf with lf
		expected = expected.replace(/\r\n/g, '\n') if os.platform() is 'win32'
		return assert.equal actual, expected

	it 'should extract a binary file (to disk) from archive', ->
		extractTo = 'tmp/extracted-api-old'
		extractedFilename = path.join extractTo, 'file2.png'
		asar.extractArchive 'test/input/extractthis-oldformat.asar', extractTo, 'dir2/file2.png'
		actual = fs.readFileSync extractedFilename, 'utf8'
		expected = fs.readFileSync 'test/expected/extractthis/dir2/file2.png', 'utf8'
		return assert.equal actual, expected

	it 'should extract an archive', (done) ->
		extractTo = 'tmp/extractthis-api-old'
		asar.extractArchive 'test/input/extractthis-oldformat.asar', extractTo
		compDirs extractTo, 'test/expected/extractthis', done
		return

	it 'should extract a directory from archive', (done) ->
		extractTo = 'tmp/extractthis-dir2-api-old'
		asar.extractArchive 'test/input/extractthis-oldformat.asar', extractTo, 'dir2'
		compDirs extractTo, 'test/expected/extractthis-dir2', done
		return

	return