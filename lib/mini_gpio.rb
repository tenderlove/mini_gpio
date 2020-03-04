require "fiddle"
require "fiddle/import"

class MiniGPIO
  module Mmap
    PROT_READ = 0x01
    PROT_WRITE = 0x02
    MAP_SHARED = 0x001

    extend Fiddle::Importer

    dlload Fiddle::Handle::DEFAULT

    extern "uint32_t * mmap(void *addr, size_t length, int prot, int flags, int fd, int offset)"
    extern "int munmap(void *addr, size_t length)"
  end

  GPSET0 =  7
  GPSET1 =  8
  GPCLR0 = 10
  GPCLR1 = 11
  GPLEV0 = 13

  # GPIO modes
  module Modes
    INPUT  = 0
    OUTPUT = 1
    ALT0   = 4
    ALT1   = 5
    ALT2   = 6
    ALT3   = 7
    ALT4   = 3
    ALT5   = 2
  end

  attr_reader :ptr

  def initialize
    @ptr = File.open("/dev/gpiomem", File::Constants::RDWR | File::Constants::SYNC) do |f|
      Mmap.mmap(nil, 4*1024, Mmap::PROT_READ|Mmap::PROT_WRITE, Mmap::MAP_SHARED, f.to_i, 0)
    end
  end

  # Get the pin mode
  def mode pin
    reg = pin / 10
    shift = (pin % 10) * 3
    (get_int_at(reg) >> shift) & 7
  end

  # Set the pin mode
  def set_mode pin, mode
    reg = pin / 10
    shift = (pin % 10) * 3
    new_value = (get_int_at(reg) & ~(7 << shift)) | (mode << shift)
    set_int_at(reg, new_value)
  end

  # Read the pin
  def read pin
    0 != get_int_at(GPLEV0 + PI_BANK(pin)) & PI_BIT(pin) ? 1 : 0
  end

  # Write to the pin
  def write pin, value
    if value == 0
      set_int_at(GPCLR0 + PI_BANK(pin), PI_BIT(pin))
    else
      set_int_at(GPSET0 + PI_BANK(pin), PI_BIT(pin))
    end
  end

  private

  def PI_BANK gpio ; gpio >> 5; end
  def PI_BIT  gpio ; (1 << (gpio&0x1F)); end

  def get_int_at offset
    @ptr[offset * Fiddle::SIZEOF_INT, Fiddle::SIZEOF_INT].unpack1("L")
  end

  def set_int_at offset, value
    @ptr[offset * Fiddle::SIZEOF_INT, Fiddle::SIZEOF_INT] = [value].pack("L")
  end
end

if __FILE__ == $0
  gpio = MiniGPIO.new

  54.times do |i|
    puts "gpio=#{i} mode=%d level=%d" % [gpio.mode(i), gpio.read(i)]
  end

  gpio.set_mode 0, MiniGPIO::Modes::OUTPUT
  gpio.write 0, 1
  p gpio.read 0
  gpio.write 0, 0
  p gpio.read 0
end
