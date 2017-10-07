package openfl._internal.stage3D.atf;

import haxe.io.Bytes;
import openfl.utils.ByteArray;
import openfl.errors.IllegalOperationError;
import openfl.display3D.Context3DTextureFormat;

typedef UploadCallback = UInt -> Int -> Int -> Int -> Int -> lime.utils.DataPointer -> Void;

/**
	This class can read textures from Adobe Texture Format containers.
	Currently only ATF block DXT1/DXT5 compressed textures without JPEG-XR+LZMA are supported. You can create such files via:
	`png2atf -n 0,0 -c d -i texture.png -o compressed_texture.atf`

	To read a texture you need to perform these steps:
	- create a `new ATFReader()` instance
	- read the header with `readHeader()`
	- call `readTextures()` and a provide an upload callback

	The ATF specification can be found here:
	<https://www.adobe.com/devnet/archive/flashruntimes/articles/atf-file-format.html>
**/
class ATFReader {

	var data: ByteArray;

	var version = 0;
	var width:Int;
	var height:Int;
	var mipCount:Int;


	public function new (data:ByteArray, byteArrayOffset:UInt) {

		data.position = byteArrayOffset;
		var signature:String = data.readUTFBytes (3);
		data.position = byteArrayOffset;

		if (signature != "ATF") {
			
			throw new IllegalOperationError ("ATF signature not found");
			
		}

		var length = 0;

		// When the 6th byte is 0xff, we have one of the new formats
		if (data[byteArrayOffset+6] == 0xff) {
			
			version = data[byteArrayOffset+7];
			data.position = byteArrayOffset+8;
			length = __readUInt32 (data);
		
		}
		else {
			
			version = 0;
			data.position = byteArrayOffset+3;
			length = __readUInt24 (data);
		
		}
		
		
		if (cast ((byteArrayOffset + length), Int) > data.length) {
			
			throw new IllegalOperationError ("ATF length exceeds byte array length");
			
		}

		this.data = data;

	}


	public function readHeader (__width:Int, __height:Int, cubeMap:Bool):ATFFormat {

		var tdata = data.readUnsignedByte();
		var type:ATFType = cast (tdata >> 7);
		
		if ( !cubeMap && (type != ATFType.NORMAL) ) {
			
			throw new IllegalOperationError ("ATF Cube map not expected");
			
		}
		
		if ( cubeMap && (type != ATFType.CUBE_MAP) ) {
			
			throw new IllegalOperationError ("ATF Cube map expected");
			
		}

		var atfFormat:ATFFormat = cast (tdata & 0x7f);
		
		width = (1 << cast data.readUnsignedByte ());
		height = (1 << cast data.readUnsignedByte ());
		
		if (width != __width || height != __height) {
			
			throw new IllegalOperationError ("ATF width and height dont match");
			
		}
		
		mipCount = cast data.readUnsignedByte ();

		return atfFormat;

	}
	
	
	public function readTextures (uploadCallback:UploadCallback):Void {

		// DXT1/5, ETC1, PVRTC4, ETC2
		// ETC2 is available with ATF version 3 
		var gpuFormats = (version < 3) ? 3 : 4;
		var sideCount = 1; // preparation for cube textures

		for (side in 0...sideCount) {
			for (level in 0...mipCount) {
				
				for (gpuFormat in 0...gpuFormats) {
					
					var blockLength = (version == 0) ? __readUInt24 (data) : __readUInt32 (data);

					if ((data.position + blockLength) > data.length) {

						throw new IllegalOperationError("Block length exceeds ATF file length");
					
					}
					
					if (blockLength > 0) {
						

						if (gpuFormat == 0) {
							
							// DXT1/5

							var bytes:Bytes = Bytes.alloc(blockLength);
							data.readBytes(bytes, 0, blockLength);
							
							uploadCallback(side, level, width>>level, height>>level, blockLength, bytes);
						
						} else {

							// TODO: Other formats are currently not supported
							
							data.position += blockLength;
							
						}
						
					}
					
				}
				
			}
		}
		
	}

	private function __readUInt24 (data:ByteArray):UInt {
		
		var value:UInt;
		value = (data.readUnsignedByte () << 16);
		value |= (data.readUnsignedByte () << 8);
		value |= data.readUnsignedByte ();
		return value;
		
	}
	
	
	private function __readUInt32 (data:ByteArray):UInt {
		
		var value:UInt;
		value = (data.readUnsignedByte () << 24);
		value |= (data.readUnsignedByte () << 16);
		value |= (data.readUnsignedByte () << 8);
		value |= data.readUnsignedByte ();
		return value;
		
	}
}