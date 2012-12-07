# direct port of python code at https://gist.github.com/4141831#file_ipin.py
require 'zlib'

module IpaReader
  class PngFile
    attr_accessor :raw_data, :width, :height

    def initialize(oldPNG)
      pngheader = "\x89PNG\r\n\x1a\n"

      if oldPNG[0...8] != pngheader
        return nil
      end
    
      newPNG = oldPNG[0...8]
  
      chunkPos = newPNG.length

      idatAcc = ""
      breakLoop = false
  
      # For each chunk in the PNG file
      while chunkPos < oldPNG.length
        skip = false
        
        # Reading chunk
        chunkLength = oldPNG[chunkPos...chunkPos+4]
        chunkLength = chunkLength.unpack("N")[0]
        chunkType = oldPNG[chunkPos+4...chunkPos+8]
        chunkData = oldPNG[chunkPos+8...chunkPos+8+chunkLength]
        chunkCRC = oldPNG[chunkPos+chunkLength+8...chunkPos+chunkLength+12]
        chunkCRC = chunkCRC.unpack("N")[0]
        chunkPos += chunkLength + 12

        # Parsing the header chunk
        if chunkType == "IHDR"
          self.width = chunkData[0...4].unpack("N")[0]
          self.height = chunkData[4...8].unpack("N")[0]
        end
    
        # Parsing the image chunk
        if chunkType == "IDAT"
          # Store the chunk data for later decompression
          idatAcc += chunkData
          skip = true
        end

        # Removing CgBI chunk 
        if chunkType == "CgBI"
          skip = true
        end

        # Stopping the PNG file parsing
        if chunkType == "IEND"
          # Uncompressing the image chunk
          inf = Zlib::Inflate.new(-Zlib::MAX_WBITS)
          chunkData = inf.inflate(idatAcc)
          inf.finish
          inf.close
  
          chunkType = "IDAT"

          # Swapping red & blue bytes for each pixel
          newdata = ""
      
          self.height.times do 
            i = newdata.length
            newdata += chunkData[i..i].to_s
            self.width.times do
              i = newdata.length
              newdata += chunkData[i+2..i+2].to_s
              newdata += chunkData[i+1..i+1].to_s
              newdata += chunkData[i+0..i+0].to_s
              newdata += chunkData[i+3..i+3].to_s
            end
          end

          # Compressing the image chunk
          chunkData = newdata
          chunkData = Zlib::Deflate.deflate( chunkData )
          chunkLength = chunkData.length
          chunkCRC = Zlib.crc32(chunkType)
          chunkCRC = Zlib.crc32(chunkData, chunkCRC)
          chunkCRC = (chunkCRC + 0x100000000) % 0x100000000
          breakLoop = true
        end

        if !skip
          newPNG += [chunkLength].pack("N")
          newPNG += chunkType
          if chunkLength > 0
            newPNG += chunkData
          end
          newPNG += [chunkCRC].pack("N")
        end

        break if breakLoop
        
      end
   
      self.raw_data = newPNG
    end
  end
end