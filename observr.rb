watch(%r{solutions/(\d+).rb}) do |m|
  system "clear"
  system "bundle exec rake tasks:#{m[1]}"
end
