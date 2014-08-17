#!/usr/bin/ruby
require 'set'
require 'yaml'
require 'pp'

data = YAML.load_file ARGV[0]
callgraph = data["callgraph"]
whitelist = data["whitelist"]
blacklist = data["blacklist"]
has_code  = data["has_code"]


symbols = Set.new
data["callgraph"].each do |key, value|
    symbols << key
    value.each do |x|
        symbols << x
    end
end

symbols_known   = Hash.new
symbols_unknown = symbols.clone

#Remove already known symbols as the user shouldn't care about them
whitelist.each {|x,_| symbols_unknown.delete x}
blacklist.each {|x,_| symbols_unknown.delete x}

#Remove symbols without a body, as we cannot classify them
del_list = []
symbols_unknown.each do |sym|
    if(!callgraph.include? sym)
        del_list << sym
        if(has_code.include?(sym) && !whitelist.include?(sym))
            whitelist[sym] = "Added with no calling funcs"
        end
    end
end
del_list.each do |x|
    symbols_unknown.delete x
end


# Go through the unknown symbol list and find if a function calls all known functions
# If it does, then it is placed in the known symbols list with wheather it is
# realtime or not
while !symbols_unknown.empty?
    del_list = []
    symbols_unknown.each do |sym|
        do_classify = true
        safe = true
        rational = nil
        callgraph[sym].each do |x|
            do_classify &&= !symbols_unknown.include?(x)
            safe        &&= whitelist.include? x
            if(!whitelist.include?(x))
                rational ||= x
            end
        end

        if(do_classify)
            if(safe)
                whitelist[sym] = "added along the way {WHITELIST}"
                symbols_known[sym] = "safe"
            else
                blacklist[sym] = "added along the way {BLACKLIST}"
                symbols_known[sym] = "unsafe{#{rational}}"
            end
            del_list << sym
        end
    end
    del_list.each do |x|
        symbols_unknown.delete x
    end

    if(del_list.empty?)
        break
    end
end

symbols_known.each do |line|
    puts "#{line[0]} #{line[1]}"
end
