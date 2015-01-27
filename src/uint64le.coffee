
UINT32_MAX = 0xFFFFFFFF
INT32_MAX = 0x7FFFFFFF
INT32_UINT32_MAX_DIFF = 0x80000000
HIGH_MAX = 0x00200000
UINT64_SIZE = 8

splitUInt64 = (number) ->
	high = 0
	low = number & UINT32_MAX
	low += INT32_UINT32_MAX_DIFF if low < 0

	if number > UINT32_MAX
		high = (number - low) / (UINT32_MAX + 1)
		high += INT32_UINT32_MAX_DIFF if high < 0
	
	return [low, high]

joinUInt64 = (numvec) ->
	[low, high] = numvec
	#console.log "joinUInt64", low, high
	low += INT32_UINT32_MAX_DIFF if low < 0
	high += INT32_UINT32_MAX_DIFF if high < 0
	throw new Error 'Number is too big.' if high > HIGH_MAX
	return low + high * (UINT32_MAX + 1)

toBuffer = (numvec) ->
	[low, high] = numvec
	buf = new Buffer UINT64_SIZE
	buf.writeUInt32LE low, 0
	buf.writeUInt32LE high, 4
	return buf

fromBuffer = (buf) -> [buf.readUInt32LE(0), buf.readUInt32LE(4)]

numberToBuffer = (number) -> toBuffer splitUInt64 number

bufferToNumber = (buf) -> joinUInt64 fromBuffer buf

# readUInt64LEFromStream streamReadUInt64LE  readUInt64LE
# writeUInt64LEToStream  streamWriteUInt64LE writeUInt64LE

module.exports = {
	numberToBuffer
	bufferToNumber
}