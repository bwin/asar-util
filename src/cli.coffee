
os = require 'os'
path = require 'path'

minimist = require 'minimist'

asar = require './asar'
pkg = require '../package'

argv = minimist process.argv.slice(2),
	string: ['_']
	boolean: 'h help v version c create e extract l list s list-size a add verify q quiet verbose'.split ' '
	default:
		root: '/'

help = ->
	console.log "Usage: #{pkg.name} ..."
	console.log '-h, --help\tshow this'
	console.log '-v, --version\toutput version info'

	console.log '-c, --create <srcDir> <archive>'
	console.log '\tcreate archive from scrDir'
	console.log "\tExample: #{pkg.name} -c some/dir whatever.asar"

	console.log '-e, --extract <archive> [--root=ROOTPATH] <destDir>'
	console.log '\tExtract archive [in ROOTPATH] to destDir'
	console.log "\tExample: #{pkg.name} -e whatever.asar to/here"
	console.log "\tExample: #{pkg.name} -e whatever.asar --root=only/this to/here"

	#console.log '-a, --add <srcDir> <archive>'
	#console.log '\tadd srcDir to archive, overwriting existing files'
	#console.log "\tExample: #{pkg.name} -a add/this/dir whatever.asar"

	console.log '-l, --list <archive> [--root=ROOTPATH]'
	console.log '-ls, --list-size <archive> [--root=ROOTPATH]'
	console.log '\tlist files (optionally with size) in archive [in ROOTPATH]'
	console.log "\tExample: #{pkg.name} -l whatever.asar"
	console.log "\tExample: #{pkg.name} -l whatever.asar --root=only/this"
	console.log "\tExample: #{pkg.name} -ls whatever.asar --root=only/this"

	#console.log '--verify <archive>'
	#console.log '\tverify integrity of archive'
	#console.log "\tExample: #{pkg.name} --verify whatever.asar"
	
	#console.log '-q, --quiet\tbe silent'
	#console.log '--verbose\tmore output'

usageError = (msg) ->
	console.error "#{msg}#{os.EOL}"
	help()
	process.exit 1

generalError = (msg) ->
	console.error "#{msg}#{os.EOL}"
	process.exit 1

# show usage info (explicit)
if argv.help or argv.h
	help()

# show version info
else if argv.version or argv.v
	console.log "v#{pkg.version}"

# create archive
else if argv.create or argv.c
	usageError 'not enough arguments for packing' if argv._.length < 2
	[srcDir, destFile] = argv._
	console.log "packing #{srcDir} to #{destFile}"
	try
		asar.createArchive srcDir, destFile, (err) ->
			generalError err.message if err
	catch err
		generalError err.message

# extract archive
else if argv.extract or argv.e
	usageError 'not enough arguments for extracting' if argv._.length < 2
	[archiveFilename, destDir] = argv._
	console.log "extracting #{archiveFilename} to #{destDir}"
	try
		asar.extractArchive archiveFilename, destDir, argv.root
	catch err
		generalError err.message
	#console.log "done."

# list archive content with size
else if argv['list-size'] or (argv.l and argv.s)
	usageError 'not enough arguments for listing' if argv._.length < 1
	[archiveFilename] = argv._
	console.log "listing #{archiveFilename}:#{argv.root}"
	try
		archive = asar.loadArchive archiveFilename
		entries = archive.getEntries argv.root
	catch err
		generalError err.message
	for entry in entries
		metadata = archive.getMetadata entry
		line = entry
		line += path.sep if metadata.files?
		line += "\t#{metadata.size}" if metadata.size
		console.log line

# list archive content
else if argv.list or argv.l
	usageError 'not enough arguments for listing' if argv._.length < 1
	[archiveFilename] = argv._
	console.log "listing #{archiveFilename}:#{argv.root}"
	try
		entries = asar.getEntries archiveFilename, argv.root
	catch err
		generalError err.message
	console.log entries.join os.EOL

# show usage info (implicit)
else
	help()
	