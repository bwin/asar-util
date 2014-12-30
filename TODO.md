
# TODO
- [ ] support symlinks
- [ ] ditch (most of) sync-api
- [ ] use opts in sync-api, too
- [ ] use async stuf everywhere else
- [ ] archive.stat & ltstat & (...sync)
- [ ] original asar: test (and fix) extracting empty files
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
- [ ] split in asar-util(/asar-cli) and asar-archive ???
- [ ] ditch asar, just use regular zip file
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