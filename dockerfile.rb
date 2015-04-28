require 'erb'

UBUNTU_RELEASES ||= `ubuntu-distro-info -a`.split
DEBIAN_RELEASES ||= `debian-distro-info -a`.split +
                     %w(unstable stable testing oldstable experimental)

# Class to render docker file
class Dockerfile
  attr_reader :dist
  attr_reader :flavor

  def initialize(dist)
    @dist = dist
    @flavor = 'ubuntu' if UBUNTU_RELEASES.include? dist
    @flavor = 'debian' if DEBIAN_RELEASES.include? dist
  end

  def render
    path = File.join(File.dirname(__FILE__), 'Dockerfile')
    ERB.new(File.read(path)).result(binding)
  end
end
