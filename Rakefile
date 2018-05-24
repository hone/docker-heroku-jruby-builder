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
  if (cmp_ver = Gem::Version.new(args[:version])) > Gem::Version.new("1.8.0")
    require 'uri'
    require 'net/http'
    uri = URI("https://raw.githubusercontent.com/jruby/jruby/#{args[:version]}/default.build.properties")
    default_props = Net::HTTP.get(uri)
    version_ruby = default_props.match(/^version\.ruby=(.*)$/)[1]
    if version_ruby.nil? || version_ruby == ""
      raise "Could not find Ruby StdLib version!"
    end
    write_file.call(version_ruby, args[:version])
  else
    ["1.8.7", "1.9.3", "2.0.0"].each do |ruby_version|
      write_file.call(ruby_version, args[:version])
    end
  end
end

desc "Upload a ruby to S3"
task :upload, [:version, :ruby_version, :stack] do |t, args|
  require 'aws-sdk'

  puts "WARNING: Empty AWS_PROFILE" if ENV['AWS_PROFILE'].nil?

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

desc "Test images"
task :test, [:version, :ruby_version, :stack] do |t, args|
  require 'tmpdir'
  require 'okyakusan'
  require 'rubygems/package'
  require 'zlib'
  require 'net/http'

  def system_pipe(command)
    IO.popen(command) do |io|
      while data = io.read(16) do
        print data
      end
    end
  end

  def gemfile_ruby(ruby_version, engine, engine_version)
    %Q{ruby "#{ruby_version}", :engine => "#{engine}", :engine_version => "#{engine_version}"}
  end

  def network_retry(max_retries, retry_count = 0)
    yield
  rescue Errno::ECONNRESET, EOFError
    if retry_count < max_retries
      $stderr.puts "Retry Count: #{retry_count}"
      sleep(0.01 * retry_count)
      retry_count += 1
      retry
    end
  end

  tmp_dir  = Dir.mktmpdir
  app_dir  = "#{tmp_dir}/app"
  app_tar  = "#{tmp_dir}/app.tgz"
  app_name = nil
  web_url  = nil
  FileUtils.mkdir_p("#{tmp_dir}/app")

  begin
    system_pipe("git clone --depth 1 https://github.com/sharpstone/jruby-minimal.git #{app_dir}")
    exit 1 unless $?.success?

    ruby_line = gemfile_ruby(args[:ruby_version], "jruby", args[:version])
    puts "Setting ruby version: #{ruby_line}"
    text = File.read("#{app_dir}/Gemfile")
    text.sub!(/^\s*ruby.*$/, ruby_line)
    File.open("#{app_dir}/Gemfile", 'w') {|file| file.print(text) }

    lines = File.readlines("#{app_dir}/Gemfile.lock")
    File.open("#{app_dir}/Gemfile.lock", 'w') do |file|
      lines.each do |line|
        next if line.match(/RUBY VERSION/)
        next if line.match(/ruby (\d+\.\d+\.\d+p\d+) \(jruby \d+\.\d+\.\d+\.\d+\)/)
        file.puts line
      end
    end

    Dir.chdir(app_dir) do
      puts "Packaging app"
      system_pipe("tar czf #{app_tar} *")
      exit 1 unless $?.success?
    end

    Okyakusan.start do |heroku|
      # create new app
      response = heroku.post("/apps", data: {
        stack: args[:stack]
      })

      if response.code != "201"
        $sterr.puts "Error Creating Heroku App (#{resp.code}): #{resp.body}"
        exit 1
      end
      json     = JSON.parse(response.body)
      app_name = json["name"]
      web_url  = json["web_url"]

      # upload source
      response = heroku.post("/apps/#{app_name}/sources")
      if response.code != "201"
        $stderr.puts "Couldn't get sources to upload code."
        exit 1
      end

      json = JSON.parse(response.body)
      source_get_url = json["source_blob"]["get_url"]
      source_put_url = json["source_blob"]["put_url"]

      puts "Uploading data to #{source_put_url}"
      uri = URI(source_put_url)
      Net::HTTP.start(uri.host, uri.port, :use_ssl => (uri.scheme == 'https')) do |http|
        request = Net::HTTP::Put.new(uri.request_uri, {
          'Content-Length'   => File.size(app_tar).to_s,
          # This is required, or Net::HTTP will add a default unsigned content-type.
          'Content-Type'      => ''
        })
        begin
          app_tar_io          = File.open(app_tar)
          request.body_stream = app_tar_io
          response            = http.request(request)
          if response.code != "200"
            $stderr.puts "Could not upload code"
            exit 1
          end
        ensure
          app_tar_io.close
        end
      end

      # create build
      response = heroku.post("/apps/#{app_name}/builds", version: "3.streaming-build-output", data: {
        "source_blob" => {
          "url"     => source_get_url,
          "version" => ""
        }
      })
      if response.code != "201"
        $stderr.puts "Could create build"
        exit 1
      end

      # stream build output
      uri = URI(JSON.parse(response.body)["output_stream_url"])
      Net::HTTP.start(uri.host, uri.port, :use_ssl => (uri.scheme == 'https')) do |http|
        request = Net::HTTP::Get.new uri.request_uri
        http.request(request) do |response|
          response.read_body do |chunk|
            print chunk
          end
        end
      end
    end

    # test app
    puts web_url
    sleep(1)
    response = network_retry(20) do
      Net::HTTP.get_response(URI(web_url))
    end

    if response.code != "200"
      $stderr.puts "App did not return a 200: #{response.code}"
      exit 1
    else
      puts response.body
      puts "Deleting #{app_name}"
      Okyakusan.start {|heroku| heroku.delete("/apps/#{app_name}") if app_name }
    end
  ensure
    FileUtils.remove_entry tmp_dir
  end
end
