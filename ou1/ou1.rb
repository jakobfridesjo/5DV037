$<.read.scan(/0x[a-f\d]{1,8}/i) {|x|
  puts "#{x} #{x.to_i(16)}"
}
