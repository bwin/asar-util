
# TODO
- [ ] support symlinks
- [ ] ?? --pretty: nicer json-header
- [ ] use opts in sync-api, too
- [ ] archive.stat & ltstat & (...sync)
- [ ] original asar: test (and fix) extracting empty files
- [ ] add verify command
- [ ] default:dont-overwrite, honor --overwrite flag
- [ ] honor --compat
- [ ] test -ls
- [ ] error handling
- [ ] test error handling
- [ ] ? removeFile
- [ ] ? removeDirectory
- [ ] adding files to existing archive aka rewriting
- [ ] readme
- [ ] dev-dep:asar & test performance against it on our node_modules and just node_modules/coffee-script
- [ ] 

# MAYBE's
- [ ] ??? treat ints as ints instead of strings (internally and in json) (@_offset, node.offset) (compability with asar-orig?!)
- [ ] ditch asar, just use regular zip file
- [ ] ditch sync-api ?
- [ ] use vinyl (vinyl-fs & vinyl-asar) ?
- [ ] put crawlFilesystem in exports or as separate npm module ?
- [ ] option to use short header keys (v, _, s, o, l) (expandHeaderKeys if header.v) ?
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