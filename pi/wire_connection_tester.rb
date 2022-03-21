#!/usr/bin/env ruby

require "i2c/i2c"


class GPIOResetter
  attr_accessor :port

  def initialize(port=4)
    @port = port
    setup_port(@port)
  end

  def setup_port(port)
    unless File.exist? "/sys/class/gpio/gpio#{@port}"
      File.write("/sys/class/gpio/export", "#{@port}\n")
    end
    # XXX unexpectedly reset here
    File.write("/sys/class/gpio/gpio#{@port}/direction", "out\n")
    File.write("/sys/class/gpio/gpio#{@port}/value", "1\n")
    self
  end

  def reset
    File.write("/sys/class/gpio/gpio#{@port}/value", "0\n")
    sleep 0.001
    File.write("/sys/class/gpio/gpio#{@port}/value", "1\n")
    sleep 0.001
  end
end


class EasyI2CResetter
  DEFAULT_DEVICE = "/dev/i2c-1"
  DEFAULT_ADDRESS = 0x0f
  DEFAULT_WAIT = 0.01 # 0.001  # XXX
  RESET_ADDRESS = 0x00
  VALID_FLAG_ADDRESSES = 0x01..0x02

  def initialize(address, option={})
    @address = address
    @device = option[:device] || DEFAULT_DEVICE
    @i2c = I2C.create(@device)
    @wait = DEFAULT_WAIT
  end

  def reset
    @i2c.write(@address, RESET_ADDRESS)
    sleep @wait
  end

  def valid_address?(address)
    VALID_FLAG_ADDRESSES.include? address
  end

  def set_flag(address, value)
    raise ArgumentError, "Invalid address" unless valid_address?(address)
    @i2c.write(@address, address, value)
  end

  def get_flag(address)
    raise ArgumentError, "Invalid address" unless valid_address?(address)
    @i2c.read(@address, 1, address).unpack("c").first
  end

  def wait_flag(address)
    loop do
      sleep 0.01
      if self.get_flag(address) == 1
        self.set_flag(address, 0)
        break
      end
    end
  end
end


class MCP23017
  DEFAULT_DEVICE = "/dev/i2c-1"
  DEFAULT_ADDRESS = 0x20

  def initialize(address, option={})
    @address = address
    @device = option[:device] || DEFAULT_DEVICE
    @i2c = I2C.create(@device)
  end

  def set_pullup(a = nil, b = nil)
    # 0: disable, 1: enable (default: 0)
    @i2c.write(@address, 0x0c, a) if a
    @i2c.write(@address, 0x0d, b) if b
  end

  def set_direction(a = nil, b = nil)
    # 0: output, 1: input (default: 1)
    @i2c.write(@address, 0x00, a) if a
    @i2c.write(@address, 0x01, b) if b
  end

  def set_gpio(a = nil, b = nil)
    # 0: L, 1: H (default: 0)
    @i2c.write(@address, 0x12, a) if a
    @i2c.write(@address, 0x13, b) if b
  end

  def read
    @i2c.read(@address, 2, 0x12).unpack("CC")
  end

  def x
    {
      address: @address,
      directions: @i2c.read(@address, 2, 0x00).unpack("CC"),
      pullups: @i2c.read(@address, 2, 0x0c).unpack("CC"),
      values: @i2c.read(@address, 2, 0x12).unpack("CC"),
    }
  end
end


class WireConnectionChecker
  def initialize(option={})
    unit_west = MCP23017.new(0x20)
    unit_east = MCP23017.new(0x21)
    @units = [unit_west, unit_east]
    @resetter = option[:resetter]
  end

  def reset
    @resetter.reset
  end

  def value_to_array(value)
    (0..7).map{|i| value & 1 << i == 0 }
  end

  def get_value(x)
    x.read.map{|v| value_to_array(v) }.flatten
  end

  def check(unit, pin)
    masked = [0b11111111, 0b11111111]
    case pin
    when 0..7
      masked[0] -= 0b00000001 << pin
    when 8..15
      masked[1] -= 0b00000001 << (pin - 8)
    else
      raise ArgumentError, "Invalid pin: #{pin}"
    end

    active, passive = (unit == 0) ? @units : @units.reverse

    reset
    active.set_pullup(*masked)
    passive.set_pullup(0b11111111, 0b11111111)
    active.set_direction(*masked)
    passive.set_direction(0b11111111, 0b11111111)
    sleep 0.010  # XXX stabilize volatge ?
    [get_value(@units[0]), get_value(@units[1])]
  end

  def get
    [0, 1].map do |unit|
      (0..15).map do |i|
        self.check(unit, i)
      end
    end
  end

  def self.result_to_matrix(result)
    matrix = ""
    matrix << "    0 1 2 3 4 5 6 7 8 9 A B C D E F   0 1 2 3 4 5 6 7 8 9 A B C D E F\n"
    result.each do |unit|
      unit.each.with_index do |r, i|
        west, east = r
        mark = (west.count(true) + east.count(true) == 1) ? " -" : " *"
        matrix << [
          "%X" % i,
          west.map {|v| (v) ? mark : "  " }.join,
          east.map {|v| (v) ? mark : "  " }.join,
        ].join("  ") << "\n"
      end
      matrix << "\n"
    end
    matrix
  end

  def self.result_to_signature(result)
    result.map do |unit|
      unit_signature = unit.map do |src|
        src.map do |dst_unit|
          dst_unit.reverse.inject(0) do |sum, bit|
            sum <<= 1
            sum += bit ? 1 : 0
          end
        end
      end
      unit_signature.flatten.map {|i| "%04x" % i }.join
    end.join(" ")
  end
end


class WireConnectionSignatureList
  DEFAULT_LIST_FILE_PATH = "signatures.dat"

  def initialize(path=DEFAULT_LIST_FILE_PATH)
    @path = path
    @data = []
  end

  def load
    @data = []
    File.open(@path) do |f|
      while line = f.gets
        line.chomp!
        if /\A([0-9a-f]+\s[0-9a-f]+)\s+(.+)/i =~ line
          @data << [$1, $2]
        else
          #puts "Unknown Signature Line: #{line}"
        end
      end
    end
    @data
  end

  def search(target_signature)
    found = []
    @data.each do |signature, name|
      found << name if signature == target_signature
    end
    found
  end
end


if __FILE__ == $0
  require "optparse"

  option = {
    loop: false,
    verbose: false,
  }

  ARGV.options { |opt|
    opt.on("-v", "--verbose") { |v| option[:verbose] = true }
    opt.on("-l", "--loop") { |v| option[:loop] = true }
    opt.parse!
  }

  resetter = EasyI2CResetter.new(0x0f)

  signature_list = WireConnectionSignatureList.new
  signature_list.load

  puts "Ready!"
  loop do
    resetter.wait_flag(1) if option[:loop]

    checker = WireConnectionChecker.new({resetter: resetter})
    result = checker.get
    signature = WireConnectionChecker.result_to_signature(result)
    found = signature_list.search(signature)

    if found.empty?
      puts "NotFound:"
      puts WireConnectionChecker.result_to_matrix(result)
      puts signature
      puts
    else
      puts "Found:"
      found.each do |entry|
        puts "  - #{entry}"
      end
    end

    break unless option[:loop]
    resetter.set_flag(1, 0) if option[:loop]
  end
  
end
