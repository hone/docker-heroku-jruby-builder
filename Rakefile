desc "Generate new jruby shell scripts"
task :new, [:version, :stack] do |t, args|
  source_folder = "rubies/#{args[:stack]}"
  FileUtils.mkdir_p(source_folder)

  write_file = Proc.new do |ruby_version, jruby_version|
    file = "#{source_folder}/ruby-#{ruby_version}-jruby-#{jruby_version}.sh"
    puts "Writing #{file}"
    File.open(file, 'w') do |file|
      file.puts <<FILE
#!/bin/sh

source `dirname $0`/../common.sh
source `dirname $0`/common.sh

docker run -v $OUTPUT_DIR:/tmp/output -v $CACHE_DIR:/tmp/cache -e VERSION=#{jruby_version} -e RUBY_VERSION=#{ruby_version} -t hone/jruby-builder:$STACK
FILE
    end
  end

  # JRuby 9000
  if Gem::Version.new(args[:version]) > Gem::Version.new("1.8.0")
    if args[:version] == "9.0.0.0.pre1"
      write_file.call("2.2.0", args[:version])
    else
      write_file.call("2.2.2", args[:version])
    end
  else
    ["1.8.7", "1.9.3", "2.0.0"].each do |ruby_version|
      write_file.call(ruby_version, args[:version])
    end
  end
end

desc "Upload a ruby to S3"
task :upload, [:version, :ruby_version, :stack] do |t, args|
  require 'aws-sdk'
  
  file        = "ruby-#{args[:ruby_version]}-jruby-#{args[:version]}.tgz"
  s3_key      = "#{args[:stack]}/#{file}"
  bucket_name = "heroku-buildpack-ruby"
  s3          = AWS::S3.new
  bucket      = s3.buckets[bucket_name]
  object      = bucket.objects[s3_key]
  build_file  = "builds/#{args[:stack]}/#{file}"

  puts "Uploading #{build_file} to s3://#{bucket_name}/#{s3_key}"
  object.write(file: build_file)
  object.acl = :public_read
end

desc "Build docker image for stack"
task :generate_image, [:stack] do |t, args|
  require 'fileutils'
  FileUtils.cp("dockerfiles/Dockerfile.#{args[:stack]}", "Dockerfile")
  system("docker build -t hone/jruby-builder:#{args[:stack]} .")
  FileUtils.rm("Dockerfile")
end
