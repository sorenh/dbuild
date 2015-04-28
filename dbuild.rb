#!/usr/bin/env ruby
require 'docker'
require 'optparse'
require 'json'
require 'logger'
require 'logger/colors'
require 'securerandom'

require_relative 'dockerfile'

REPO = 'dbuild-test'
Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

def create_container(id, user, script)
  c = Docker::Container.create(Image: id,
                               User: user,
                               Cmd: ['bash', '-xc', "#{script}"])
  Thread.new do
    c.attach do |_stream, chunk|
      puts chunk
      STDOUT.flush
    end
  end

  c.start(Binds: ["#{Dir.pwd}/build:/home/buildd/build/"])
  c.wait
  c.stop!
  c.commit(repo: REPO, tag: SecureRandom.hex(2), comment: 'test')
end

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: dbuild.rb -d RELEASE [dsc]'

  opts.on('-dDISTRIBUTION', '--dist=DISTRIBUTION', 'Distribution to build for') do |d|
    options[:dist] = d
  end
end.parse!

d = Dockerfile.new(options[:dist])

@log = Logger.new(STDERR)
@log.level = Logger::WARN

Thread.new do
  Docker::Event.stream { |event| @log.debug event }
end

t = Docker::Image.build(d.render) do |chunk|
  begin
    chunk = JSON.parse(chunk)
    keys = chunk.keys
    if keys.include?('stream')
      puts chunk['stream']
    elsif keys.include?('error')
      @log.error chunk['error']
      @log.error chunk['errorDetail']
    elsif keys.include?('status')
      @log.info chunk['status']
    else
      fail "Unknown response type in #{chunk}"
    end
  rescue => e
    @log.error(e)
  end
end

Dir.mkdir('build') unless Dir.exist?('build')
Dir.chdir('build') do
  system("dget -u #{ARGV[-1]}")
end

unpack_script = 'dpkg-source -x /home/buildd/build/*.dsc /home/buildd/pkgbuild/'
a = create_container(t.id, 'buildd', unpack_script)

install_script = 'cd /home/buildd/pkgbuild && /usr/lib/pbuilder/pbuilder-satisfydepends'
b = create_container(a.id, 'root', install_script)

build_script = 'cd /home/buildd/pkgbuild && dpkg-buildpackage'
c = create_container(b.id, 'buildd', build_script)

copy_script = 'dcmd cp /home/buildd/*.changes /home/buildd/build/ && \
               chown -R 666 /home/buildd/build'
d = create_container(c.id, 'root', copy_script)

d.delete
c.delete
b.delete
a.delete
