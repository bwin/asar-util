
assert = require 'assert'
fs = require 'fs'
os = require 'os'
exec = require('child_process').exec

asar = require '../lib/asar'
compDirs = require './util/compareDirectories'

#asar.opts.verbose = yes

describe 'cli', ->

	it 'should create archive from directory', (done) ->
		packTo = 'tmp/packthis-cli.asar'
		exec "node bin/asar-util -i test/input/packthis/ -o #{packTo}", (err, stdout, stderr) ->
			actual = fs.readFileSync packTo, 'utf8'
			expected = fs.readFileSync 'test/expected/packthis.asar', 'utf8'
			return done assert.equal actual, expected
		return

	it 'should list files/dirs in archive', (done) ->
		exec "node bin/asar-util -i test/input/extractthis.asar -l", (err, stdout, stderr) ->
			actual = stdout
			expected = fs.readFileSync 'test/expected/extractthis-filelist.txt', 'utf8'
			# on windows replace slashes with backslashes and crlf with lf
			if os.platform() is 'win32'
				#expected = expected.replace(/\//g, '\\').replace(/\r\n/g, '\n')
				expected = expected.replace(/\//g, '\\') + '\n'
			done assert.equal actual, expected
			return
		return

	it 'should list files/dirs for directories in archive', (done) ->
		exec "node bin/asar-util -i test/input/extractthis.asar -l -r dir2", (err, stdout, stderr) ->
			actual = stdout
			expected = fs.readFileSync 'test/expected/extractthis-filelist-dir2.txt', 'utf8'
			# on windows replace slashes with backslashes and crlf with lf
			if os.platform() is 'win32'
				#expected = expected.replace(/\//g, '\\').replace(/\r\n/g, '\n')
				expected = expected.replace(/\//g, '\\') + '\n'
			done assert.equal actual, expected
			return
		return

	it 'should extract a text file (to disk) from archive', (done) ->
		extractTo = 'tmp/extracted-cli'
		extractedFilename = path.join extractTo, 'file1.txt'
		exec "node bin/asar-util -i test/input/extractthis.asar -o #{extractTo} -r dir1/file1.txt", (err, stdout, stderr) ->
			actual = fs.readFileSync extractedFilename, 'utf8'
			expected = fs.readFileSync 'test/expected/extractthis/dir1/file1.txt', 'utf8'
			# on windows replace crlf with lf
			expected = expected.replace(/\r\n/g, '\n') if os.platform() is 'win32'
			done assert.equal actual, expected
			return
		return

	it 'should extract a binary file (to disk) from archive', (done) ->
		extractTo = 'tmp/extracted-cli'
		extractedFilename = path.join extractTo, 'file2.png'
		exec "node bin/asar-util -i test/input/extractthis.asar -o #{extractTo} -r dir2/file2.png", (err, stdout, stderr) ->
			actual = fs.readFileSync extractedFilename, 'utf8'
			expected = fs.readFileSync 'test/expected/extractthis/dir2/file2.png', 'utf8'
			done assert.equal actual, expected
			return
		return

	it 'should extract an archive', (done) ->
		extractTo = 'tmp/extractthis-cli/'
		exec "node bin/asar-util -i test/input/extractthis.asar -o #{extractTo}", (err, stdout, stderr) ->
			compDirs extractTo, 'test/expected/extractthis', done
			return
		return
	
	it 'should extract a directory from archive', (done) ->
		extractTo = 'tmp/extractthis-dir2-cli/'
		exec "node bin/asar-util -i test/input/extractthis.asar -o #{extractTo} -r dir2", (err, stdout, stderr) ->
			compDirs extractTo, 'test/expected/extractthis-dir2', done
			return
		return
		
	return

describe 'cli (old format, read-only)', ->

	it 'should list files/dirs in archive', (done) ->
		exec "node bin/asar-util -i test/input/extractthis-oldformat.asar -l", (err, stdout, stderr) ->
			actual = stdout
			expected = fs.readFileSync 'test/expected/extractthis-filelist.txt', 'utf8'
			# on windows replace slashes with backslashes and crlf with lf
			if os.platform() is 'win32'
				#expected = expected.replace(/\//g, '\\').replace(/\r\n/g, '\n')
				expected = expected.replace(/\//g, '\\') + '\n'
			done assert.equal actual, expected
			return
		return

	it 'should list files/dirs for directories in archive', (done) ->
		exec "node bin/asar-util -i test/input/extractthis-oldformat.asar -l -r dir2", (err, stdout, stderr) ->
			actual = stdout
			expected = fs.readFileSync 'test/expected/extractthis-filelist-dir2.txt', 'utf8'
			# on windows replace slashes with backslashes and crlf with lf
			if os.platform() is 'win32'
				#expected = expected.replace(/\//g, '\\').replace(/\r\n/g, '\n')
				expected = expected.replace(/\//g, '\\') + '\n'
			done assert.equal actual, expected
			return
		return

	it 'should extract a text file (to disk) from archive', (done) ->
		extractTo = 'tmp/extracted-cli-old'
		extractedFilename = path.join extractTo, 'file1.txt'
		exec "node bin/asar-util -i test/input/extractthis-oldformat.asar -o #{extractTo} -r dir1/file1.txt", (err, stdout, stderr) ->
			actual = fs.readFileSync extractedFilename, 'utf8'
			expected = fs.readFileSync 'test/expected/extractthis/dir1/file1.txt', 'utf8'
			# on windows replace crlf with lf
			expected = expected.replace(/\r\n/g, '\n') if os.platform() is 'win32'
			done assert.equal actual, expected
			return
		return

	it 'should extract a binary file (to disk) from archive', (done) ->
		extractTo = 'tmp/extracted-cli-old'
		extractedFilename = path.join extractTo, 'file2.png'
		exec "node bin/asar-util -i test/input/extractthis-oldformat.asar -o #{extractTo} -r dir2/file2.png", (err, stdout, stderr) ->
			actual = fs.readFileSync extractedFilename, 'utf8'
			expected = fs.readFileSync 'test/expected/extractthis/dir2/file2.png', 'utf8'
			done assert.equal actual, expected
			return
		return

	it 'should extract an archive', (done) ->
		extractTo = 'tmp/extractthis-cli-old'
		exec "node bin/asar-util -i test/input/extractthis-oldformat.asar -o #{extractTo}", (err, stdout, stderr) ->
			compDirs extractTo, 'test/expected/extractthis', done
			return
		return

	it 'should extract a directory from archive', (done) ->
		extractTo = 'tmp/extractthis-dir2-cli-old'
		exec "node bin/asar-util -i test/input/extractthis-oldformat.asar -o #{extractTo} -r dir2", (err, stdout, stderr) ->
			compDirs extractTo, 'test/expected/extractthis-dir2', done
			return
		return

	return
