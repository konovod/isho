# Reads picture dimensions from the header before ImageMagick touches the file.
# A "screenshot" of 30000x30000 pixels is a memory bomb, and the size limits
# alone would not catch it.
module Import::ImageSize
  record Info, extension : String, width : Int32, height : Int32

  MAX_SIDE = 20_000

  def self.inspect(bytes : Bytes) : Info?
    png(bytes) || jpeg(bytes) || webp(bytes)
  end

  private def self.png(bytes : Bytes) : Info?
    return nil if bytes.size < 24
    return nil unless bytes[0] == 0x89_u8 && bytes[1] == 0x50_u8 && bytes[2] == 0x4E_u8 && bytes[3] == 0x47_u8
    return nil unless String.new(bytes[12, 4]) == "IHDR"

    valid("png", be32(bytes, 16), be32(bytes, 20))
  end

  private def self.jpeg(bytes : Bytes) : Info?
    return nil if bytes.size < 4
    return nil unless bytes[0] == 0xFF_u8 && bytes[1] == 0xD8_u8

    index = 2
    while index + 1 < bytes.size
      return nil unless bytes[index] == 0xFF_u8

      marker = bytes[index + 1]
      index += 2
      # Standalone markers carry no length.
      next if marker == 0xD8_u8 || marker == 0x01_u8 || (marker >= 0xD0_u8 && marker <= 0xD7_u8)
      return nil if index + 1 >= bytes.size

      length = (bytes[index].to_i32 << 8) | bytes[index + 1].to_i32
      return nil if length < 2

      if (marker >= 0xC0_u8 && marker <= 0xC3_u8) ||
         (marker >= 0xC5_u8 && marker <= 0xC7_u8) ||
         (marker >= 0xC9_u8 && marker <= 0xCB_u8) ||
         (marker >= 0xCD_u8 && marker <= 0xCF_u8)
        return nil if index + 7 >= bytes.size

        height = (bytes[index + 3].to_i32 << 8) | bytes[index + 4].to_i32
        width = (bytes[index + 5].to_i32 << 8) | bytes[index + 6].to_i32
        return valid("jpg", width, height)
      end

      index += length
    end

    nil
  end

  private def self.webp(bytes : Bytes) : Info?
    return nil if bytes.size < 30
    return nil unless String.new(bytes[0, 4]) == "RIFF" && String.new(bytes[8, 4]) == "WEBP"

    case String.new(bytes[12, 4])
    when "VP8X"
      valid("webp", le24(bytes, 24) + 1, le24(bytes, 27) + 1)
    when "VP8 "
      width = le16(bytes, 26) & 0x3FFF
      height = le16(bytes, 28) & 0x3FFF
      valid("webp", width, height)
    when "VP8L"
      return nil unless bytes[20] == 0x2F_u8

      bits = le32(bytes, 21)
      valid("webp", (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1)
    end
  end

  private def self.valid(extension : String, width : Int32, height : Int32) : Info?
    return nil if width <= 0 || height <= 0
    return nil if width > MAX_SIDE || height > MAX_SIDE
    return nil if width.to_i64 * height.to_i64 > AppSettings::IMPORT_MAX_PIXELS

    Info.new(extension, width, height)
  end

  private def self.be32(bytes : Bytes, offset : Int32) : Int32
    (bytes[offset].to_i32 << 24) |
      (bytes[offset + 1].to_i32 << 16) |
      (bytes[offset + 2].to_i32 << 8) |
      bytes[offset + 3].to_i32
  end

  private def self.le16(bytes : Bytes, offset : Int32) : Int32
    bytes[offset].to_i32 | (bytes[offset + 1].to_i32 << 8)
  end

  private def self.le24(bytes : Bytes, offset : Int32) : Int32
    bytes[offset].to_i32 |
      (bytes[offset + 1].to_i32 << 8) |
      (bytes[offset + 2].to_i32 << 16)
  end

  private def self.le32(bytes : Bytes, offset : Int32) : Int32
    bytes[offset].to_i32 |
      (bytes[offset + 1].to_i32 << 8) |
      (bytes[offset + 2].to_i32 << 16) |
      (bytes[offset + 3].to_i32 << 24)
  end
end
