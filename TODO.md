
# TODO
- [ ] ditch cuint because its broken
- [ ] maybe headerLen as uint32 ? (header > 4.2 GB realistic? hell no) (but archiveSize needs to be uint64)
- [ ] use combined-stream
  combinedStream = new CombinedStream()
  .append (next) -> next fs.createReadStream './LICENSE'
  .append (next) -> next fs.createReadStream './README.md'
  IMPORTANTE check for .on 'finish', also check for bytesRead (or out.bytesWritten?)
  combinedStream.append(stream) Special case: stream can also be a String or Buffer. NICE
  combinedStream = new CombinedStream()
  .append 'MAGIC'
  .append (next) -> next fs.createReadStream './LICENSE'
  .append (next) -> next fs.createReadStream './LICENSE'
  .append (next) -> next fs.createReadStream './README.md'
  .append (next) -> next 'HEADER' + 'HEADERLEN' # async because we may not know the header size before
  .append (next) -> next 'CHECKSUM' # dont think that works
  .pipe out
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
