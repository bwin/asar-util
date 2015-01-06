
fs = require 'fs'
os = require 'os'
path = require 'path'

minimist = require 'minimist'
Progress = require 'progress'
nodeFilesize = require 'filesize'

asar = require './asar'
pkg = require '../package'

argv = minimist process.argv.slice(2),
	string: '_ i in o out a add r root'.split ' '
	boolean: 'h help v version examples w overwrite z compress P pretty l list s size verify info c colors C compat Q verbose debug q quiet'.split ' '
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
    --examples        show example usage and exit
    --verify          verify archive integrity and exit
    --info            output archive info and exit
-l, --list            list archive entries and exit
-s, --size            also list size
-a, --add <path>      path to directory to add to archive
-r, --root <path>     set root path in archive
-p, --pattern <glob>  set a filter pattern
-w, --overwrite       overwrite files
-z, --compress        gzip file contents
-P, --pretty          write pretty printed json TOC
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
	onProgress? bar.total, bar.total, 'done.'
	console.log "ok.".success unless quiet
	process.exit 0


truncatePath = (filename, maxLenght=0) ->
	return filename if maxLenght is 0

	truncated = no
	result = filename
	results = result.split /[\\\/]+/g
	while results.length > 1 and result.length + 3 > maxLenght
		truncated = yes
		results = result.split /[\\\/]+/g
		last = results.pop()
		results.pop()
		results.push last
		result = results.join path.sep
	if result.length + 3 > maxLenght
		len = result.length + 3
		result = '...' + result.substr len - maxLenght
		return result
	if truncated
		results = result.split /[\\\/]+/g
		last = results.pop()
		results.push '...'
		results.push last
		result = results.join path.sep
	return result

throttle = (fn, threshhold, scope) ->
	threshhold or (threshhold = 250)
	last = undefined
	deferTimer = undefined
	return ->
		context = scope or @
		now = +new Date
		args = arguments
		if last and now < last + threshhold
			
			# hold on to it
			clearTimeout deferTimer
			deferTimer = setTimeout(->
				last = now
				fn.apply context, args
				return
			, threshhold)
		else
			last = now
			fn.apply context, args
		return

niceSize = (size) ->
	result = nodeFilesize size,	output: 'object'
	return "#{result.value.toFixed 2}#{result.suffix}"

unless quiet
	bar = new Progress ':bar :percent :mbWritten/:mbTotal :filename',
		total: 0
		width: 20
		incomplete: '▒'
		complete: '█'

	onProgress = (total, progress, filename) ->
		bar.total = total
		bar.tick 0,
			filename: truncatePath filename, 30
			mbWritten: niceSize bar.curr#(bar.curr / 1024 / 1024).toFixed 1
			mbTotal: niceSize bar.total#(bar.total / 1024 / 1024).toFixed 1
	#onProgressThrottled = onProgress # throttle onProgress, 150
	onProgressThrottled = throttle onProgress, 150
	asar.opts.onProgress = (total, progress, filename) ->
		bar.curr += progress
		onProgressThrottled total, progress, filename

if verbose
	usageError 'Y U mix --verbose and --quiet ?! U crazy' if quiet
	asar.opts.verbose = yes
	filesAdded = []
	logFilenames =  ->
		process.stdout.clearLine()
		process.stdout.cursorTo 0
		console.log "#{filename}" for filename in filesAdded
		filesAdded = []
		bar.tick 0 if bar.curr > 0
	logFilenamesThrottled = throttle logFilenames, 150
	asar.opts.onFileBegin = (filename) ->
		filesAdded.push filename
		logFilenamesThrottled()

if debug
	asar.opts.debug = yes
	usageError 'Y U mix --debug and --quiet ?! U crazy' if quiet

asar.opts.compress = yes if doCompress
asar.opts.prettyToc = yes if prettyPrint

inputPath = []
inputPath.push '.'
if root in ['/', '\\']
	inputPath.push input
else
	inputPath.push "#{input}:"
	inputPath.push root
inputPath.push pattern if pattern
inputPath = path.join.apply(null, inputPath).info

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
	if verify
		usageError 'output and --verify not allowed together' if output
		try
			archive = asar.loadArchive input
		catch err
			generalError err.message
		console.log "verifying #{input.info}" unless quiet
		archive.verify (err, ok) ->
			if ok
				done()
			else
				generalError 'wrong checksum'

	else if appendDir
		# append directory to archive
		usageError 'output and --add not allowed together' if output
		console.log "adding #{(appendDir + (pattern or '')).info} to #{input.info}" unless quiet
		archive = asar.loadArchive input
		archive.addDirectory appendDir,
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

		#@opts.onProgress? @_filesSize, chunk.length, filename

		if inputStat.isDirectory()
			# create archive
			usageError 'using --root is not allowed for packing' if root isnt '/'
			console.log "packing #{inputPath} to #{output.info}" unless quiet
			asar.createArchive input, output, pattern, done
		else
			# extract archive
			console.log "extracting #{inputPath} to #{output.info}" unless quiet
			asar.extractArchive input, output,
				root: root
				pattern: pattern
			, done

	else #if showList
		#usageError 'output and --list not allowed together' if output
		#usageError 'output and --verify not allowed together' if verify
		#usageError 'Y U mix --list and --quiet ?! makes no sense' if quiet
		#usageError '--size can only be used with --list' if showListSize and not showList

		#console.log "listing #{inputPath}" unless quiet
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
				#line += "\t-> #{metadata.link}" if metadata.link?
				console.log line
		else
			# list archive content
			try
				entries = asar.getEntries input, root, pattern
			catch err
				generalError err.message
			console.log entries.join os.EOL
		#done()

	#else if showListSize then usageError '--size can only be used with --list'

	# input but nothing else
	#else usageError 'not enough arguments'

# show usage info (implicit)
else usageError 'no input specified'
	