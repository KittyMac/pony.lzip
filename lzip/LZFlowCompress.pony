// A simple pony wrapper around the bzip2 library

use "collections"
use "fileExt"
use "flow"

use "path:/usr/lib" if osx
use "lib:lz"  

actor LZFlowCompress is Flowable
	
	var lzret:U32 = _LzErrnoEnum.ok()
	
	let target:Flowable tag
	let bufferSize:USize
	
	var encoder:_LzEncoderRef
	
	fun _tag():USize => 119

	new create(compressionLevel:USize, bufferSize':USize, target':Flowable tag) =>
		target = target'
		bufferSize = bufferSize'
    
    
    let dictionary_size_by_level:Array[U32] = [
      65535
      1 << 20
      3 << 19
      1 << 21
      3 << 20
      1 << 22
      1 << 23
      1 << 24
      3 << 23
      1 << 25
    ]
    
    let match_len_limit_by_level:Array[U32] = [
      16
      5
      6
      8
      12
      20
      36
      68
      132
      273
    ]
    
    var dict_size = try dictionary_size_by_level(compressionLevel)? else 65535 end
    var match_len = try match_len_limit_by_level(compressionLevel)? else 16 end
		
    encoder = @LZ_compress_open(dict_size, match_len, U64.max_value() )
    
	  if encoder.is_null() or (@LZ_compress_errno( encoder ) != _LzErrnoEnum.ok()) then
			@LZ_compress_close(encoder)
			return
		end
	
	be flowFinished() =>
		@LZ_compress_finish(encoder)
    
    performCompressRead()
    
		@LZ_compress_close(encoder)
		target.flowFinished()
	
  fun ref performCompressRead() =>
    // when compressing, we only know that we're 100% done when the data stop coming
    // so once we get here we need to call LZ_compress_read() one more time to 
    // flush the rest of the data
  	while true do

  		let outBuffer = recover iso Array[U8](bufferSize) end
  		let outPointer = outBuffer.cpointer()
	
  		let rd = @LZ_compress_read(encoder, outPointer.offset(0), bufferSize.u32())
  		if rd < 0 then
  			lzret = @LZ_compress_errno(encoder)
  			@fprintf[I32](@pony_os_stderr[Pointer[U8]](), ("lz compression read error: " + lzret.string() + "\n").cstring())
  			@LZ_compress_close(encoder)
  			return
  		end
  		if rd == 0 then
  			break
  		end
	  
  		outBuffer.undefined(rd.usize())
  		target.flowReceived(consume outBuffer)
  	end
  
	be flowReceived(dataIso:Any iso) =>
		let data:Any ref = consume dataIso
    
		// If the compression error'd out, then we can't really do anything
		if lzret != _LzErrnoEnum.ok() then
			return
		end
		
		try
			let inBuffer = data as CPointer
			let inBufferSize = inBuffer.size().usize()
			var inOffset:USize = 0
	
			while inOffset < inBufferSize do
				let inMaxSize = (inBufferSize - inOffset).min(@LZ_compress_write_size(encoder).usize())
				if inMaxSize == 0 then
					@usleep[I32](I32(5_000_000))
					continue
				end
								
				let inPointer = inBuffer.cpointer(inOffset)
				inOffset = inOffset + inMaxSize
        
				let wr = @LZ_compress_write(encoder, inPointer.offset(0), inMaxSize.u32() )
				if wr < 0 then
					lzret = @LZ_compress_errno(encoder)
					@fprintf[I32](@pony_os_stderr[Pointer[U8]](), ("lz compression write error: " + lzret.string() + "\n").cstring())
					@LZ_compress_close(encoder)
					return
				end
        
        // if we have no more data to send, flush the buffer then start calling read
        if inOffset >= inBufferSize then
          @LZ_compress_sync_flush(encoder)
        end
			
				performCompressRead()
        
			end
		end
		
	
	