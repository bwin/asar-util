
# TODO
- [ ] add verify command
- [ ] support symlinks
- [x] change cli args
- [x] cli: fix extracting file
- [ ] error handling
- [ ] test error handling
- [x] tests cli
- [ ] test -ls
- [ ] ? removeFile
- [ ] ? removeDirectory
- [ ] adding files to existing archive aka rewriting
- [ ] readme
- [ ] option to use terminal colors
- [ ] 

# MAYBE's
- [ ] put crawlFilesystem in exports or as separate npm module
- [ ] option to use short header keys (v, _, s, o, l) (expandHeaderKeys if header.v)
- [ ] 


class AsarArchiveFileReadStream extends stream.Transform
	constructor: (opts) ->
		#unless @ instanceOf AsarArchiveFileReadStream
		#	return new AsarArchiveFileReadStream opts

		#Transform.call @, opts
		super opts

	_transform: (chunk, enc, cb) ->
		buffer = if Buffer.isBuffer chunk then chunk else new Buffer chunk, enc
		@push buffer
		cb()