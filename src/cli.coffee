
fs = require 'fs'
os = require 'os'
path = require 'path'

minimist = require 'minimist'

asar = require './asar'
pkg = require '../package'

argv = minimist process.argv.slice(2),
	string: '_ i in o out a add r root'.split ' '
	boolean: 'h help v version examples w overwrite z compress P pretty l list s size verify c colors C compat Q verbose debug q quiet'.split ' '
	default:
		root: '/'

help = ->
	console.log """
#{pkg.name} [input] [output] [options]
Parameter:
input                 path to archive or directory
output                path to archive or directory
or if you prefer, you can set these with:
-i, --in <path>       specify input (can be archive or directory)
-o, --out <path>      specify output (can be archive or directory)
Options:
-h, --help            show help and exit
-v, --version         show version and exit
    --examples        show example usage
-a, --add <path>      path to directory to add to archive
-r, --root <path>     set root path in archive
-p, --pattern <glob>  set a filter pattern
-w, --overwrite       overwrite files
-z, --compress        gzip file contents
-P, --pretty          write pretty printed json TOC
-l, --list            list archive entries
-s, --size            also list size
    --verify          verify archive integrity
-c, --colors          use terminal colors for output
-C, --compat          also read legacy asar format
-Q, --verbose         more feedback
    --debug           a lot feedback
-q, --quiet           no feedback
	"""

examples = ->
	console.log """
#{pkg.name}
Examples:
create archive from dir:            asar-util dir archive
same with named parameters:         asar-util -i dir -o archive
extract archive to dir:             asar-util archive dir
extract root from archive to dir:   asar-util archive dir -r root
extract d/file from archive to dir: asar-util archive dir -r d/file
verify archive:                     asar-util archive --verify
list archive entries:               asar-util archive -l
list archive entries for root:      asar-util archive -l -r root
list entries for root with pattern: asar-util archive -l -r root -p pattern
list archive entries with size:     asar-util archive -ls
	"""

showHelp = argv.help or argv.h
showVersion = argv.version or argv.v
showExamples = argv.examples
input = argv.i or argv.in or argv._[0]
output = argv.o or argv.out or argv._[1]
appendDir = argv.a or argv.add
root = argv.r or argv.root
pattern = argv.p or argv.pattern
doOverwrite = argv.w or argv.overwrite
doCompress = argv.z or argv.compress
prettyPrint = argv.P or argv.pretty
showList = argv.l or argv.list
showListSize = argv.s or argv.size
verify = argv.verify
useColors = argv.c or argv.colors
compatibilityMode = argv.C or argv.compat
verbose = argv.Q or argv.verbose
debug = argv.debug
quiet = argv.q or argv.quiet


if useColors
	require 'terminal-colors' 
	String::__defineGetter__ 'error', -> @.red
	String::__defineGetter__ 'warning', -> @.yellow
	String::__defineGetter__ 'info', -> @.cyan
	String::__defineGetter__ 'success', -> @.green
else
	String::__defineGetter__ 'error', -> '' + @
	String::__defineGetter__ 'warning', -> '' + @
	String::__defineGetter__ 'info', -> '' + @
	String::__defineGetter__ 'success', -> '' + @

usageError = (msg) ->
	console.error "usage error: #{msg}#{os.EOL}".error
	help()
	process.exit -1

generalError = (msg) ->
	console.error "#{msg}#{os.EOL}".error unless quiet
	process.exit 1

done = (err) ->
	generalError err.message if err
	console.log "ok.".success unless quiet
	process.exit 0


if verbose
	asar.opts.verbose = yes
	usageError 'Y U mix --verbose and --quiet ?! U crazy' if quiet
if debug
	asar.opts.debug = yes
	usageError 'Y U mix --debug and --quiet ?! U crazy' if quiet
asar.opts.compress = yes if doCompress
asar.opts.prettyToc = yes if prettyPrint

# show usage info (explicit)
if showHelp
	help()

# show examples
else if showExamples
	examples()

# show version info
else if showVersion
	console.log "v#{pkg.version}"

# we have at least an input
else if input
	if showList
		usageError 'output and --list not allowed together' if output
		usageError 'output and --verify not allowed together' if verify
		usageError 'Y U mix --list and --quiet ?! makes no sense' if quiet
		console.log "listing #{input}:#{root}" if verbose
		if showListSize
			# list archive content with size
			try
				archive = asar.loadArchive input
				entries = archive.getEntries root, pattern
			catch err
				generalError err.message
			for entry in entries
				metadata = archive.getMetadata entry
				line = entry
				line += path.sep if metadata.files?
				line += "\t#{metadata.size}" if metadata.size?
				console.log line
		else
			# list archive content
			try
				entries = asar.getEntries input, root, pattern
			catch err
				generalError err.message
			console.log entries.join os.EOL
		#done()

	else if showListSize then usageError '--size can only be used with --list'

	else if verify
		usageError 'output and --verify not allowed together' if output
		try
			archive = asar.loadArchive input
		catch err
			generalError err.message
		archive.verify (err, ok) ->
			if ok
				done()
			else
				generalError 'wrong checksum'

	else if appendDir
		# append directory to archive
		usageError 'output and --add not allowed together' if output
		console.log "adding #{(appendDir + (pattern or '')).info} to #{input.info}" if verbose
		archive = asar.loadArchive input
		archive.addDirectory appendDir, appendDir,
			pattern: pattern
		, (err) ->
			return done err if err
			archive.write input, done

	else if output
		# transcode in -> out
		try
			inputStat = fs.lstatSync input
		catch err
			generalError "input not found: #{input}"

		if inputStat.isDirectory()
			# create archive
			console.log "packing #{(input + (pattern or '')).info} to #{output.info}" if verbose
			asar.createArchive input, output, pattern, done
		else
			# extract archive
			console.log "extracting #{(input + root + (pattern or '')).info} to #{output.info}" if verbose
			asar.extractArchive input, output,
				root: root
				pattern: pattern
			, done

	# input but nothing else
	else usageError 'not enough arguments'

# show usage info (implicit)
else usageError 'no input specified'
	