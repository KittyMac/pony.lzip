// A simple pony wrapper around the bzip2 library

use "collections"
use "fileExt"
use "flow"

use "path:/usr/lib" if osx
use "lib:lz"

actor LZFlowDecompress is Flowable
	
	var lzret:U32 = _LzErrnoEnum.ok()
	
	let target:Flowable tag
	let bufferSize:USize
	
	var decoder:_LzDecoderRef
	
	fun _tag():USize => 119

	new create(bufferSize':USize, target':Flowable tag) =>
		target = target'
		bufferSize = bufferSize'
		
		decoder = @LZ_decompress_open()
	  if decoder.is_null() or (@LZ_decompress_errno( decoder ) != _LzErrnoEnum.ok()) then
			@LZ_decompress_close(decoder)
			return
		end
	
	be flowFinished() =>
		@LZ_decompress_finish(decoder)
		@LZ_decompress_close(decoder)
		target.flowFinished()
	
	be flowReceived(dataIso:Any iso) =>
		let data:Any ref = consume dataIso
			
		// If the decompression error'd out, then we can't really do anything
		if lzret != _LzErrnoEnum.ok() then
			return
		end
		
		try
			let inBuffer = data as CPointer
			let inBufferSize = inBuffer.size().usize()
			var inOffset:USize = 0
	
			while inOffset < inBufferSize do
				let inMaxSize = (inBufferSize - inOffset).min(@LZ_decompress_write_size(decoder).usize())
				if inMaxSize == 0 then
					@usleep[I32](I32(5_000_000))
					continue
				end
								
				let inPointer = inBuffer.cpointer(inOffset)
				inOffset = inOffset + inMaxSize
				
				let wr = @LZ_decompress_write(decoder, inPointer.offset(0), inMaxSize.u32() )					
				if wr < 0 then
					lzret = @LZ_decompress_errno(decoder)
					@fprintf[I32](@pony_os_stderr[Pointer[U8]](), ("lz decompression write error: " + lzret.string() + "\n").cstring())
					@LZ_decompress_close(decoder)
					return
				end
			
				while true do
			
					let outBuffer = recover iso Array[U8](bufferSize) end
					let outPointer = outBuffer.cpointer()
				
					let rd = @LZ_decompress_read(decoder, outPointer.offset(0), bufferSize.u32())
					if rd == 0 then
						break
					end
					if rd < 0 then
						lzret = @LZ_decompress_errno(decoder)
						@fprintf[I32](@pony_os_stderr[Pointer[U8]](), ("lz decompression read error: " + lzret.string() + "\n").cstring())
						@LZ_decompress_close(decoder)
						return
					end
				
					outBuffer.undefined(rd.usize())
					target.flowReceived(consume outBuffer)
				end
			end
		end
		
	
	