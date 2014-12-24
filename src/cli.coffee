
fs = require 'fs'
os = require 'os'
path = require 'path'

minimist = require 'minimist'

asar = require './asar'
pkg = require '../package'

argv = minimist process.argv.slice(2),
	string: ['_'] # i in o out a add r root
	boolean: 'h help v version w l list s verify verbose q quiet'.split ' '
	default:
		root: '/'

help = ->
	console.log """
#{pkg.name} [input] [output] [options]
Parameter:
input               path to archive or directory
output              path to archive or directory
or if you prefer, you can set these with:
-i, --in <path>     specify input (can be archive or directory)
-o, --out <path>    specify output (can be archive or directory)
Options:
-h, --help          show help and exit
-v, --version       show version and exit
-a, --add <path>    path to directory to add to archive
-r, --root <path>   set root path in archive
-w, --overwrite     overwrite files
-l, --list          list archive entries
-s, --size          also list size
    --verify        verify archive integrity
    --verbose       more feedback
-q, --quiet         no feedback
Examples:
create archive from dir:            asar-util dir archive
same with named parameters:         asar-util -i dir -o archive
extract archive to dir:             asar-util archive dir
extract root from archive to dir:   asar-util archive dir -r root
extract d/file from archive to dir: asar-util archive dir -r d/file
verify archive:                     asar-util archive --verify
list archive entries:               asar-util archive -l
list archive entries for root:      asar-util archive -l -r root
list archive entries with size:     asar-util archive -ls
	"""

usageError = (msg) ->
	console.error "usage error: #{msg}#{os.EOL}"
	help()
	process.exit 1

generalError = (msg) ->
	console.error "#{msg}#{os.EOL}"
	process.exit 1

showHelp = argv.help or argv.h
showVersion = argv.version or argv.v
input = argv.i or argv.in or argv._[0]
output = argv.o or argv.out or argv._[1]
root = argv.r or argv.root
showList = argv.l or argv.list
showListSize = argv.s or argv.size
verify = argv.verify
verbose = argv.verbose
quiet = argv.q or argv.quiet

#[input, output] = argv._

# show usage info (explicit)
if showHelp
	help()

# show version info
else if showVersion
	console.log "v#{pkg.version}"

# we have at least an input
else if input
	if showList
		usageError 'output and --list not allowed together' if output
		usageError 'output and --verify not allowed together' if verify
		usageError 'Y U MIX --list and --quiet ?! makes no sense' if quiet
		console.log "listing #{input}:#{root}" if verbose
		if showListSize
			# list archive content with size
			try
				archive = asar.loadArchive input
				entries = archive.getEntries root
			catch err
				generalError err.message
			for entry in entries
				metadata = archive.getMetadata entry
				line = entry
				line += path.sep if metadata.files?
				line += "\t#{metadata.size}" if metadata.size
				console.log line
		else
			# list archive content
			try
				entries = asar.getEntries input, root
			catch err
				generalError err.message
			console.log entries.join os.EOL

	else if showListSize then usageError '--size can only be used with --list'

	else if output
		# transcode in -> out
		inputStat = fs.lstatSync input

		if inputStat.isDirectory()
			# create archive
			console.log "packing #{input} to #{output}" if verbose
			try
				asar.createArchive input, output, (err) ->
					generalError err.message if err
			catch err
				generalError err.message
		else
			# extract archive
			console.log "extracting #{input}:#{root} to #{output}" if verbose
			try
				asar.extractArchive input, output, root
			catch err
				generalError err.message

	# input but nothing else
	else usageError 'not enough arguments'

# show usage info (implicit)
else usageError 'no input specified'
	