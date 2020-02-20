use "fileExt"
use "files"
use "ponytest"

actor Main is TestList
	new create(env: Env) => PonyTest(env, this)
	new make() => None

	fun tag tests(test: PonyTest) =>
		//test(_TestSmallStringDecompression)
		//test(_TestLargeStringDecompression)
    //test(_TestSmallStringCompression)
    test(_TestLargeStringFullPath)
	
 	fun @runtime_override_defaults(rto: RuntimeOptions) =>
		//rto.ponyanalysis = true
		rto.ponyminthreads = 2
		rto.ponynoblock = true
		rto.ponygcinitial = 0
		rto.ponygcfactor = 1.0

class iso _TestLargeStringDecompression is UnitTest
	fun name(): String => "large file decompression"

	fun apply(h: TestHelper) =>
		var inFilePath = "test_large.lz"
		var outFilePath = "/tmp/test_large_lz_decompress.txt"

		h.long_test(2_000_000_000_000)

		let callback = object val is FlowFinished
			fun flowFinished() =>
				try
					let result = FileExt.fileToString(outFilePath)?
					h.complete(result.size() == 206_051)
				else
					h.complete(false)
				end
		end

		FileExtFlowReader(inFilePath, 512,
			LZFlowDecompress(1024,
				FileExtFlowByteCounter(
					FileExtFlowWriter(outFilePath,
						FileExtFlowFinished(callback, FileExtFlowEnd)
					)
				)
			)
		)

class iso _TestSmallStringDecompression is UnitTest
	fun name(): String => "small file decompression"

	fun apply(h: TestHelper) =>
		var inFilePath = "test_small.lz"
		var outFilePath = "/tmp/test_small_lz_decompress.txt"
		
		h.long_test(2_000_000_000_000)
		
		let callback = object val is FlowFinished
			fun flowFinished() =>
				try
					let result = FileExt.fileToString(outFilePath)?
					h.complete(result == "This is a test document which has been compressed by lzip")
				else
					h.complete(false)
				end
		end

		FileExtFlowReader(inFilePath, 512,
			LZFlowDecompress(1024,
				FileExtFlowByteCounter(
					FileExtFlowWriter(outFilePath,
						FileExtFlowFinished(callback, FileExtFlowEnd)
					)
				)
			)
		)
		

class iso _TestSmallStringCompression is UnitTest
	fun name(): String => "small file compression"

	fun apply(h: TestHelper) =>
		var inFilePath = "test_small.txt"
		var outFilePath = "/tmp/test_small_lz_compress.lz"

		h.long_test(2_000_000_000_000)

		let callback = object val is FlowFinished
			fun flowFinished() =>
				try
					let result = FileExt.fileToArray(outFilePath)?
					h.complete(result.size() == 109)
				else
					h.complete(false)
				end
		end

		FileExtFlowReader(inFilePath, 512,
			LZFlowCompress(5, 512,
				FileExtFlowByteCounter(
					FileExtFlowWriter(outFilePath,
						FileExtFlowFinished(callback, FileExtFlowEnd)
					)
				)
			)
		)

class iso _TestLargeStringFullPath is UnitTest
	fun name(): String => "large file full path"

	fun apply(h: TestHelper) =>
		var inFilePath = "test_large.txt"
		var outFilePath = "/tmp/test_large.txt"

		h.long_test(2_000_000_000_000)

		let callback = object val is FlowFinished
			fun flowFinished() =>
				try
					let result = FileExt.fileToArray(outFilePath)?
					h.complete(result.size() == 206_051)
				else
					h.complete(false)
				end
		end

		FileExtFlowReader(inFilePath, 512,
			LZFlowCompress(9, 512,
				LZFlowDecompress(1024,
					FileExtFlowWriter(outFilePath,
						FileExtFlowFinished(callback, FileExtFlowEnd)
					)
				)
			)
		)