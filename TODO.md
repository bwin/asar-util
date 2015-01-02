
# TODO
- [ ] add --info command:
archive size, dirs, files, links, compsize, decompsize, checksum
- [ ] use async fs stuff everywhere
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
